import Foundation

/// Transient in-memory representation of the SSH connection settings.
/// Actual persistence lives in KeychainService — this struct is only used
/// to pass values between the Settings screen and SSHManager.
struct SSHConfig: Equatable {
    var host: String
    var port: Int
    var username: String
    var authMethod: AuthMethod

    enum AuthMethod: Equatable {
        case password(String)
        case privateKey(String) // PEM/OpenSSH key text
    }

    var isValid: Bool {
        !host.isEmpty && !username.isEmpty && port > 0 && port < 65536
    }
}
