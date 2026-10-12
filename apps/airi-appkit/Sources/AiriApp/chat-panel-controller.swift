import AppKit
import AiriCore

@MainActor
final class ChatPanelController: NSViewController {
    private let transcriptView: NSTextView
    private let scrollView: NSScrollView
    private let draftField = NSTextField(string: "")
    private let statusLabel = NSTextField(wrappingLabelWithString: "")
    private let sendButton = NSButton(title: "Send", target: nil, action: nil)
    private let speakButton = NSButton(title: "Speak", target: nil, action: nil)
    private let listenButton = NSButton(title: "Listen", target: nil, action: nil)

    var onSend: (() -> Void)?
    var onSpeak: (() -> Void)?
    var onListen: (() -> Void)?

    init() {
        scrollView = NSTextView.scrollableTextView()
        transcriptView = scrollView.documentView as? NSTextView ?? NSTextView()
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        let root = NSView()
        view = root

        transcriptView.isEditable = false
        transcriptView.isSelectable = true
        transcriptView.isRichText = false
        transcriptView.font = .systemFont(ofSize: 14)
        transcriptView.textColor = .labelColor
        transcriptView.drawsBackground = true
        transcriptView.backgroundColor = .textBackgroundColor
        transcriptView.textContainerInset = NSSize(width: 8, height: 8)
        transcriptView.setAccessibilityLabel("Chat transcript")
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder

        draftField.placeholderString = "Message AIRI"
        draftField.font = .systemFont(ofSize: 14)
        draftField.translatesAutoresizingMaskIntoConstraints = false
        draftField.setAccessibilityLabel("Message")
        draftField.target = self
        draftField.action = #selector(send)

        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.maximumNumberOfLines = 3
        statusLabel.setAccessibilityLabel("Status")

        configure(sendButton, label: "Send message", action: #selector(send))
        configure(speakButton, label: "Speak the last reply", action: #selector(speak))
        configure(listenButton, label: "Listen with the microphone", action: #selector(listen))
        let buttons = NSStackView(views: [listenButton, speakButton, sendButton])
        buttons.orientation = .horizontal
        buttons.spacing = 8
        buttons.translatesAutoresizingMaskIntoConstraints = false

        root.addSubview(scrollView)
        root.addSubview(statusLabel)
        root.addSubview(draftField)
        root.addSubview(buttons)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: root.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -8),

            statusLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            statusLabel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            statusLabel.bottomAnchor.constraint(equalTo: draftField.topAnchor, constant: -8),

            draftField.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            draftField.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -12),
            draftField.heightAnchor.constraint(equalToConstant: 28),

            buttons.leadingAnchor.constraint(equalTo: draftField.trailingAnchor, constant: 8),
            buttons.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            buttons.centerYAnchor.constraint(equalTo: draftField.centerYAnchor),
        ])
    }

    func render(_ model: ChatViewModel) {
        var lines: [String] = []
        for message in model.messages where message.role != .system {
            let speaker = message.role == .user ? "You" : "AIRI"
            lines.append("\(speaker)\n\(message.content)")
        }
        let next = lines.joined(separator: "\n\n")
        if transcriptView.string != next {
            transcriptView.string = next
            transcriptView.scrollToEndOfDocument(nil)
        }
        statusLabel.stringValue = model.statusText
        sendButton.isEnabled = model.phase != .streaming
        speakButton.isEnabled = model.textForSpeech() != nil && !model.isSpeaking
    }

    func draftText() -> String {
        draftField.stringValue
    }

    func setDraft(_ text: String) {
        draftField.stringValue = text
    }

    func setListening(_ listening: Bool) {
        listenButton.title = listening ? "Stop" : "Listen"
    }

    @objc private func send() {
        onSend?()
    }

    @objc private func speak() {
        onSpeak?()
    }

    @objc private func listen() {
        onListen?()
    }

    private func configure(_ button: NSButton, label: String, action: Selector) {
        button.target = self
        button.action = action
        button.bezelStyle = .rounded
        button.setAccessibilityLabel(label)
        button.translatesAutoresizingMaskIntoConstraints = false
    }
}
