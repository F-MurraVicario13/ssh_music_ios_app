import Foundation
import Citadel
import NIOSSH
import NIOCore

// MARK: - Error types

enum SSHManagerError: LocalizedError {
    case notConfigured
    case connectionRefused
    case authFailed
    case hostUnreachable
    case commandNotFound(String)
    case nonZeroExit(Int, String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "SSH is not configured. Go to Settings first."
        case .connectionRefused:
            return "Connection refused — check host and port."
        case .authFailed:
            return "Authentication failed — check username and credentials."
        case .hostUnreachable:
            return "Host unreachable — check IP address and network."
        case .commandNotFound(let cmd):
            return "'\(cmd)' not found on the remote host. Is somedl installed?"
        case .nonZeroExit(let code, let msg):
            return "Command exited \(code): \(msg)"
        case .unknown(let msg):
            return "SSH error: \(msg)"
        }
    }
}

// MARK: - SSHManager

/// Manages a single reusable SSHClient connection.
/// All public methods are async and safe to call from any Task.
actor SSHManager {

    static let shared = SSHManager()
    private init() {}

    private var client: SSHClient?
    private var currentConfig: SSHConfig?

    // MARK: - Connection lifecycle

    /// Returns an existing connected client or creates a new one.
    func getOrConnect(config: SSHConfig) async throws -> SSHClient {
        // Reuse if same config and still alive
        if let existing = client, currentConfig == config {
            return existing
        }
        // Otherwise establish a fresh session
        return try await connect(config: config)
    }

    func disconnect() async {
        try? await client?.close()
        client = nil
        currentConfig = nil
    }

    // MARK: - Private connect

    private func connect(config: SSHConfig) async throws -> SSHClient {
        let authMethod = try buildAuthMethod(config)

        do {
            let newClient = try await SSHClient.connect(
                host: config.host,
                port: config.port,
                authenticationMethod: authMethod,
                // acceptAnything is fine for a personal device on a home network.
                // For stricter security implement TOFU fingerprint pinning here.
                hostKeyValidator: .acceptAnything()
            )
            client = newClient
            currentConfig = config
            return newClient
        } catch let error as NIOSSHError {
            throw mapNIOError(error)
        } catch {
            throw mapGenericError(error)
        }
    }

    // MARK: - Build auth method

    private func buildAuthMethod(_ config: SSHConfig) throws -> SSHAuthenticationMethod {
        switch config.authMethod {
        case .password(let pw):
            return .passwordBased(username: config.username, password: pw)
        case .privateKey(let pem):
            // NIOSSHPrivateKey(openSSHPrivateKey:) is provided by Citadel and handles
            // Ed25519 and ECDSA keys in OpenSSH format (-----BEGIN OPENSSH PRIVATE KEY-----)
            let privateKey = try NIOSSHPrivateKey(openSSHPrivateKey: pem)
            return .privateKeyBased(username: config.username, privateKey: privateKey)
        }
    }

    // MARK: - Test connection

    /// Runs `which somedl` on the remote host; returns the path string on success.
    func testConnection(config: SSHConfig) async throws -> String {
        let ssh = try await getOrConnect(config: config)
        do {
            let output = try await ssh.executeCommand("which somedl || command -v somedl")
            let text = String(buffer: output).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                throw SSHManagerError.commandNotFound("somedl")
            }
            return text
        } catch let e as SSHManagerError {
            throw e
        } catch {
            // If the first command failed, try version flag
            let output = try await ssh.executeCommand("somedl --version 2>&1 || echo NOT_FOUND")
            let text = String(buffer: output).trimmingCharacters(in: .whitespacesAndNewlines)
            if text.contains("NOT_FOUND") {
                throw SSHManagerError.commandNotFound("somedl")
            }
            return text
        }
    }

    // MARK: - Execute somedl (streaming)

    /// Executes `somedl '<query>'` on the remote host and streams combined stdout/stderr
    /// back as an `AsyncThrowingStream<String, Error>`.
    func runSomeDL(
        query: String,
        config: SSHConfig
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let ssh = try await self.getOrConnect(config: config)
                    let command = buildSomeDLCommand(query)

                    let execStream = try await ssh.executeCommandStream(command)

                    // Concurrently drain stdout and stderr so neither blocks the other.
                    try await withThrowingTaskGroup(of: Void.self) { group in
                        group.addTask {
                            for try await chunk in execStream.stdout {
                                let text = String(buffer: chunk)
                                continuation.yield(text)
                            }
                        }
                        group.addTask {
                            for try await chunk in execStream.stderr {
                                let text = String(buffer: chunk)
                                continuation.yield(text)
                            }
                        }
                        try await group.waitForAll()
                    }

                    continuation.finish()
                } catch let e as SSHManagerError {
                    // Mark the connection dead so next call reconnects
                    await self.invalidateClient()
                    continuation.finish(throwing: e)
                } catch {
                    await self.invalidateClient()
                    continuation.finish(throwing: mapGenericError(error))
                }
            }
        }
    }

    private func invalidateClient() {
        client = nil
        currentConfig = nil
    }

    // MARK: - Shell safety

    /// Single-quotes the argument and escapes any embedded single-quotes.
    /// Produces: somedl 'artist - title' or somedl 'it'\''s complicated'
    private func buildSomeDLCommand(_ query: String) -> String {
        let escaped = query.replacingOccurrences(of: "'", with: "'\\''")
        return "somedl '\(escaped)'"
    }

    // MARK: - Error mapping

    private func mapNIOError(_ error: NIOSSHError) -> SSHManagerError {
        let desc = error.localizedDescription.lowercased()
        if desc.contains("auth") || desc.contains("permission denied") {
            return .authFailed
        }
        if desc.contains("refused") {
            return .connectionRefused
        }
        return .unknown(error.localizedDescription)
    }

    private func mapGenericError(_ error: Error) -> SSHManagerError {
        let desc = error.localizedDescription.lowercased()
        if desc.contains("refused") || desc.contains("econnrefused") {
            return .connectionRefused
        }
        if desc.contains("host") && (desc.contains("reach") || desc.contains("timeout")) {
            return .hostUnreachable
        }
        if desc.contains("auth") || desc.contains("permission denied") {
            return .authFailed
        }
        return .unknown(error.localizedDescription)
    }
}
