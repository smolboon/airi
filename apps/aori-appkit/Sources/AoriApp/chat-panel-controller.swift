import AppKit
import AoriCore

@MainActor
final class ChatPanelController: NSViewController {
    private let transcriptView: NSTextView
    private let scrollView: NSScrollView
    private let draftField = NSTextField(string: "")
    private let searchField = NSTextField(string: "")
    private let statusLabel = NSTextField(wrappingLabelWithString: "")
    private let sendButton = NSButton(title: "Send", target: nil, action: nil)
    private let speakButton = NSButton(title: "Speak", target: nil, action: nil)
    private let listenButton = NSButton(title: "Listen", target: nil, action: nil)

    var onSend: (() -> Void)?
    var onSpeak: (() -> Void)?
    var onListen: (() -> Void)?
    private var renderedModel: ChatViewModel?

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
        transcriptView.drawsBackground = false
        transcriptView.insertionPointColor = AccentPalette.fill
        transcriptView.selectedTextAttributes = [
            .backgroundColor: AccentPalette.fill,
            .foregroundColor: AccentPalette.ink,
        ]
        transcriptView.textContainerInset = NSSize(width: 8, height: 8)
        transcriptView.setAccessibilityLabel(AccessibilityCopy.transcript)
        scrollView.setAccessibilityLabel(AccessibilityCopy.transcript)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder

        searchField.placeholderString = "Search chat"
        searchField.font = .systemFont(ofSize: 13)
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.setAccessibilityLabel(AccessibilityCopy.search)
        searchField.target = self
        searchField.action = #selector(searchChanged)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(searchChanged),
            name: NSControl.textDidChangeNotification,
            object: searchField
        )

        draftField.placeholderString = "Message Aori"
        draftField.font = .systemFont(ofSize: 14)
        draftField.translatesAutoresizingMaskIntoConstraints = false
        draftField.setAccessibilityLabel(AccessibilityCopy.message)
        draftField.target = self
        draftField.action = #selector(send)

        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.maximumNumberOfLines = 3
        statusLabel.setAccessibilityLabel(AccessibilityCopy.status)

        configure(sendButton, label: AccessibilityCopy.send, action: #selector(send))
        configure(speakButton, label: AccessibilityCopy.speak, action: #selector(speak))
        configure(listenButton, label: AccessibilityCopy.listen, action: #selector(listen))
        let buttons = NSStackView(views: [listenButton, speakButton, sendButton])
        buttons.orientation = .horizontal
        buttons.spacing = 8
        buttons.translatesAutoresizingMaskIntoConstraints = false

        root.addSubview(searchField)
        root.addSubview(scrollView)
        root.addSubview(statusLabel)
        root.addSubview(draftField)
        root.addSubview(buttons)

        NSLayoutConstraint.activate([
            searchField.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            searchField.topAnchor.constraint(equalTo: root.topAnchor, constant: 8),
            searchField.heightAnchor.constraint(equalToConstant: 24),

            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
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
        renderedModel = model
        paint(model)
    }

    private func paint(_ model: ChatViewModel) {
        let query = searchField.stringValue
        let hits = TranscriptSearch.match(query: query, messages: model.messages, notes: model.memory.notes)
        let shown = query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? model.messages : hits.messages
        var lines: [String] = []
        for message in shown where message.role != .system {
            let speaker = message.role == .user ? "You" : "Aori"
            lines.append("\(speaker)\n\(message.content)")
        }
        if !hits.notes.isEmpty {
            let notes = hits.notes.map(\.text).joined(separator: "\n")
            lines.append("Memory\n\(notes)")
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

    func setSpeechCaption(_ text: String) {
        statusLabel.setAccessibilityValue(text)
    }

    func setListening(_ listening: Bool) {
        listenButton.title = listening ? "Stop" : "Listen"
    }

    func pressSendForAccessibility() -> String {
        let label = sendButton.accessibilityLabel() ?? AccessibilityCopy.send
        sendButton.performClick(nil)
        return label
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

    @objc private func searchChanged() {
        guard let renderedModel else {
            return
        }
        paint(renderedModel)
    }

    private func configure(_ button: NSButton, label: String, action: Selector) {
        button.target = self
        button.action = action
        button.bezelStyle = .rounded
        AccentPalette.apply(to: button)
        button.setAccessibilityLabel(label)
        button.translatesAutoresizingMaskIntoConstraints = false
    }
}
