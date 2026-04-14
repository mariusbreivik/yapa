import Foundation
import CoreGraphics

func buildFuzzySearchQuery(_ query: String) -> String {
    let words = query
        .lowercased()
        .split { $0.isWhitespace || $0.isNewline || $0.isPunctuation }
        .map { term -> String in
            let cleaned = term.filter { $0.isLetter || $0.isNumber }
            return cleaned.isEmpty ? "" : "\(cleaned)*"
        }
        .filter { !$0.isEmpty }

    return words.joined(separator: " ")
}

func sidebarTreeLeadingPadding(forDepth depth: Int) -> CGFloat {
    guard depth > 1 else {
        return 0
    }

    return 22 + CGFloat(depth - 2) * 20
}
