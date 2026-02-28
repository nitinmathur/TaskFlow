import SwiftUI
import AppKit

// MARK: - Formatting Toolbar

struct FormattingToolbar: View {
    @Binding var text: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ToolbarButton(icon: "bold", tooltip: "Bold") {
                    insertMarkdown("**", "**", placeholder: "bold")
                }
                ToolbarButton(icon: "italic", tooltip: "Italic") {
                    insertMarkdown("_", "_", placeholder: "italic")
                }
                ToolbarButton(icon: "strikethrough", tooltip: "Strikethrough") {
                    insertMarkdown("~~", "~~", placeholder: "text")
                }

                ToolbarDivider()

                ToolbarButton(icon: "number", tooltip: "Heading") {
                    insertAtLineStart("## ", placeholder: "Heading")
                }
                ToolbarButton(icon: "list.bullet", tooltip: "Bullet List") {
                    insertAtLineStart("- ", placeholder: "Item")
                }
                ToolbarButton(icon: "checklist", tooltip: "Checkbox") {
                    insertAtLineStart("- [ ] ", placeholder: "Task")
                }

                ToolbarDivider()

                ToolbarButton(icon: "chevron.left.forwardslash.chevron.right", tooltip: "Inline Code") {
                    insertMarkdown("`", "`", placeholder: "code")
                }
                ToolbarButton(icon: "doc.text", tooltip: "Code Block") {
                    insertCodeBlock()
                }

                ToolbarDivider()

                ToolbarButton(icon: "link", tooltip: "Link") {
                    insertLink()
                }
                ToolbarButton(icon: "quote.opening", tooltip: "Quote") {
                    insertAtLineStart("> ", placeholder: "Quote")
                }
                ToolbarButton(icon: "minus", tooltip: "Divider") {
                    insertText("\n---\n")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func insertMarkdown(_ pre: String, _ suf: String, placeholder: String) {
        text += (text.isEmpty || text.hasSuffix("\n") || text.hasSuffix(" ")) ? "" : " "
        text += "\(pre)\(placeholder)\(suf)"
    }

    private func insertAtLineStart(_ prefix: String, placeholder: String) {
        if !text.isEmpty && !text.hasSuffix("\n") { text += "\n" }
        text += "\(prefix)\(placeholder)"
    }

    private func insertCodeBlock() {
        if !text.isEmpty && !text.hasSuffix("\n") { text += "\n" }
        text += "```\ncode\n```"
    }

    private func insertLink() {
        text += (text.isEmpty || text.hasSuffix("\n") || text.hasSuffix(" ")) ? "" : " "
        text += "[text](https://)"
    }

    private func insertText(_ t: String) { text += t }
}

struct ToolbarButton: View {
    let icon: String
    let tooltip: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon).font(.subheadline).frame(width: 28, height: 24)
        }
        .buttonStyle(.plain)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .help(tooltip)
    }
}

struct ToolbarDivider: View {
    var body: some View {
        Divider().frame(height: 16).padding(.horizontal, 6)
    }
}

// MARK: - Markdown Text Editor (NSTextView)

struct MarkdownTextEditor: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.backgroundColor = .clear
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.allowsUndo = true
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        return scrollView
    }

    func updateNSView(_ sv: NSScrollView, context: Context) {
        let tv = sv.documentView as! NSTextView
        if tv.string != text { tv.string = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownTextEditor
        init(_ p: MarkdownTextEditor) { parent = p }
        func textDidChange(_ n: Notification) {
            if let tv = n.object as? NSTextView { parent.text = tv.string }
        }
    }
}
