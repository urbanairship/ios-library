/* Copyright Airship and Contributors */

import SwiftUI

#if !os(watchOS)
struct SmsLocalePicker: View {
    
    @Binding var selectedLocale: ThomasSMSLocale?
    let availableLocales: [ThomasSMSLocale]

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
                        .font(.system(size: 34))
                        .minimumScaleFactor(0.1)
                        .scaledToFit()
                }
                    
                Image(systemName: "chevron.down")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 8)
                    .foregroundStyle(.gray)
                    .padding(.vertical, 3)
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
    var locale: ThomasSMSLocale? = .init(countryCode: "US", prefix: "+1", registration: nil)
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
        ]
    )
}
#endif
