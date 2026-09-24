/// Presentation-only wrapping. Stored menu titles and returned values do not change.
public enum TitleLines {
    public static let maximumCharacters = 20

    /// Counts Swift Characters (extended grapheme clusters), including spaces.
    /// Explicit newlines are retained; horizontal whitespace becomes one space.
    /// An indivisible word may exceed the limit and occupies a line of its own.
    public static func wrap(_ title: String) -> [String] {
        title.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).flatMap { paragraph in
            var lines: [String] = [], current = ""
            for word in paragraph.split(whereSeparator: \.isWhitespace) {
                if !current.isEmpty && current.count + 1 + word.count > maximumCharacters {
                    lines.append(current)
                    current = String(word)
                } else {
                    current += (current.isEmpty ? "" : " ") + word
                }
            }
            lines.append(current)
            return lines
        }
    }
}
