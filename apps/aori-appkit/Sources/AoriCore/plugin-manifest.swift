import Foundation

struct PluginDiagnostic: Equatable, Sendable {
    var path: String
    var message: String
}

struct PluginManifest: Equatable, Sendable {
    var id: String
    var version: String
    var airiRange: String
    var runtimes: [String]
    var entrypoints: [String: String]
    var permissions: PluginPermissions
}

enum PluginManifestParse: Equatable, Sendable {
    case manifest(PluginManifest)
    case invalid([PluginDiagnostic])
}

enum PluginManifestReader {
    static let runtimes = ["electron", "node", "web"]
    static let areas = ["apis", "resources", "capabilities", "processors", "pipelines"]
    static let actions = [
        "apis": ["invoke", "emit"],
        "resources": ["read", "write", "subscribe"],
        "capabilities": ["wait", "snapshot"],
        "processors": ["register", "execute", "manage"],
        "pipelines": ["hook", "process", "emit", "manage"],
    ]

    static func parse(_ data: Data) -> PluginManifestParse {
        guard let root = try? JSONSerialization.jsonObject(with: data) else {
            return .invalid([PluginDiagnostic(path: "<root>", message: "The manifest is not JSON.")])
        }
        guard let object = jsonObject(root) else {
            return .invalid([PluginDiagnostic(path: "<root>", message: "The manifest is not an object.")])
        }
        var diagnostics: [PluginDiagnostic] = []
        rejectUnknown(object, allowed: [
            "manifestVersion", "kind", "id", "version", "engines", "entrypoints", "permissions", "kits",
        ], path: "<root>", into: &diagnostics)

        if jsonInt(object["manifestVersion"]) != 2 {
            diagnostics.append(PluginDiagnostic(path: "manifestVersion", message: "Use manifest version 2."))
        }
        if jsonString(object["kind"]) != "manifest.extension.airi.moeru.ai" {
            diagnostics.append(PluginDiagnostic(path: "kind", message: "The kind is not an Aori extension manifest."))
        }
        let id = jsonString(object["id"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !validIdentifier(id) {
            diagnostics.append(PluginDiagnostic(path: "id", message: "Use a lowercase extension id."))
        }
        let version = jsonString(object["version"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if PluginVersion.parseExact(version) == nil {
            diagnostics.append(PluginDiagnostic(path: "version", message: "Use an exact semantic version such as 1.0.0."))
        }

        let engines = jsonObject(object["engines"]) ?? [:]
        if object["engines"] == nil || jsonObject(object["engines"]) == nil {
            diagnostics.append(PluginDiagnostic(path: "engines", message: "Add an engines object."))
        } else {
            rejectUnknown(engines, allowed: ["airi", "runtimes"], path: "engines", into: &diagnostics)
        }
        let airiRange = jsonString(engines["airi"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if PluginVersionRange.parse(airiRange) == nil {
            diagnostics.append(PluginDiagnostic(path: "engines.airi", message: "Use a semantic version range."))
        }
        let runtimeValues = jsonArray(engines["runtimes"])
        var runtimes: [String] = []
        if engines["runtimes"] != nil && runtimeValues == nil {
            diagnostics.append(PluginDiagnostic(path: "engines.runtimes", message: "Use an array of runtime names."))
        } else if runtimeValues?.isEmpty != false {
            diagnostics.append(PluginDiagnostic(path: "engines.runtimes", message: "Declare one runtime."))
        }
        for (index, value) in (runtimeValues ?? []).enumerated() {
            let name = jsonString(value) ?? ""
            if !Self.runtimes.contains(name) {
                diagnostics.append(PluginDiagnostic(path: "engines.runtimes.\(index)", message: "Use electron, node, or web."))
            } else if runtimes.contains(name) {
                diagnostics.append(PluginDiagnostic(path: "engines.runtimes", message: "Declare each runtime once."))
            } else {
                runtimes.append(name)
            }
        }

        let entryObject = jsonObject(object["entrypoints"]) ?? [:]
        if object["entrypoints"] == nil || jsonObject(object["entrypoints"]) == nil {
            diagnostics.append(PluginDiagnostic(path: "entrypoints", message: "Add an entrypoints object."))
        } else {
            rejectUnknown(entryObject, allowed: ["default", "electron", "node", "web"], path: "entrypoints", into: &diagnostics)
        }
        var entrypoints: [String: String] = [:]
        for key in ["default", "electron", "node", "web"] {
            guard let raw = entryObject[key] else {
                continue
            }
            let path = jsonString(raw)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if path.isEmpty {
                diagnostics.append(PluginDiagnostic(path: "entrypoints.\(key)", message: "Use a non-empty entrypoint path."))
            } else {
                entrypoints[key] = path
            }
        }
        if entrypoints.isEmpty {
            diagnostics.append(PluginDiagnostic(path: "entrypoints", message: "Define at least one entrypoint."))
        }
        for runtime in runtimes where entrypoints[runtime] == nil && entrypoints["default"] == nil {
            diagnostics.append(PluginDiagnostic(path: "entrypoints", message: "Define an entrypoint for every declared runtime."))
        }

        let permissions = parsePermissions(object["permissions"], into: &diagnostics)
        parseKits(object["kits"], into: &diagnostics)
        if !diagnostics.isEmpty {
            return .invalid(diagnostics)
        }
        return .manifest(PluginManifest(
            id: id,
            version: version,
            airiRange: airiRange,
            runtimes: runtimes,
            entrypoints: entrypoints,
            permissions: permissions
        ))
    }

    private static func parsePermissions(_ value: Any?, into diagnostics: inout [PluginDiagnostic]) -> PluginPermissions {
        guard let object = jsonObject(value) else {
            diagnostics.append(PluginDiagnostic(path: "permissions", message: "Add a permissions object."))
            return .empty
        }
        rejectUnknown(object, allowed: Set(areas), path: "permissions", into: &diagnostics)
        var permissions = PluginPermissions.empty
        for area in areas {
            guard let raw = object[area] else {
                continue
            }
            guard let items = jsonArray(raw) else {
                diagnostics.append(PluginDiagnostic(path: "permissions.\(area)", message: "Use an array of permission objects."))
                continue
            }
            let parsed = items.enumerated().compactMap { index, item -> PluginPermission? in
                parsePermission(item, area: area, path: "permissions.\(area).\(index)", into: &diagnostics)
            }
            switch area {
            case "apis":
                permissions.apis = parsed
            case "resources":
                permissions.resources = parsed
            case "capabilities":
                permissions.capabilities = parsed
            case "processors":
                permissions.processors = parsed
            case "pipelines":
                permissions.pipelines = parsed
            default:
                break
            }
        }
        return permissions
    }

    private static func parsePermission(
        _ value: Any,
        area: String,
        path: String,
        into diagnostics: inout [PluginDiagnostic]
    ) -> PluginPermission? {
        guard let object = jsonObject(value) else {
            diagnostics.append(PluginDiagnostic(path: path, message: "Use a permission object."))
            return nil
        }
        rejectUnknown(object, allowed: ["key", "label", "reason", "required", "metadata", "actions"], path: path, into: &diagnostics)
        let key = jsonString(object["key"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if key.isEmpty {
            diagnostics.append(PluginDiagnostic(path: "\(path).key", message: "Use a non-empty permission key."))
        }
        let allowedActions = actions[area] ?? []
        let rawActions = jsonArray(object["actions"])
        if object["actions"] != nil && rawActions == nil {
            diagnostics.append(PluginDiagnostic(path: "\(path).actions", message: "Use an array of actions."))
        } else if rawActions?.isEmpty != false {
            diagnostics.append(PluginDiagnostic(path: "\(path).actions", message: "Declare one action."))
        }
        var names: [String] = []
        for (index, action) in (rawActions ?? []).enumerated() {
            let name = jsonString(action) ?? ""
            if !allowedActions.contains(name) {
                diagnostics.append(PluginDiagnostic(path: "\(path).actions.\(index)", message: "Use an action from this permission area."))
            } else if !names.contains(name) {
                names.append(name)
            }
        }
        return PluginPermission(key: key, actions: names)
    }

    private static func parseKits(_ value: Any?, into diagnostics: inout [PluginDiagnostic]) {
        guard let value else {
            return
        }
        guard let object = jsonObject(value) else {
            diagnostics.append(PluginDiagnostic(path: "kits", message: "Use a kits object."))
            return
        }
        rejectUnknown(object, allowed: ["provides", "uses"], path: "kits", into: &diagnostics)
        _ = kitIDs(object["provides"], exact: true, path: "kits.provides", into: &diagnostics)
        _ = kitIDs(object["uses"], exact: false, path: "kits.uses", into: &diagnostics)
    }

    private static func kitIDs(
        _ value: Any?,
        exact: Bool,
        path: String,
        into diagnostics: inout [PluginDiagnostic]
    ) -> [String] {
        guard let value else {
            return []
        }
        guard let items = jsonArray(value) else {
            diagnostics.append(PluginDiagnostic(path: path, message: "Use an array of kit declarations."))
            return []
        }
        var ids: [String] = []
        for (index, item) in items.enumerated() {
            guard let object = jsonObject(item) else {
                diagnostics.append(PluginDiagnostic(path: "\(path).\(index)", message: "Use a kit object."))
                continue
            }
            let allowed = exact ? ["id", "version", "exposure"] : ["id", "version", "optional"]
            rejectUnknown(object, allowed: Set(allowed), path: "\(path).\(index)", into: &diagnostics)
            let id = jsonString(object["id"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if id.isEmpty {
                diagnostics.append(PluginDiagnostic(path: "\(path).\(index).id", message: "Use a kit id."))
            } else if ids.contains(id) {
                diagnostics.append(PluginDiagnostic(path: path, message: "Declare each kit once."))
            } else {
                ids.append(id)
            }
            let version = jsonString(object["version"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if exact {
                if PluginVersion.parseExact(version) == nil {
                    diagnostics.append(PluginDiagnostic(path: "\(path).\(index).version", message: "Use an exact semantic version such as 1.0.0."))
                }
                let exposure = jsonString(object["exposure"]) ?? ""
                if !["local-only", "remote-observable", "remote-callable"].contains(exposure) {
                    diagnostics.append(PluginDiagnostic(path: "\(path).\(index).exposure", message: "Use a known kit exposure."))
                }
            } else if PluginVersionRange.parse(version) == nil {
                diagnostics.append(PluginDiagnostic(path: "\(path).\(index).version", message: "Use a semantic version range."))
            }
        }
        return ids
    }

    private static func validIdentifier(_ id: String) -> Bool {
        guard (1...255).contains(id.count) else {
            return false
        }
        let pattern = #"^[a-z0-9](?:[a-z0-9._-]*[a-z0-9])?$"#
        guard id.range(of: pattern, options: .regularExpression) != nil else {
            return false
        }
        let reserved = #"^(?:con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)"#
        return id.range(of: reserved, options: .regularExpression) == nil
    }
}

private func rejectUnknown(
    _ object: [String: Any],
    allowed: Set<String>,
    path: String,
    into diagnostics: inout [PluginDiagnostic]
) {
    for key in object.keys.sorted() where !allowed.contains(key) {
        let prefix = path == "<root>" ? key : "\(path).\(key)"
        diagnostics.append(PluginDiagnostic(path: prefix, message: "Remove the unknown field."))
    }
}

private func jsonObject(_ value: Any?) -> [String: Any]? {
    value as? [String: Any]
}

private func jsonArray(_ value: Any?) -> [Any]? {
    value as? [Any]
}

private func jsonString(_ value: Any?) -> String? {
    value as? String
}

private func jsonInt(_ value: Any?) -> Int? {
    guard let value else {
        return nil
    }
    if value is Bool {
        return nil
    }
    // JSON true and false are boolean numbers. A version is an integer.
    if let number = value as? NSNumber {
        let type = String(cString: number.objCType)
        if type == "c" || type == "B" {
            return nil
        }
        let double = number.doubleValue
        guard double.rounded() == double else {
            return nil
        }
        return Int(double)
    }
    return nil
}
