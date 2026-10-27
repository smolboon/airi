import AppKit
import AoriCore

@MainActor
final class MemoryWindowController: NSWindowController {
    private let store: EmbeddingMemoryStore
    private let list = NSTextField(wrappingLabelWithString: "")
    private let chooser = NSPopUpButton()
    private var rows: [EmbeddingMemoryRecord] = []

    init(store: EmbeddingMemoryStore) {
        self.store = store
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 280),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Aori Memory"
        window.setAccessibilityLabel("Memory list")
        super.init(window: window)
        build()
        reload()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func show() {
        reload()
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }

    @discardableResult
    func deleteFirst() -> Bool {
        guard !rows.isEmpty else {
            return false
        }
        chooser.selectItem(at: 0)
        return deleteSelection()
    }

    @discardableResult
    func deleteSelection() -> Bool {
        let index = chooser.indexOfSelectedItem
        guard index >= 0, index < rows.count else {
            return false
        }
        let removed = store.delete(id: rows[index].id)
        reload()
        return removed
    }

    private func reload() {
        rows = store.list()
        chooser.removeAllItems()
        for row in rows {
            chooser.addItem(withTitle: row.text)
        }
        if rows.isEmpty {
            list.stringValue = "No memories."
        } else {
            list.stringValue = rows.map(\.text).joined(separator: "\n")
        }
    }

    private func build() {
        list.font = .systemFont(ofSize: 13)
        list.translatesAutoresizingMaskIntoConstraints = false
        list.setAccessibilityLabel("Memory list")
        chooser.translatesAutoresizingMaskIntoConstraints = false
        chooser.setAccessibilityLabel("Memory to delete")

        let button = NSButton(title: "Delete", target: self, action: #selector(deletePressed))
        button.bezelStyle = .rounded
        button.setAccessibilityLabel("Delete memory")
        button.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(list)
        content.addSubview(chooser)
        content.addSubview(button)
        window?.contentView = content
        NSLayoutConstraint.activate([
            list.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            list.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            list.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            chooser.leadingAnchor.constraint(equalTo: list.leadingAnchor),
            chooser.trailingAnchor.constraint(equalTo: button.leadingAnchor, constant: -12),
            chooser.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16),
            button.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            button.centerYAnchor.constraint(equalTo: chooser.centerYAnchor),
            list.bottomAnchor.constraint(lessThanOrEqualTo: chooser.topAnchor, constant: -12),
        ])
    }

    @objc private func deletePressed() {
        _ = deleteSelection()
    }
}
