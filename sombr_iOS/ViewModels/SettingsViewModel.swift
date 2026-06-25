import Foundation
import SwiftUI

enum AuthMethodChoice: String, CaseIterable, Identifiable {
    case privateKey = "Private Key"
    case password   = "Password"
    var id: String { rawValue }
}

enum TestConnectionState: Equatable {
    case idle
    case testing
    case success(String)    // somedl path/version
    case failure(String)    // error message
}

@MainActor
final class SettingsViewModel: ObservableObject {

    // Form fields — loaded from Keychain on init
    @Published var host: String       = ""
    @Published var port: String       = "22"
    @Published var username: String   = ""
    @Published var password: String   = ""
    @Published var privateKey: String = ""
    @Published var authChoice: AuthMethodChoice = .privateKey

    @Published var testState: TestConnectionState = .idle

    init() {
        loadFromKeychain()
    }

    // MARK: - Persistence

    func loadFromKeychain() {
        if let config = KeychainService.loadConfig() {
            host     = config.host
            port     = String(config.port)
            username = config.username
            switch config.authMethod {
            case .password(let pw):
                password   = pw
                authChoice = .password
            case .privateKey(let pk):
                privateKey = pk
                authChoice = .privateKey
            }
        }
    }

    func save() {
        guard let portInt = Int(port), portInt > 0, portInt < 65536 else { return }
        let method: SSHConfig.AuthMethod = authChoice == .privateKey
            ? .privateKey(privateKey)
            : .password(password)
        let config = SSHConfig(host: host, port: portInt, username: username, authMethod: method)
        KeychainService.saveConfig(config)
        testState = .idle   // reset banner after a config change
    }

    // MARK: - Test connection

    func testConnection() {
        guard let portInt = Int(port), portInt > 0 else {
            testState = .failure("Invalid port number.")
            return
        }
        guard !host.isEmpty, !username.isEmpty else {
            testState = .failure("Host and username are required.")
            return
        }
        let cred: SSHConfig.AuthMethod = authChoice == .privateKey
            ? .privateKey(privateKey)
            : .password(password)
        let config = SSHConfig(host: host, port: portInt, username: username, authMethod: cred)

        testState = .testing
        Task {
            do {
                let path = try await SSHManager.shared.testConnection(config: config)
                testState = .success("somedl found: \(path)")
            } catch {
                testState = .failure(error.localizedDescription)
            }
        }
    }
}
