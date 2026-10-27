import AoriCore
import Foundation
import Security

struct KeychainError: Error, Equatable, CustomStringConvertible {
    var status: OSStatus

    var description: String {
        "Keychain status \(status)."
    }
}

struct KeychainSecretStore: SecretStore {
    var service: String

    func read(account: String) throws -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainError(status: status)
        }
        guard let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func write(account: String, secret: String) throws {
        let data = Data(secret.utf8)
        let query = baseQuery(account: account)
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        if status == errSecSuccess {
            let attributes = [kSecValueData as String: data] as CFDictionary
            let update = SecItemUpdate(query as CFDictionary, attributes)
            guard update == errSecSuccess else {
                throw KeychainError(status: update)
            }
            return
        }
        if status != errSecItemNotFound {
            throw KeychainError(status: status)
        }
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let created = SecItemAdd(add as CFDictionary, nil)
        guard created == errSecSuccess else {
            throw KeychainError(status: created)
        }
    }

    func delete(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        if status == errSecItemNotFound || status == errSecSuccess {
            return
        }
        throw KeychainError(status: status)
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail,
        ]
    }
}
