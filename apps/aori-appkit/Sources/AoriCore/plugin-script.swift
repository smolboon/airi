import Foundation
#if canImport(JavaScriptCore)
import JavaScriptCore
#endif

protocol PluginScriptRuntime {
    func evaluate(source: String, grant: PluginPermissions) -> String
}

enum PluginScriptBridge {
    static func call(grant: PluginPermissions, area: String, action: String, key: String) -> String {
        guard PluginPermissions.allows(grant, area: area, action: action, key: key) else {
            return "denied"
        }
        if key == PluginHost.greetingKey && action == "snapshot" {
            return PluginHost.greetingText
        }
        return "denied"
    }
}

#if canImport(JavaScriptCore)
@objc protocol AoriScriptExports: JSExport {
    func call(_ area: String, _ action: String, _ key: String) -> String
}

final class AoriScriptApi: NSObject, AoriScriptExports {
    private let grant: PluginPermissions

    init(grant: PluginPermissions) {
        self.grant = grant
    }

    func call(_ area: String, _ action: String, _ key: String) -> String {
        PluginScriptBridge.call(grant: grant, area: area, action: action, key: key)
    }
}

final class ScriptFailure: @unchecked Sendable {
    var failed = false
}

struct JavaScriptCorePluginRuntime: PluginScriptRuntime {
    func evaluate(source: String, grant: PluginPermissions) -> String {
        guard let context = JSContext() else {
            return "error"
        }
        let flag = ScriptFailure()
        context.exceptionHandler = { _, _ in
            flag.failed = true
        }
        let api = AoriScriptApi(grant: grant)
        context.setObject(api, forKeyedSubscript: "aori" as NSString)
        let value = context.evaluateScript(source)
        if flag.failed {
            return "error"
        }
        let text = value?.toString() ?? ""
        if text.isEmpty || text == "undefined" {
            return "error"
        }
        return text
    }
}
#endif
