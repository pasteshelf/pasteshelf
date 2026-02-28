//
//  DLPPatternTestView.swift
//  PasteShelf
//
//  Sheet for testing DLP regex patterns against sample text in the Enterprise preferences tab.
//

import SwiftUI

// MARK: - DLPPatternTestView

/// A modal sheet for testing regex patterns against sample text.
///
/// Administrators can paste or type sample clipboard content and a regex pattern,
/// then run the test to see how many matches are found and what substrings matched.
/// This helps verify DLP rule patterns before deploying them.
struct DLPPatternTestView: View {

    // MARK: - Properties

    @Binding var isPresented: Bool

    // MARK: - State

    @State private var testText: String = ""
    @State private var pattern: String = ""
    @State private var matchResults: [String] = []
    @State private var errorMessage: String?
    @State private var hasRun: Bool = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text("Test Pattern")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()

            // Form content
            Form {
                testInputSection
                patternSection
                resultsSection
            }
            .formStyle(.grouped)

            Divider()

            // Bottom button
            HStack {
                Spacer()
                Button("Done") {
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 520)
        .frame(minHeight: 460)
    }

    // MARK: - Test Input Section

    private var testInputSection: some View {
        Section("Test Input") {
            TextEditor(text: $testText)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 80, maxHeight: 120)
                .overlay(
                    Group {
                        if testText.isEmpty {
                            Text("Paste or type sample clipboard content here…")
                                .foregroundStyle(.tertiary)
                                .font(.system(.body, design: .monospaced))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 8)
                                .allowsHitTesting(false)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        }
                    }
                )
        }
    }

    // MARK: - Pattern Section

    private var patternSection: some View {
        Section("Pattern") {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Regular expression pattern", text: $pattern)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.roundedBorder)

                Button("Test Pattern") {
                    runTest()
                }
                .disabled(pattern.trimmingCharacters(in: .whitespaces).isEmpty || testText.isEmpty)
            }
        }
    }

    // MARK: - Results Section

    private var resultsSection: some View {
        Section("Results") {
            if let error = errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.body)
                }
            } else if !hasRun {
                Text("Enter a pattern and tap \"Test Pattern\" to see results.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else if matchResults.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("No matches found")
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(matchResults.count) match\(matchResults.count == 1 ? "" : "es") found")
                        .font(.body)
                        .fontWeight(.medium)

                    ForEach(Array(matchResults.enumerated()), id: \.offset) { index, match in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1).")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 24, alignment: .trailing)

                            Text(match)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Pattern Testing

    private func runTest() {
        let trimmedPattern = pattern.trimmingCharacters(in: .whitespaces)
        let trimmedText = testText

        errorMessage = nil
        matchResults = []
        hasRun = true

        let regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: trimmedPattern, options: [])
        } catch {
            errorMessage = "Invalid regular expression: \(error.localizedDescription)"
            return
        }

        let nsText = trimmedText as NSString
        let range = NSRange(location: 0, length: nsText.length)
        let matches = regex.matches(in: trimmedText, options: [], range: range)

        matchResults = matches.compactMap { match -> String? in
            guard match.range.location != NSNotFound else { return nil }
            return nsText.substring(with: match.range)
        }
    }
}

// MARK: - Previews

#if DEBUG
    struct DLPPatternTestView_Previews: PreviewProvider {
        @State static var isPresented = true

        static var previews: some View {
            DLPPatternTestView(isPresented: $isPresented)
        }
    }
#endif
