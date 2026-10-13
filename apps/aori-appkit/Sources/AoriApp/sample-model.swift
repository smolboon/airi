import AoriCore
import Foundation

enum SampleModel {
    static func data() -> Data? {
        if let url = BundledFile.url(name: "aori-sample", extension: "vrm") {
            return try? Data(contentsOf: url)
        }
        if let url = Bundle.main.url(forResource: "aori-sample", withExtension: "vrm") {
            return try? Data(contentsOf: url)
        }
        #if SWIFT_PACKAGE
        if let url = Bundle.module.url(forResource: "aori-sample", withExtension: "vrm") {
            return try? Data(contentsOf: url)
        }
        #endif
        return nil
    }
}
