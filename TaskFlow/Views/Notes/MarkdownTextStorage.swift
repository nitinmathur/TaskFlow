import AppKit

/// Custom NSTextStorage that stores plain markdown but applies rich text styling for display.
/// This provides live WYSIWYG-style rendering while preserving the underlying markdown syntax.
class MarkdownTextStorage: NSTextStorage {

    // MARK: - Properties

    private let backingStore = NSMutableAttributedString()

    /// Default font for body text
    private let bodyFont: NSFont = .systemFont(ofSize: 14)

    /// Monospaced font for code
    private let codeFont: NSFont = .monospacedSystemFont(ofSize: 13, weight: .regular)

    /// Default text color
    private let textColor: NSColor = .textColor

    /// Color for markdown syntax characters
    private let syntaxColor: NSColor = .tertiaryLabelColor

    /// Color for code text
    private let codeColor: NSColor = .systemPurple

    /// Color for links
    private let linkColor: NSColor = .systemBlue

    // MARK: - NSTextStorage Required Overrides

    override var string: String {
        backingStore.string
    }

    override func attributes(at location: Int, effectiveRange range: NSRangePointer?) -> [NSAttributedString.Key: Any] {
        guard location < backingStore.length else {
            return [:]
        }
        return backingStore.attributes(at: location, effectiveRange: range)
    }

    override func replaceCharacters(in range: NSRange, with str: String) {
        beginEditing()
        backingStore.replaceCharacters(in: range, with: str)
        edited(.editedCharacters, range: range, changeInLength: str.count - range.length)
        endEditing()
    }

    override func setAttributes(_ attrs: [NSAttributedString.Key: Any]?, range: NSRange) {
        beginEditing()
        backingStore.setAttributes(attrs, range: range)
        edited(.editedAttributes, range: range, changeInLength: 0)
        endEditing()
    }

    // MARK: - Markdown Processing

    override func processEditing() {
        applyMarkdownStyling()
        super.processEditing()
    }

    /// Applies markdown styling to the entire document
    private func applyMarkdownStyling() {
        let fullRange = NSRange(location: 0, length: backingStore.length)
        guard fullRange.length > 0 else { return }

        // Reset to default styling first
        backingStore.addAttributes([
            .font: bodyFont,
            .foregroundColor: textColor
        ], range: fullRange)

        let text = backingStore.string

        // Process line-based patterns (headings, lists)
        applyLinePatterns(text)

        // Process inline patterns (bold, italic, code, links)
        applyInlinePatterns(text)
    }

    // MARK: - Line Patterns

    private func applyLinePatterns(_ text: String) {
        let lines = text.components(separatedBy: "\n")
        var currentIndex = 0

        for line in lines {
            let lineRange = NSRange(location: currentIndex, length: line.count)

            if line.hasPrefix("### ") {
                applyHeadingStyle(range: lineRange, level: 3, prefixLength: 4)
            } else if line.hasPrefix("## ") {
                applyHeadingStyle(range: lineRange, level: 2, prefixLength: 3)
            } else if line.hasPrefix("# ") {
                applyHeadingStyle(range: lineRange, level: 1, prefixLength: 2)
            } else if line.hasPrefix("- [ ] ") || line.hasPrefix("- [x] ") || line.hasPrefix("- [X] ") {
                applyCheckboxStyle(range: lineRange, line: line)
            } else if line.hasPrefix("- ") {
                applyBulletStyle(range: lineRange)
            } else if line.hasPrefix("> ") {
                applyBlockquoteStyle(range: lineRange)
            } else if line == "---" {
                applyDividerStyle(range: lineRange)
            }

            currentIndex += line.count + 1 // +1 for newline
        }
    }

    private func applyHeadingStyle(range: NSRange, level: Int, prefixLength: Int) {
        guard range.location + range.length <= backingStore.length else { return }

        let fontSize: CGFloat
        switch level {
        case 1: fontSize = 24
        case 2: fontSize = 20
        default: fontSize = 16
        }

        let headingFont = NSFont.boldSystemFont(ofSize: fontSize)

        // Style the prefix (# symbols) in syntax color
        let prefixRange = NSRange(location: range.location, length: prefixLength)
        backingStore.addAttribute(.foregroundColor, value: syntaxColor, range: prefixRange)

        // Style the heading text
        backingStore.addAttribute(.font, value: headingFont, range: range)
    }

    private func applyCheckboxStyle(range: NSRange, line: String) {
        guard range.location + range.length <= backingStore.length else { return }

        // Style the checkbox syntax
        let prefixRange = NSRange(location: range.location, length: 6)
        backingStore.addAttribute(.foregroundColor, value: syntaxColor, range: prefixRange)

        // If checked, apply strikethrough to the text
        let isChecked = line.hasPrefix("- [x] ") || line.hasPrefix("- [X] ")
        if isChecked && range.length > 6 {
            let textRange = NSRange(location: range.location + 6, length: range.length - 6)
            backingStore.addAttributes([
                .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                .foregroundColor: NSColor.secondaryLabelColor
            ], range: textRange)
        }
    }

    private func applyBulletStyle(range: NSRange) {
        guard range.location + 2 <= backingStore.length else { return }

        // Style the bullet marker
        let bulletRange = NSRange(location: range.location, length: 2)
        backingStore.addAttribute(.foregroundColor, value: syntaxColor, range: bulletRange)
    }

    private func applyBlockquoteStyle(range: NSRange) {
        guard range.location + range.length <= backingStore.length else { return }

        // Style quote marker
        let markerRange = NSRange(location: range.location, length: 2)
        backingStore.addAttribute(.foregroundColor, value: linkColor, range: markerRange)

        // Style quoted text
        backingStore.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: range)
    }

    private func applyDividerStyle(range: NSRange) {
        guard range.location + range.length <= backingStore.length else { return }
        backingStore.addAttribute(.foregroundColor, value: syntaxColor, range: range)
    }

    // MARK: - Inline Patterns

    private func applyInlinePatterns(_ text: String) {
        // Bold: **text**
        applyPattern(
            text: text,
            pattern: "\\*\\*([^*]+)\\*\\*",
            syntaxLength: 2,
            contentAttributes: [.font: NSFont.boldSystemFont(ofSize: 14)]
        )

        // Italic: _text_
        applyPattern(
            text: text,
            pattern: "(?<![\\w])_([^_]+)_(?![\\w])",
            syntaxLength: 1,
            contentAttributes: [.font: NSFontManager.shared.convert(bodyFont, toHaveTrait: .italicFontMask)]
        )

        // Strikethrough: ~~text~~
        applyPattern(
            text: text,
            pattern: "~~([^~]+)~~",
            syntaxLength: 2,
            contentAttributes: [.strikethroughStyle: NSUnderlineStyle.single.rawValue]
        )

        // Inline code: `code`
        applyPattern(
            text: text,
            pattern: "`([^`]+)`",
            syntaxLength: 1,
            contentAttributes: [
                .font: codeFont,
                .foregroundColor: codeColor,
                .backgroundColor: NSColor.controlBackgroundColor
            ]
        )

        // Links: [text](url)
        applyLinkPattern(text: text)
    }

    private func applyPattern(
        text: String,
        pattern: String,
        syntaxLength: Int,
        contentAttributes: [NSAttributedString.Key: Any]
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

        let matches = regex.matches(in: text, range: NSRange(location: 0, length: text.utf16.count))

        for match in matches {
            let fullRange = match.range
            guard fullRange.location + fullRange.length <= backingStore.length else { continue }

            // Apply content attributes to full match (visible styling)
            backingStore.addAttributes(contentAttributes, range: fullRange)

            // Dim the syntax characters
            let openRange = NSRange(location: fullRange.location, length: syntaxLength)
            let closeRange = NSRange(location: fullRange.location + fullRange.length - syntaxLength, length: syntaxLength)

            backingStore.addAttribute(.foregroundColor, value: syntaxColor, range: openRange)
            backingStore.addAttribute(.foregroundColor, value: syntaxColor, range: closeRange)
        }
    }

    private func applyLinkPattern(text: String) {
        let pattern = "\\[([^\\]]+)\\]\\(([^)]+)\\)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

        let matches = regex.matches(in: text, range: NSRange(location: 0, length: text.utf16.count))

        for match in matches {
            let fullRange = match.range
            guard fullRange.location + fullRange.length <= backingStore.length else { continue }

            // Get the URL from the second capture group
            if match.numberOfRanges > 2 {
                let urlRange = match.range(at: 2)
                if let swiftRange = Range(urlRange, in: text) {
                    let urlString = String(text[swiftRange])

                    // Apply link styling to the entire match
                    backingStore.addAttributes([
                        .foregroundColor: linkColor,
                        .underlineStyle: NSUnderlineStyle.single.rawValue
                    ], range: fullRange)

                    // If it's a valid URL, make it clickable
                    if let url = URL(string: urlString) {
                        backingStore.addAttribute(.link, value: url, range: fullRange)
                    }
                }
            }
        }
    }
}
