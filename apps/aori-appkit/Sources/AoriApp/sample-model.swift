import Foundation

enum SampleModel {
    static func data() -> Data? {
        #if SWIFT_PACKAGE
        if let url = Bundle.module.url(forResource: "aori-sample", withExtension: "vrm") {
            return try? Data(contentsOf: url)
        }
        #endif
        if let url = Bundle.main.url(forResource: "aori-sample", withExtension: "vrm") {
            return try? Data(contentsOf: url)
        }
        return nil
    }
}
