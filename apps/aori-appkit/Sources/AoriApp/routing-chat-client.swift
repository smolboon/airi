import AoriCore
import AoriProviders
import Foundation

struct RoutingChatClient: ChatCompletionClient {
    func streamChat(
        messages: [ChatMessage],
        configuration: ProviderConfiguration
    ) async throws -> AsyncThrowingStream<ChatStreamEvent, Error> {
        if ChatRoute.usesDeviceTemplate(configuration) {
            return try await LocalChatClient().streamChat(messages: messages, configuration: configuration)
        }
        return try await OpenAICompatibleClient().streamChat(messages: messages, configuration: configuration)
    }
}
