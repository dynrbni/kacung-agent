import SwiftUI
import AppKit

// MARK: - Markdown Block AST

public enum MarkdownBlock: Identifiable, Equatable {
    case heading1(String)
    case heading2(String)
    case heading3(String)
    case heading4(String)
    case bullet(String, indent: Int)
    case numbered(String, num: Int, indent: Int)
    case paragraph(String)
    case codeBlock(code: String, lang: String?)
    case tableRow(cells: [String], isHeader: Bool)
    case divider

    public var id: String {
        switch self {
        case .heading1(let s): return "h1_\(s.hashValue)"
        case .heading2(let s): return "h2_\(s.hashValue)"
        case .heading3(let s): return "h3_\(s.hashValue)"
        case .heading4(let s): return "h4_\(s.hashValue)"
        case .bullet(let s, let i): return "bullet_\(i)_\(s.hashValue)"
        case .numbered(let s, let n, let i): return "num_\(i)_\(n)_\(s.hashValue)"
        case .paragraph(let s): return "p_\(s.hashValue)"
        case .codeBlock(let c, let l): return "code_\(l ?? "")_\(c.hashValue)"
        case .tableRow(let c, let h): return "tr_\(h)_\(c.joined().hashValue)"
        case .divider: return "divider"
        }
    }
}

// MARK: - Markdown Parser

public struct MarkdownParser {
    public static func parse(_ text: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let lines = text.components(separatedBy: .newlines)
        var inCodeBlock = false
        var codeLang: String? = nil
        var codeLines: [String] = []
        var pendingEmptyLines = 0

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Code block delimiter
            if trimmed.hasPrefix("```") {
                if inCodeBlock {
                    inCodeBlock = false
                    blocks.append(.codeBlock(code: codeLines.joined(separator: "\n"), lang: codeLang))
                    codeLines = []
                    codeLang = nil
                } else {
                    inCodeBlock = true
                    let lang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    codeLang = lang.isEmpty ? nil : lang
                }
                pendingEmptyLines = 0
                continue
            }

            if inCodeBlock {
                codeLines.append(line)
                continue
            }

            // Skip empty lines (acts as block separators)
            if trimmed.isEmpty {
                pendingEmptyLines += 1
                continue
            }

            // Table delimiter line (e.g. |---|---| or |:---:|---|)
            if trimmed.range(of: #"^\|[\s\-:|]+\|$"#, options: .regularExpression) != nil {
                pendingEmptyLines = 0
                continue
            }

            // Table row
            if trimmed.hasPrefix("|") && trimmed.hasSuffix("|") && trimmed.contains("|") {
                let rawCells = trimmed.split(separator: "|", omittingEmptySubsequences: true)
                let cells = rawCells.map { $0.trimmingCharacters(in: .whitespaces) }
                if !cells.isEmpty {
                    let isHeader = blocks.isEmpty || !isPreviousBlockTableRow(blocks)
                    blocks.append(.tableRow(cells: cells, isHeader: isHeader))
                    pendingEmptyLines = 0
                    continue
                }
            }

            // Horizontal rule
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                blocks.append(.divider)
                pendingEmptyLines = 0
                continue
            }

            // Headings (#, ##, ###, ####)
            if trimmed.hasPrefix("#") {
                let hashCount = trimmed.prefix(while: { $0 == "#" }).count
                let remainder = trimmed.dropFirst(hashCount)
                if remainder.hasPrefix(" ") || hashCount >= 2 {
                    let content = remainder.trimmingCharacters(in: .whitespaces)
                    if hashCount == 1 {
                        blocks.append(.heading1(content))
                    } else if hashCount == 2 {
                        blocks.append(.heading2(content))
                    } else if hashCount == 3 {
                        blocks.append(.heading3(content))
                    } else {
                        blocks.append(.heading4(content))
                    }
                    pendingEmptyLines = 0
                    continue
                }
            }

            let leadingSpaces = line.prefix(while: { $0 == " " || $0 == "\t" }).count
            let indent = min(leadingSpaces / 2, 4)

            // Unordered list (- , * , + )
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                let content = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                blocks.append(.bullet(content, indent: indent))
                pendingEmptyLines = 0
                continue
            }

            // Ordered list (1. , 2) , etc.)
            if let match = trimmed.range(of: #"^\d+[\.\)]\s+"#, options: .regularExpression) {
                let numStr = trimmed[match].filter { $0.isNumber }
                let num = Int(numStr) ?? 1
                let content = String(trimmed[match.upperBound...]).trimmingCharacters(in: .whitespaces)
                blocks.append(.numbered(content, num: num, indent: indent))
                pendingEmptyLines = 0
                continue
            }

            // Regular paragraph line: merge into previous paragraph if not separated by empty line
            if pendingEmptyLines == 0, let last = blocks.last, case .paragraph(let prevContent) = last {
                blocks[blocks.count - 1] = .paragraph(prevContent + "\n" + trimmed)
            } else {
                blocks.append(.paragraph(trimmed))
            }
            pendingEmptyLines = 0
        }

        if inCodeBlock && !codeLines.isEmpty {
            blocks.append(.codeBlock(code: codeLines.joined(separator: "\n"), lang: codeLang))
        }

        return blocks
    }

    private static func isPreviousBlockTableRow(_ blocks: [MarkdownBlock]) -> Bool {
        guard let last = blocks.last else { return false }
        if case .tableRow = last { return true }
        return false
    }

    /// Fix unclosed inline markdown delimiters (e.g. during live streaming)
    public static func sanitizeInlineMarkdown(_ text: String) -> String {
        var fixed = text
        let boldParts = fixed.components(separatedBy: "**")
        if boldParts.count % 2 == 0 {
            fixed += "**"
        }
        let codeParts = fixed.components(separatedBy: "`")
        if codeParts.count % 2 == 0 {
            fixed += "`"
        }
        return fixed
    }

    /// Produces a styled AttributedString with native bold/italic/code, stripping raw markdown punctuation.
    public static func inlineAttributedString(_ text: String) -> AttributedString {
        let sanitized = sanitizeInlineMarkdown(text)
        if let attr = try? AttributedString(markdown: sanitized, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            return attr
        }
        return AttributedString(text)
    }
}

// MARK: - Rich Markdown SwiftUI View

public struct RichMarkdownView: View {
    let text: String

    public init(text: String) {
        self.text = text
    }

    public var body: some View {
        let blocks = MarkdownParser.parse(text)

        VStack(alignment: .leading, spacing: 14) {
            ForEach(blocks) { block in
                blockView(for: block)
            }
        }
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func blockView(for block: MarkdownBlock) -> some View {
        switch block {
        case .heading1(let content):
            Text(MarkdownParser.inlineAttributedString(content))
                .font(.system(size: 20, weight: .bold))
                .lineSpacing(5)
                .foregroundStyle(.primary)
                .padding(.top, 12)
                .padding(.bottom, 2)

        case .heading2(let content):
            Text(MarkdownParser.inlineAttributedString(content))
                .font(.system(size: 17.5, weight: .bold))
                .lineSpacing(4.5)
                .foregroundStyle(.primary)
                .padding(.top, 10)
                .padding(.bottom, 2)

        case .heading3(let content):
            Text(MarkdownParser.inlineAttributedString(content))
                .font(.system(size: 15.5, weight: .semibold))
                .lineSpacing(4)
                .foregroundStyle(.primary)
                .padding(.top, 8)
                .padding(.bottom, 1)

        case .heading4(let content):
            Text(MarkdownParser.inlineAttributedString(content))
                .font(.system(size: 14.5, weight: .semibold))
                .lineSpacing(4)
                .foregroundStyle(.primary)
                .padding(.top, 6)
                .padding(.bottom, 1)

        case .bullet(let content, let indent):
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Text("•")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.secondary.opacity(0.8))
                    .frame(width: 8, alignment: .center)
                Text(MarkdownParser.inlineAttributedString(content))
                    .font(.system(size: 14.5, weight: .regular))
                    .lineSpacing(5.5)
                    .foregroundStyle(.primary)
            }
            .padding(.leading, CGFloat(indent * 18))
            .padding(.vertical, 3)

        case .numbered(let content, let num, let indent):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(num).")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(minWidth: 20, alignment: .leading)
                Text(MarkdownParser.inlineAttributedString(content))
                    .font(.system(size: 14.5, weight: .regular))
                    .lineSpacing(5.5)
                    .foregroundStyle(.primary)
            }
            .padding(.leading, CGFloat(indent * 18))
            .padding(.top, indent == 0 ? 6 : 2)
            .padding(.bottom, 2)

        case .paragraph(let content):
            Text(MarkdownParser.inlineAttributedString(content))
                .font(.system(size: 14.5, weight: .regular))
                .lineSpacing(5.5)
                .foregroundStyle(.primary)
                .padding(.bottom, 2)

        case .codeBlock(let code, let lang):
            CodeBlockView(code: code, lang: lang)

        case .tableRow(let cells, let isHeader):
            HStack(alignment: .top, spacing: 12) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                    Text(MarkdownParser.inlineAttributedString(cell))
                        .font(isHeader ? .system(size: 13.5, weight: .bold) : .system(size: 13.5, weight: .regular))
                        .foregroundStyle(isHeader ? .primary : .secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(isHeader ? Color.primary.opacity(0.05) : Color.clear)
            .cornerRadius(4)

        case .divider:
            Divider()
                .padding(.vertical, 6)
        }
    }
}

// MARK: - Code Block View

private struct CodeBlockView: View {
    let code: String
    let lang: String?
    @State private var didCopy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if let lang = lang, !lang.isEmpty {
                    Text(lang.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                } else {
                    Text("CODE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                    didCopy = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        didCopy = false
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10))
                        Text(didCopy ? "Copied" : "Copy")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.04))

            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(size: 12.5, design: .monospaced))
                    .padding(12)
                    .textSelection(.enabled)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(LoflyTheme.separator.opacity(0.6), lineWidth: 0.5)
        )
        .padding(.vertical, 4)
    }
}
