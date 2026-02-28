import SwiftUI

struct MarkdownRenderer: View {
    let text: String

    var body: some View {
        if text.isEmpty {
            Text("No content")
                .foregroundStyle(.tertiary)
                .italic()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(text.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                    renderLine(line)
                }
            }
        }
    }

    @ViewBuilder
    private func renderLine(_ line: String) -> some View {
        if line.isEmpty {
            Spacer().frame(height: 8)
        } else if line.hasPrefix("## ") {
            Text(line.dropFirst(3))
                .font(.title2.bold())
                .padding(.top, 8)
        } else if line.hasPrefix("# ") {
            Text(line.dropFirst(2))
                .font(.title.bold())
                .padding(.top, 8)
        } else if line.hasPrefix("### ") {
            Text(line.dropFirst(4))
                .font(.headline)
                .padding(.top, 4)
        } else if line.hasPrefix("- [ ] ") {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "square")
                    .foregroundStyle(.secondary)
                renderInlineMarkdown(String(line.dropFirst(6)))
            }
        } else if line.hasPrefix("- [x] ") || line.hasPrefix("- [X] ") {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "checkmark.square.fill")
                    .foregroundStyle(.green)
                renderInlineMarkdown(String(line.dropFirst(6)))
                    .strikethrough()
                    .foregroundStyle(.secondary)
            }
        } else if line.hasPrefix("- ") {
            HStack(alignment: .top, spacing: 8) {
                Text("•").foregroundStyle(.secondary)
                renderInlineMarkdown(String(line.dropFirst(2)))
            }
        } else if line.hasPrefix("> ") {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.blue.opacity(0.5))
                    .frame(width: 3)
                renderInlineMarkdown(String(line.dropFirst(2)))
                    .padding(.leading, 10)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        } else if line.hasPrefix("```") {
            // Skip code fence markers
            EmptyView()
        } else if line == "---" {
            Divider().padding(.vertical, 8)
        } else {
            renderInlineMarkdown(line)
        }
    }

    @ViewBuilder
    private func renderInlineMarkdown(_ text: String) -> some View {
        Text(parseInline(text))
    }

    private func parseInline(_ text: String) -> AttributedString {
        var result = AttributedString(text)

        // Code: `code`
        result = applyPattern(result, pattern: "`([^`]+)`") { match in
            var attr = AttributedString(match)
            attr.font = .system(.body, design: .monospaced)
            attr.backgroundColor = Color(nsColor: .controlBackgroundColor)
            return attr
        }

        // Bold: **text**
        result = applyPattern(result, pattern: "\\*\\*([^*]+)\\*\\*") { match in
            var attr = AttributedString(match)
            attr.font = .body.bold()
            return attr
        }

        // Italic: _text_
        result = applyPattern(result, pattern: "_([^_]+)_") { match in
            var attr = AttributedString(match)
            attr.font = .body.italic()
            return attr
        }

        // Strikethrough: ~~text~~
        result = applyPattern(result, pattern: "~~([^~]+)~~") { match in
            var attr = AttributedString(match)
            attr.strikethroughStyle = .single
            return attr
        }

        // Links: [text](url)
        result = applyLinkPattern(result)

        return result
    }

    private func applyPattern(_ input: AttributedString, pattern: String, transform: (String) -> AttributedString) -> AttributedString {
        let plainText = String(input.characters)
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return input }

        var result = input
        let matches = regex.matches(in: plainText, range: NSRange(plainText.startIndex..., in: plainText))

        for match in matches.reversed() {
            guard let fullRange = Range(match.range, in: plainText),
                  let contentRange = Range(match.range(at: 1), in: plainText) else { continue }

            let content = String(plainText[contentRange])
            let attrStart = AttributedString.Index(fullRange.lowerBound, within: result)
            let attrEnd = AttributedString.Index(fullRange.upperBound, within: result)

            if let start = attrStart, let end = attrEnd {
                result.replaceSubrange(start..<end, with: transform(content))
            }
        }
        return result
    }

    private func applyLinkPattern(_ input: AttributedString) -> AttributedString {
        let plainText = String(input.characters)
        let pattern = "\\[([^\\]]+)\\]\\(([^)]+)\\)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return input }

        var result = input
        let matches = regex.matches(in: plainText, range: NSRange(plainText.startIndex..., in: plainText))

        for match in matches.reversed() {
            guard let fullRange = Range(match.range, in: plainText),
                  let textRange = Range(match.range(at: 1), in: plainText),
                  let urlRange = Range(match.range(at: 2), in: plainText) else { continue }

            let linkText = String(plainText[textRange])
            let urlString = String(plainText[urlRange])

            var linkAttr = AttributedString(linkText)
            linkAttr.foregroundColor = .blue
            linkAttr.underlineStyle = .single
            if let url = URL(string: urlString) {
                linkAttr.link = url
            }

            let attrStart = AttributedString.Index(fullRange.lowerBound, within: result)
            let attrEnd = AttributedString.Index(fullRange.upperBound, within: result)

            if let start = attrStart, let end = attrEnd {
                result.replaceSubrange(start..<end, with: linkAttr)
            }
        }
        return result
    }
}
