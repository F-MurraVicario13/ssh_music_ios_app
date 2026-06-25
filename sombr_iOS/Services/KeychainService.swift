import Foundation
import Security

/// Thin wrapper around the iOS Keychain for storing SSH credentials.
/// Every value is encrypted at rest by the Secure Enclave.
enum KeychainService {

    private static let service = "com.sombr.ios.ssh"

    enum Key: String {
        case host       = "ssh_host"
        case port       = "ssh_port"
        case username   = "ssh_username"
        case password   = "ssh_password"
        case privateKey = "ssh_private_key"
        case authMethod = "ssh_auth_method" // "password" | "privateKey"
    }

    // MARK: - Save

    @discardableResult
    static func save(_ value: String, for key: Key) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key.rawValue
        ]

        let attributes: [CFString: Any] = [
            kSecValueData: data,
            // Only accessible when device is unlocked; not backed up to iCloud.
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData] = data
            addQuery[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
        }
        return status == errSecSuccess
    }

    // MARK: - Load

    static func load(_ key: Key) -> String? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecAttrAccount:      key.rawValue,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]

        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8)
        else { return nil }
        return value
    }

    // MARK: - Delete

    @discardableResult
    static func delete(_ key: Key) -> Bool {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key.rawValue
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Convenience: load full SSHConfig

    static func loadConfig() -> SSHConfig? {
        guard
            let host     = load(.host), !host.isEmpty,
            let portStr  = load(.port), let port = Int(portStr),
            let username = load(.username), !username.isEmpty
        else { return nil }

        let method: SSHConfig.AuthMethod
        let rawMethod = load(.authMethod) ?? "password"
        if rawMethod == "privateKey", let key = load(.privateKey), !key.isEmpty {
            method = .privateKey(key)
        } else if let pw = load(.password) {
            method = .password(pw)
        } else {
            return nil
        }

        return SSHConfig(host: host, port: port, username: username, authMethod: method)
    }

    // MARK: - Convenience: save full SSHConfig

    static func saveConfig(_ config: SSHConfig) {
        save(config.host,            for: .host)
        save(String(config.port),    for: .port)
        save(config.username,        for: .username)
        switch config.authMethod {
        case .password(let pw):
            save("password",   for: .authMethod)
            save(pw,           for: .password)
            delete(.privateKey)
        case .privateKey(let pk):
            save("privateKey", for: .authMethod)
            save(pk,           for: .privateKey)
            delete(.password)
        }
    }
}
