import AoriCore
import Darwin
import Foundation

@main
enum AoriSceneKitMain {
    static func main() {
        let arguments = CommandLine.arguments
        guard arguments.count >= 3 else {
            fputs("usage: AoriSceneKit <png> <vrm> [emotion|--reply text]\n", stderr)
            exit(1)
        }
        do {
            let bytes = try Data(contentsOf: URL(fileURLWithPath: arguments[2]))
            let scene = try VRMSceneReader.read(bytes)
            let emotion = emotion(from: arguments)
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
            if arguments.count > 4, arguments[3] == "--reply" {
                print("aori_expression_reply=\(arguments[4])")
            }
        } catch {
            let message = errorMessage(error)
            fputs("aori_scenekit=failed \(message)\n", stderr)
            exit(1)
        }
    }

    private static func emotion(from arguments: [String]) -> CompanionEmotion {
        if arguments.count > 4, arguments[3] == "--reply" {
            return CompanionEmotion.infer(from: arguments[4])
        }
        if arguments.count > 3, let named = CompanionEmotion(rawValue: arguments[3]) {
            return named
        }
        return .neutral
    }

    private static func errorMessage(_ error: Error) -> String {
        if let sceneError = error as? VRMSceneError {
            return sceneError.description
        }
        return String(describing: error)
    }
}
