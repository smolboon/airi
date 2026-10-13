import AoriCore
import Darwin
import Foundation

@main
enum AoriSceneKitMain {
    static func main() {
        let arguments = CommandLine.arguments
        guard arguments.count >= 3 else {
            fputs("usage: AoriSceneKit <png> <vrm> [emotion]\n", stderr)
            exit(1)
        }
        do {
            let bytes = try Data(contentsOf: URL(fileURLWithPath: arguments[2]))
            let scene = try VRMSceneReader.read(bytes)
            let emotion = CompanionEmotion(rawValue: arguments.count > 3 ? arguments[3] : "neutral") ?? .neutral
            let pose = VRMAvatarPose.face(emotion: emotion)
            guard SceneKitAvatar.writePNG(scene: scene, pose: pose, path: arguments[1]) else {
                fputs("aori_scenekit=failed\n", stderr)
                exit(1)
            }
            let positions = scene.meshes.flatMap(\.positions)
            let framed = PortraitCamera.frame(positions: positions)
            print("aori_scenekit=vrm")
            print("aori_scenekit_vertices=\(scene.vertexCount)")
            print("aori_scenekit_blink=\(pose.blink)")
            print("aori_scenekit_mouth=\(pose.mouthOpen)")
            print("aori_scenekit_yaw=\(pose.yaw)")
            print("aori_scenekit_face=head")
            print("aori_scenekit_emotion=\(pose.emotion.rawValue)")
            print("aori_scenekit_look_y=\(framed.lookY)")
        } catch {
            let message = errorMessage(error)
            fputs("aori_scenekit=failed \(message)\n", stderr)
            exit(1)
        }
    }

    private static func errorMessage(_ error: Error) -> String {
        if let sceneError = error as? VRMSceneError {
            return sceneError.description
        }
        return String(describing: error)
    }
}
