import Foundation

struct PluginPermission: Equatable, Sendable {
    var key: String
    var actions: [String]

    init(key: String, actions: [String]) {
        self.key = key
        self.actions = actions
    }
}

struct PluginPermissions: Equatable, Sendable {
    var apis: [PluginPermission]
    var resources: [PluginPermission]
    var capabilities: [PluginPermission]
    var processors: [PluginPermission]
    var pipelines: [PluginPermission]

    static let empty = PluginPermissions(apis: [], resources: [], capabilities: [], processors: [], pipelines: [])

    /// The overlap of the request and the grant. The result is never wider than either side.
    static func intersect(_ requested: PluginPermissions, _ granted: PluginPermissions) -> PluginPermissions {
        PluginPermissions(
            apis: intersect(requested.apis, granted.apis),
            resources: intersect(requested.resources, granted.resources),
            capabilities: intersect(requested.capabilities, granted.capabilities),
            processors: intersect(requested.processors, granted.processors),
            pipelines: intersect(requested.pipelines, granted.pipelines)
        )
    }

    static func allows(_ grant: PluginPermissions, area: String, action: String, key: String) -> Bool {
        let scopes: [PluginPermission]
        switch area {
        case "apis":
            scopes = grant.apis
        case "resources":
            scopes = grant.resources
        case "capabilities":
            scopes = grant.capabilities
        case "processors":
            scopes = grant.processors
        case "pipelines":
            scopes = grant.pipelines
        default:
            return false
        }
        return scopes.contains { scope in
            matchKey(scope.key, key) && scope.actions.contains(action)
        }
    }

    private static func intersect(_ requested: [PluginPermission], _ granted: [PluginPermission]) -> [PluginPermission] {
        var order: [String] = []
        var actionsByKey: [String: [String]] = [:]
        for request in requested {
            for grant in granted {
                guard let key = intersectionKey(request.key, grant.key) else {
                    continue
                }
                let shared = request.actions.filter { grant.actions.contains($0) }
                guard !shared.isEmpty else {
                    continue
                }
                if actionsByKey[key] == nil {
                    order.append(key)
                }
                var merged = actionsByKey[key] ?? []
                for action in shared where !merged.contains(action) {
                    merged.append(action)
                }
                actionsByKey[key] = merged
            }
        }
        return order.map { PluginPermission(key: $0, actions: actionsByKey[$0] ?? []) }
    }
}

func matchKey(_ pattern: String, _ target: String) -> Bool {
    if pattern == "*" {
        return true
    }
    if pattern.hasSuffix("*") {
        return target.hasPrefix(String(pattern.dropLast()))
    }
    return pattern == target
}

func intersectionKey(_ left: String, _ right: String) -> String? {
    if matchKey(left, right) {
        return right
    }
    if matchKey(right, left) {
        return left
    }
    return nil
}
