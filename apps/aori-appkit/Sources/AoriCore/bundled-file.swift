import Foundation

public enum BundledFile {
    // NOTICE:
    // The sandboxed app reads these files from Contents/Resources.
    // Bundle.module looks beside the .app and in .build, and the sandbox blocks .build.
    // SwiftPM resource_bundle_accessor.swift fatalError on line 12.
    // Remove this search when that accessor also looks in Contents/Resources.

    public static func url(name: String, extension ext: String) -> URL? {
        let file = "\(name).\(ext)"
        var urls: [URL] = []
        if let resources = Bundle.main.resourceURL {
            urls.append(resources.appendingPathComponent(file))
            urls.append(resources.appendingPathComponent("AoriAppKit_AoriCore.bundle").appendingPathComponent(file))
            urls.append(resources.appendingPathComponent("AoriAppKit_AoriApp.bundle").appendingPathComponent(file))
        }
        let root = Bundle.main.bundleURL
        let contents = root.appendingPathComponent("Contents/Resources")
        urls.append(contents.appendingPathComponent(file))
        urls.append(contents.appendingPathComponent("AoriAppKit_AoriCore.bundle").appendingPathComponent(file))
        urls.append(contents.appendingPathComponent("AoriAppKit_AoriApp.bundle").appendingPathComponent(file))
        for candidate in urls {
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }
}
