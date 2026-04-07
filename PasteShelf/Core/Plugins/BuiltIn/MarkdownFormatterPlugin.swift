#if !APP_STORE
//
    //  MarkdownFormatterPlugin.swift
    //  PasteShelf
//
    //  Built-in Markdown Formatter plugin.
    //  Converts HTML to Markdown and formats Markdown tables.
//

    import AppKit
    import Foundation
    import SwiftUI

    /// Markdown Formatter plugin - converts HTML and formats Markdown
    @objc(MarkdownFormatter)
    public final class MarkdownFormatterPlugin: NSObject, PasteShelfPlugin {
        // MARK: Public

        public func didLoad(with context: any PluginContext) {
            self.context = context
            context.logger.info("Markdown Formatter loaded")

            Task { @MainActor in
                self.registerTransformers()
            }
        }

        public func willUnload() {
            self.context?.logger.info("Markdown Formatter unloading")

            Task { @MainActor in
                PluginTransformAPI.shared.unregisterTransformers(for: Self.identifier)
                PluginUIAPI.shared.unregisterMenuItems(for: Self.identifier)
            }
        }

        // MARK: - Menu Items

        public func menuItems() -> [PluginMenuItem] {
            [
                PluginMenuItem(
                    title: "HTML to Markdown",
                    iconName: "doc.text",
                    shortcutKey: "M+command+shift"
                ) { [weak self] content in
                    try await self?.htmlToMarkdown(content)
                },
                PluginMenuItem(
                    title: "Format Markdown Table",
                    iconName: "tablecells"
                ) { [weak self] content in
                    try await self?.formatMarkdownTable(content)
                },
                PluginMenuItem(
                    title: "Strip Markdown",
                    iconName: "text.badge.minus"
                ) { [weak self] content in
                    try await self?.stripMarkdown(content)
                },
            ]
        }

        // MARK: Internal

        // MARK: - Plugin Metadata

        static let identifier = "com.pasteshelf.plugins.markdownformatter"
        static let name = "Markdown Formatter"
        static let version = "1.0.0"
        static let supportedTypes: [ContentType] = [.plainText, .html]

        // MARK: - Internal Transform

        /// Transforms content (used internally by plugin system)
        func transform(content: PluginClipboardContent) async throws -> PluginClipboardContent? {
            // Default transform: HTML to Markdown if HTML present
            if content.html != nil {
                return try await self.htmlToMarkdown(content)
            }
            return nil
        }

        /// Checks if content type is supported (used internally by plugin system)
        func supports(contentType: ContentType) -> Bool {
            Self.supportedTypes.contains(contentType)
        }

        // MARK: Private

        // MARK: - State

        private var context: (any PluginContext)?

        // MARK: - Transformer Registration

        @MainActor
        private func registerTransformers() {
            // HTML to Markdown
            PluginTransformAPI.shared.registerTransformer(
                pluginId: Self.identifier,
                name: "HTML to Markdown",
                description: "Convert HTML content to Markdown",
                supportedTypes: [.html, .plainText],
                iconName: "doc.text"
            ) { [weak self] content in
                try await self?.htmlToMarkdown(content)
            }

            // Format Markdown Table
            PluginTransformAPI.shared.registerTransformer(
                pluginId: Self.identifier,
                name: "Format Markdown Table",
                description: "Align columns in Markdown tables",
                supportedTypes: [.plainText],
                iconName: "tablecells"
            ) { [weak self] content in
                try await self?.formatMarkdownTable(content)
            }

            // Strip Markdown
            PluginTransformAPI.shared.registerTransformer(
                pluginId: Self.identifier,
                name: "Strip Markdown",
                description: "Remove Markdown formatting",
                supportedTypes: [.plainText],
                iconName: "text.badge.minus"
            ) { [weak self] content in
                try await self?.stripMarkdown(content)
            }
        }

        // MARK: - Markdown Operations

        @MainActor
        private func htmlToMarkdown(_ content: PluginClipboardContent) throws -> PluginClipboardContent? {
            let html = content.html ?? content.text ?? ""
            guard !html.isEmpty else {
                return nil
            }

            let markdown = self.convertHTMLToMarkdown(html)

            let result = PluginClipboardContent(text: markdown)
            result.metadata["convertedFromHTML"] = true
            return result
        }

        @MainActor
        private func formatMarkdownTable(_ content: PluginClipboardContent) throws -> PluginClipboardContent? {
            guard let text = content.text else {
                return nil
            }

            // Check if content contains a Markdown table
            guard text.contains("|"), text.contains("-") else {
                return nil
            }

            let formatted = self.formatTable(text)

            let result = PluginClipboardContent(text: formatted)
            result.metadata["tableFormatted"] = true
            return result
        }

        @MainActor
        private func stripMarkdown(_ content: PluginClipboardContent) throws -> PluginClipboardContent? {
            guard let text = content.text else {
                return nil
            }

            let stripped = self.removeMarkdownFormatting(text)

            let result = PluginClipboardContent(text: stripped)
            result.metadata["markdownStripped"] = true
            return result
        }

        // MARK: - HTML to Markdown Conversion

        // swiftlint:disable:next function_body_length
        private func convertHTMLToMarkdown(_ html: String) -> String {
            var result = html

            // Remove scripts and styles
            result = result.replacingOccurrences(
                of: "<script[^>]*>[\\s\\S]*?</script>",
                with: "",
                options: .regularExpression
            )
            result = result.replacingOccurrences(
                of: "<style[^>]*>[\\s\\S]*?</style>",
                with: "",
                options: .regularExpression
            )

            // Headings
            for i in (1 ... 6).reversed() {
                let pattern = "<h\(i)[^>]*>(.*?)</h\(i)>"
                let replacement = String(repeating: "#", count: i) + " $1\n\n"
                result = result.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
            }

            // Bold
            result = result.replacingOccurrences(
                of: "<(strong|b)>(.*?)</\\1>",
                with: "**$2**",
                options: .regularExpression
            )

            // Italic
            result = result.replacingOccurrences(of: "<(em|i)>(.*?)</\\1>", with: "*$2*", options: .regularExpression)

            // Code
            result = result.replacingOccurrences(of: "<code>(.*?)</code>", with: "`$1`", options: .regularExpression)

            // Pre/code blocks
            result = result.replacingOccurrences(
                of: "<pre[^>]*><code[^>]*>(.*?)</code></pre>",
                with: "```\n$1\n```\n",
                options: .regularExpression
            )

            // Links
            result = result.replacingOccurrences(
                of: "<a[^>]*href=\"([^\"]*)\"[^>]*>(.*?)</a>",
                with: "[$2]($1)",
                options: .regularExpression
            )

            // Images
            result = result.replacingOccurrences(
                of: "<img[^>]*src=\"([^\"]*)\"[^>]*alt=\"([^\"]*)\"[^>]*/?>",
                with: "![$2]($1)",
                options: .regularExpression
            )
            result = result.replacingOccurrences(
                of: "<img[^>]*src=\"([^\"]*)\"[^>]*/?>",
                with: "![]($1)",
                options: .regularExpression
            )

            // Lists
            result = result.replacingOccurrences(of: "<ul[^>]*>", with: "", options: .regularExpression)
            result = result.replacingOccurrences(of: "</ul>", with: "\n", options: .regularExpression)
            result = result.replacingOccurrences(of: "<ol[^>]*>", with: "", options: .regularExpression)
            result = result.replacingOccurrences(of: "</ol>", with: "\n", options: .regularExpression)
            result = result.replacingOccurrences(of: "<li[^>]*>(.*?)</li>", with: "- $1\n", options: .regularExpression)

            // Paragraphs
            result = result.replacingOccurrences(of: "<p[^>]*>(.*?)</p>", with: "$1\n\n", options: .regularExpression)

            // Line breaks
            result = result.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)

            // Horizontal rules
            result = result.replacingOccurrences(of: "<hr\\s*/?>", with: "\n---\n", options: .regularExpression)

            // Blockquotes
            result = result.replacingOccurrences(
                of: "<blockquote[^>]*>(.*?)</blockquote>",
                with: "> $1\n",
                options: .regularExpression
            )

            // Remove remaining tags
            result = result.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

            // Decode HTML entities
            result = self.decodeHTMLEntities(result)

            // Clean up whitespace
            result = result.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
            result = result.trimmingCharacters(in: .whitespacesAndNewlines)

            return result
        }

        private func decodeHTMLEntities(_ string: String) -> String {
            var result = string
            let entities: [String: String] = [
                "&amp;": "&",
                "&lt;": "<",
                "&gt;": ">",
                "&quot;": "\"",
                "&apos;": "'",
                "&nbsp;": " ",
                "&#39;": "'",
            ]

            for (entity, char) in entities {
                result = result.replacingOccurrences(of: entity, with: char)
            }

            return result
        }

        // MARK: - Table Formatting

        private func formatTable(_ text: String) -> String {
            let lines = text.components(separatedBy: .newlines)
            var tableLines: [[String]] = []
            var maxWidths: [Int] = []
            var inTable = false
            var resultLines: [String] = []

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                if trimmed.hasPrefix("|"), trimmed.hasSuffix("|") {
                    inTable = true
                    let cells = trimmed
                        .dropFirst()
                        .dropLast()
                        .components(separatedBy: "|")
                        .map { $0.trimmingCharacters(in: .whitespaces) }

                    // Track max widths
                    for (i, cell) in cells.enumerated() {
                        if i >= maxWidths.count {
                            maxWidths.append(cell.count)
                        } else {
                            maxWidths[i] = max(maxWidths[i], cell.count)
                        }
                    }

                    tableLines.append(cells)
                } else {
                    if inTable, !tableLines.isEmpty {
                        // Output formatted table
                        resultLines.append(contentsOf: self.formatTableLines(tableLines, maxWidths: maxWidths))
                        tableLines = []
                        maxWidths = []
                        inTable = false
                    }
                    resultLines.append(line)
                }
            }

            // Handle table at end
            if !tableLines.isEmpty {
                resultLines.append(contentsOf: self.formatTableLines(tableLines, maxWidths: maxWidths))
            }

            return resultLines.joined(separator: "\n")
        }

        private func formatTableLines(_ lines: [[String]], maxWidths: [Int]) -> [String] {
            var result: [String] = []

            for (index, cells) in lines.enumerated() {
                var formattedCells: [String] = []

                for (i, cell) in cells.enumerated() {
                    let width = i < maxWidths.count ? maxWidths[i] : cell.count

                    // Check if this is a separator row
                    if cell.allSatisfy({ $0 == "-" || $0 == ":" }) {
                        let separator = String(repeating: "-", count: width)
                        formattedCells.append(separator)
                    } else {
                        formattedCells.append(cell.padding(toLength: width, withPad: " ", startingAt: 0))
                    }
                }

                result.append("| " + formattedCells.joined(separator: " | ") + " |")
            }

            return result
        }

        // MARK: - Strip Markdown

        private func removeMarkdownFormatting(_ text: String) -> String {
            var result = text

            // Remove headers
            result = result.replacingOccurrences(of: "^#{1,6}\\s*", with: "", options: .regularExpression)

            // Remove bold/italic
            result = result.replacingOccurrences(of: "\\*\\*([^*]+)\\*\\*", with: "$1", options: .regularExpression)
            result = result.replacingOccurrences(of: "\\*([^*]+)\\*", with: "$1", options: .regularExpression)
            result = result.replacingOccurrences(of: "__([^_]+)__", with: "$1", options: .regularExpression)
            result = result.replacingOccurrences(of: "_([^_]+)_", with: "$1", options: .regularExpression)

            // Remove inline code
            result = result.replacingOccurrences(of: "`([^`]+)`", with: "$1", options: .regularExpression)

            // Remove links (keep text)
            result = result.replacingOccurrences(
                of: "\\[([^\\]]+)\\]\\([^)]+\\)",
                with: "$1",
                options: .regularExpression
            )

            // Remove images
            result = result.replacingOccurrences(of: "!\\[[^\\]]*\\]\\([^)]+\\)", with: "", options: .regularExpression)

            // Remove list markers
            result = result.replacingOccurrences(of: "^[\\-\\*\\+]\\s+", with: "", options: .regularExpression)
            result = result.replacingOccurrences(of: "^\\d+\\.\\s+", with: "", options: .regularExpression)

            // Remove blockquotes
            result = result.replacingOccurrences(of: "^>\\s*", with: "", options: .regularExpression)

            // Remove horizontal rules
            result = result.replacingOccurrences(of: "^[\\-\\*_]{3,}$", with: "", options: .regularExpression)

            return result.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

#endif
