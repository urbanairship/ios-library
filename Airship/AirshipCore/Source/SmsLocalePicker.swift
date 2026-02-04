/* Copyright Airship and Contributors */

import SwiftUI

#if !os(watchOS)
struct SmsLocalePicker: View {
    
    @Binding private var selectedLocale: ThomasSMSLocale?
    private let availableLocales: [ThomasSMSLocale]
    private let fontSize: Double

    init(
        selectedLocale: Binding<ThomasSMSLocale?>,
        availableLocales: [ThomasSMSLocale],
        fontSize: Double
    ) {
        self._selectedLocale = selectedLocale
        self.availableLocales = availableLocales
        self.fontSize = fontSize
    }

    var body: some View {
        Menu {
            ForEach(availableLocales, id: \.countryCode) { locale in
                Button([
                    locale.countryCode.toFlagEmoji(),
                    locale.countryCode,
                    locale.prefix
                ].joined(separator: " ")) {
                    selectedLocale = locale
                }
            }
        } label: {
            HStack(spacing: 0) {
                if let selectedLocale {
                    Text(selectedLocale.countryCode.toFlagEmoji())
                        .font(.system(size: fontSize))
                        .minimumScaleFactor(0.1)
                        .scaledToFit()
                        .padding(.trailing, 5)
                }
                    
                Image(systemName: "chevron.down")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: fontSize * 0.75, height: fontSize * 0.75)
                    .foregroundStyle(.gray)
            }
        }
    }
}

private extension String {
    private static let base = UnicodeScalar("🇦").value - UnicodeScalar("A").value
    
    func toFlagEmoji() -> String {
        guard self.count == 2 else { return self }
        
        return self
            .uppercased()
            .unicodeScalars
            .compactMap({ UnicodeScalar(Self.base + $0.value)?.description })
            .joined()
    }
}

#Preview {
    let locale: ThomasSMSLocale? = .init(countryCode: "US", prefix: "+1", registration: nil)
    SmsLocalePicker(
        selectedLocale: .constant(locale),
        availableLocales: [
            .init(
                countryCode: "US",
                prefix: "+1",
                registration: nil
            ),
            .init(
                countryCode: "FR",
                prefix: "+33",
                registration: nil
            ),
            .init(
                countryCode: "MO",
                prefix: "+853",
                registration: nil
            ),
        ],
        fontSize: 34
    )
}
#endif
