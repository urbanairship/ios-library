/* Copyright Airship and Contributors */


import Foundation
import SwiftUI

protocol ThemeDefaultable {
    static var defaultPlistName: String { get }
    static var defaultValues: Self { get }
}

protocol PlistLoadable {
    init?(plistName: String, bundle: Bundle?)
}

extension PlistLoadable where Self: Decodable {
    init?(plistName: String, bundle: Bundle? = Bundle.main) {
        guard let url = bundle?.url(forResource: plistName, withExtension: "plist"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }

        let decoder = PropertyListDecoder()
        guard let decoded = try? decoder.decode(Self.self, from: data) else {
            return nil
        }

        self = decoded
    }
}

extension ButtonView {
    @ViewBuilder
    func applyButtonTheme(_ buttonTheme: ButtonTheme) -> some View {
        self.padding(buttonTheme.additionalPadding)
    }
}

extension MediaView {
    @ViewBuilder
    func applyMediaTheme(_ textTheme: MediaTheme) -> some View {
        self.padding(textTheme.additionalPadding)
    }
}

extension View {
    @ViewBuilder
    func applyTextTheme(_ textTheme: TextTheme) -> some View {
        if #available(iOS 16.0, *) {
            self
                .padding(textTheme.additionalPadding)
                .lineSpacing(textTheme.lineSpacing)
                .kerning(textTheme.letterSpacing)
        } else {
            self
                .padding(textTheme.additionalPadding)
                .lineSpacing(textTheme.lineSpacing)
            /// TODO add a pre-16.0 version of kerning/letter spacing and manually test
        }
    }
}
