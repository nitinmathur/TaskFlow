import SwiftUI
import AppKit

// MARK: - Text View Coordinator for Toolbar Communication

/// Observable class that provides access to the NSTextView for formatting operations
class TextViewCoordinator: ObservableObject {
    weak var textView: NSTextView?

    /// Applies markdown formatting to the selected text or inserts at cursor
    func applyFormatting(prefix: String, suffix: String, placeholder: String) {
        guard let textView = textView else { return }

        let selectedRange = textView.selectedRange()
        let text = textView.string

        if selectedRange.length > 0 {
            // Wrap selected text with markdown syntax
            if let range = Range(selectedRange, in: text) {
                let selectedText = String(text[range])
                let newText = "\(prefix)\(selectedText)\(suffix)"
                textView.insertText(newText, replacementRange: selectedRange)
            }
        } else {
            // No selection - insert placeholder at cursor
            let insertText = "\(prefix)\(placeholder)\(suffix)"
            textView.insertText(insertText, replacementRange: selectedRange)

            // Select the placeholder for easy replacement
            let newCursorLocation = selectedRange.location + prefix.count
            let newSelectionRange = NSRange(location: newCursorLocation, length: placeholder.count)
            textView.setSelectedRange(newSelectionRange)
        }

        textView.window?.makeFirstResponder(textView)
    }

    /// Inserts markdown at the start of the current line
    func insertAtLineStart(prefix: String, placeholder: String) {
        guard let textView = textView else { return }

        let text = textView.string as NSString
        let selectedRange = textView.selectedRange()

        // Handle empty text case
        if text.length == 0 {
            let insertText = "\(prefix)\(placeholder)"
            textView.insertText(insertText, replacementRange: selectedRange)
            let newSelectionRange = NSRange(location: prefix.count, length: placeholder.count)
            textView.setSelectedRange(newSelectionRange)
            textView.window?.makeFirstResponder(textView)
            return
        }

        // Find the start of the current line
        let safeLocation = min(selectedRange.location, text.length)
        let lineRange = text.lineRange(for: NSRange(location: safeLocation, length: 0))
        let lineStart = lineRange.location

        // Check if line already has content
        let currentLine = text.substring(with: lineRange)
        let trimmedLine = currentLine.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedLine.isEmpty {
            // Line is empty - insert prefix + placeholder
            let insertText = "\(prefix)\(placeholder)"
            let replaceLength = max(0, lineRange.length - 1)
            textView.insertText(insertText, replacementRange: NSRange(location: lineStart, length: replaceLength))

            // Select the placeholder
            let newSelectionRange = NSRange(location: lineStart + prefix.count, length: placeholder.count)
            textView.setSelectedRange(newSelectionRange)
        } else {
            // Line has content - insert at the start of the line (prepend prefix)
            let insertText = "\(prefix)"
            textView.insertText(insertText, replacementRange: NSRange(location: lineStart, length: 0))

            // Position cursor after the prefix
            let newCursorLocation = lineStart + prefix.count
            textView.setSelectedRange(NSRange(location: newCursorLocation, length: 0))
        }

        textView.window?.makeFirstResponder(textView)
    }

    /// Inserts a code block
    func insertCodeBlock() {
        guard let textView = textView else { return }

        let selectedRange = textView.selectedRange()
        let text = textView.string

        // Check if we need a leading newline (not at start and previous char is not newline)
        var needsLeadingNewline = false
        if selectedRange.location > 0 && !text.isEmpty {
            let prevIndex = text.index(text.startIndex, offsetBy: selectedRange.location - 1, limitedBy: text.endIndex)
            if let idx = prevIndex, idx < text.endIndex {
                needsLeadingNewline = text[idx] != "\n"
            }
        }

        let leadingNewline = needsLeadingNewline ? "\n" : ""

        if selectedRange.length > 0 {
            // Wrap selected text in code block
            if let range = Range(selectedRange, in: text) {
                let selectedText = String(text[range])
                let newText = "\(leadingNewline)```\n\(selectedText)\n```\n"
                textView.insertText(newText, replacementRange: selectedRange)
            }
        } else {
            // Insert empty code block with placeholder
            let insertText = "\(leadingNewline)```\ncode\n```\n"
            textView.insertText(insertText, replacementRange: selectedRange)

            // Select "code" placeholder
            let codeStart = selectedRange.location + leadingNewline.count + 4 // "```\n" = 4 chars
            let newSelectionRange = NSRange(location: codeStart, length: 4) // "code" = 4 chars
            textView.setSelectedRange(newSelectionRange)
        }

        textView.window?.makeFirstResponder(textView)
    }

    /// Inserts a markdown link
    func insertLink() {
        guard let textView = textView else { return }

        let selectedRange = textView.selectedRange()
        let text = textView.string

        if selectedRange.length > 0 {
            // Use selected text as link text
            if let range = Range(selectedRange, in: text) {
                let selectedText = String(text[range])
                let newText = "[\(selectedText)](https://)"
                textView.insertText(newText, replacementRange: selectedRange)

                // Position cursor in the URL portion
                let urlStart = selectedRange.location + selectedText.count + 3 // "[text](" = text.count + 3
                textView.setSelectedRange(NSRange(location: urlStart + 8, length: 0)) // After "https://"
            }
        } else {
            // Insert placeholder link
            let insertText = "[text](https://)"
            textView.insertText(insertText, replacementRange: selectedRange)

            // Select "text" placeholder
            let newSelectionRange = NSRange(location: selectedRange.location + 1, length: 4)
            textView.setSelectedRange(newSelectionRange)
        }

        textView.window?.makeFirstResponder(textView)
    }

    /// Inserts plain text at cursor position
    func insertText(_ insertText: String) {
        guard let textView = textView else { return }

        let selectedRange = textView.selectedRange()
        textView.insertText(insertText, replacementRange: selectedRange)
        textView.window?.makeFirstResponder(textView)
    }
}

// MARK: - Formatting Toolbar

struct FormattingToolbar: View {
    @Binding var text: String
    @ObservedObject var coordinator: TextViewCoordinator

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ToolbarButton(icon: "bold", tooltip: "Bold") {
                    coordinator.applyFormatting(prefix: "**", suffix: "**", placeholder: "bold")
                }
                ToolbarButton(icon: "italic", tooltip: "Italic") {
                    coordinator.applyFormatting(prefix: "_", suffix: "_", placeholder: "italic")
                }
                ToolbarButton(icon: "strikethrough", tooltip: "Strikethrough") {
                    coordinator.applyFormatting(prefix: "~~", suffix: "~~", placeholder: "text")
                }

                ToolbarDivider()

                ToolbarButton(icon: "number", tooltip: "Heading") {
                    coordinator.insertAtLineStart(prefix: "## ", placeholder: "Heading")
                }
                ToolbarButton(icon: "list.bullet", tooltip: "Bullet List") {
                    coordinator.insertAtLineStart(prefix: "- ", placeholder: "Item")
                }
                ToolbarButton(icon: "checklist", tooltip: "Checkbox") {
                    coordinator.insertAtLineStart(prefix: "- [ ] ", placeholder: "Task")
                }

                ToolbarDivider()

                ToolbarButton(icon: "chevron.left.forwardslash.chevron.right", tooltip: "Inline Code") {
                    coordinator.applyFormatting(prefix: "`", suffix: "`", placeholder: "code")
                }
                ToolbarButton(icon: "doc.text", tooltip: "Code Block") {
                    coordinator.insertCodeBlock()
                }

                ToolbarDivider()

                ToolbarButton(icon: "link", tooltip: "Link") {
                    coordinator.insertLink()
                }
                ToolbarButton(icon: "quote.opening", tooltip: "Quote") {
                    coordinator.insertAtLineStart(prefix: "> ", placeholder: "Quote")
                }
                ToolbarButton(icon: "minus", tooltip: "Divider") {
                    coordinator.insertText("\n---\n")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
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

// MARK: - Markdown Text Editor (NSTextView with MarkdownTextStorage)

struct MarkdownTextEditor: NSViewRepresentable {
    @Binding var text: String
    @ObservedObject var coordinator: TextViewCoordinator

    func makeNSView(context: Context) -> NSScrollView {
        // Create custom text storage with markdown styling
        let textStorage = MarkdownTextStorage()

        // Create layout manager
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        // Create text container
        let textContainer = NSTextContainer()
        textContainer.widthTracksTextView = true
        textContainer.heightTracksTextView = false
        layoutManager.addTextContainer(textContainer)

        // Create text view with custom text storage
        let textView = NSTextView(frame: .zero, textContainer: textContainer)
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.backgroundColor = .clear
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.textContainerInset = NSSize(width: 0, height: 8)

        // Set initial text
        textView.string = text

        // Store reference in coordinator for toolbar access
        self.coordinator.textView = textView

        // Create scroll view
        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        // Configure autoresizing
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0, height: 0)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Update coordinator reference
        self.coordinator.textView = textView

        // Only update if text has changed externally
        if textView.string != text {
            let selectedRange = textView.selectedRange()
            textView.string = text

            // Restore selection if possible
            let newLength = textView.string.count
            if selectedRange.location <= newLength {
                let adjustedLength = min(selectedRange.length, newLength - selectedRange.location)
                textView.setSelectedRange(NSRange(location: selectedRange.location, length: adjustedLength))
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownTextEditor

        init(_ parent: MarkdownTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}
