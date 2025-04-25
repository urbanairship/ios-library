// Copyright Urban Airship and Contributors


import SwiftUI

private struct ToastModifier: ViewModifier {
    @Binding
    var message: AirshipToast.Message?
    
    func body(content: Content) -> some View {
        content.overlay(AirshipToast(message: $message), alignment: .bottom)
    }
}

extension View {
    func toastable(_ message: Binding<AirshipToast.Message?>) -> some View {
        modifier(ToastModifier(message: message))
    }
}

extension String {
    func pastleboard() {
#if !os(tvOS)
        UIPasteboard.general.string = self
#endif
    }
}

struct CommonItems {
    
    static let rowHeight = 34.0
    
    @ViewBuilder
    @MainActor
    static func navigationRow(
        title: String,
        trailingView: (() -> some View) = { EmptyView() },
        showDivider: Bool = false,
        destination: @autoclosure () -> some View
    ) -> some View {
        NavigationLink(destination: destination) {
            VStack {
                HStack {
                    Text(title)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    trailingView()
                }
                .frame(height: Self.rowHeight)
                
                if showDivider {
                    Divider()
                }
            }
        }
    }
    
    @ViewBuilder
    @MainActor
    static func infoRow(
        title: String,
        value: String?,
        onTap: (() -> Void)? = nil,
        showDivider: Bool = false
    ) -> some View {
        
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if let value {
                    Text(value)
                        .foregroundColor(.secondary)
                }
            }
            
            if showDivider {
                Divider()
            }
        }
        .frame(height: Self.rowHeight)
        .onTapGesture { onTap?() }
    }
}
