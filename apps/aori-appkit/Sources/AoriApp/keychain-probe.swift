import Foundation

enum KeychainProbe {
    static let account = "aori-keychain-probe"

    static func line(store: KeychainSecretStore) -> String {
        let token = "probe-token"
        do {
            try store.delete(account: account)
            try store.write(account: account, secret: token)
            let read = try store.read(account: account)
            try store.delete(account: account)
            if read == token {
                return "aori_keychain=roundtrip"
            }
            return "aori_keychain=mismatch"
        } catch {
            return "aori_keychain=failed \(error)"
        }
    }
}
