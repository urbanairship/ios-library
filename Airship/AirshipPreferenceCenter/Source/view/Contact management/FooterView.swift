/* Copyright Airship and Contributors */

import SwiftUI

struct FooterView: View {
    let text: String
    let textAppearance: PreferenceCenterTheme.TextAppearance

    var body: some View {
        /// Footer
        Text(LocalizedStringKey(text)) /// Markdown parsing in iOS15+
            .textAppearance(textAppearance)
            .fixedSize(horizontal: false, vertical: true)
            .lineLimit(2)
            .applyIf(containsMarkdownLink(text: text)) { view in
                view.accessibilityAddTraits(.isLink)
            }
    }

    private func containsMarkdownLink(text: String) -> Bool {
        if #available(iOS 15, tvOS 15, watchOS 8, *) {
            let text = try? AttributedString(markdown: text)
            return text?.runs.contains(where: { $0.link != nil }) ?? false
        } else {
            let regexPattern = "\\[([^\\]]+)\\]\\(([^\\)]+)\\)"
            return text.range(of: regexPattern, options: .regularExpression) != nil
        }
    }
}
