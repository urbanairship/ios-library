/* Copyright Airship and Contributors */

import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

struct FooterView: View {
    @Environment(\.colorScheme)
    private var colorScheme

    let text: String
    let textAppearance: PreferenceCenterTheme.TextAppearance

    var body: some View {
        /// Footer
        Text(LocalizedStringKey(text)) /// Markdown parsing in iOS15+
            .textAppearance(
                textAppearance,
                colorScheme: colorScheme
            )
            .fixedSize(horizontal: false, vertical: true)
            .lineLimit(2)
            .airshipApplyIf(containsMarkdownLink(text: text)) { view in
                view.accessibilityAddTraits(.isLink)
            }
    }

    private func containsMarkdownLink(text: String) -> Bool {
        let text = try? AttributedString(markdown: text)
        return text?.runs.contains(where: { $0.link != nil }) ?? false
    }
}
