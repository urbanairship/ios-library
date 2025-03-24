/* Copyright Airship and Contributors */

import SwiftUI
import Foundation

// MARK: - UserDefaults Extension for Recent Layouts
extension UserDefaults {
    var recentLayouts: [String] {
        get { self.array(forKey: "recentLayouts") as? [String] ?? [] }
        set { self.set(newValue, forKey: "recentLayouts") }
    }

    func addRecentLayout(_ layout: String) {
        var current = recentLayouts
        // Remove duplicate if exists
        current.removeAll(where: { $0 == layout })
        // Insert new layout at the beginning
        current.insert(layout, at: 0)
        // Keep only the last 5 items
        if current.count > 5 {
            current = Array(current.prefix(5))
        }
        self.recentLayouts = current
        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: nil)
    }
}

// MARK: - LastLayoutButtonView

struct LastLayoutButtonView: View {
    @State
    private var recentLayouts: [String] = UserDefaults.standard.recentLayouts

    var body: some View {
        Button(action: {
            openLastLayout()
        }, label: {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                Text(recentLayouts.first ?? "No Recent Layout")
                    .foregroundColor(recentLayouts.first == nil ? .gray : .primary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
        })
        .contextMenu {
            if recentLayouts.isEmpty {
                Text("No Recent Layouts")
            } else {
                ForEach(recentLayouts, id: \.self) { layoutName in
                    Button(layoutName) {
                        openLayout(layoutName: layoutName)
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            recentLayouts = UserDefaults.standard.recentLayouts
        }
        .disabled(recentLayouts.first == nil)
    }

    private func openLastLayout() {
        let layouts = Layouts.shared.layouts
        if let lastFileName = recentLayouts.first,
           let layout = layouts.first(where: { $0.fileName == lastFileName }) {
            openLayout(layout: layout)
        }
    }

    private func openLayout(layout: LayoutFile) {
        do {
            try Layouts.shared.openLayout(layout)
            UserDefaults.standard.addRecentLayout(layout.fileName)
        } catch {
            print("Error opening layout: \(error)")
        }
    }

    private func openLayout(layoutName: String) {
        let layouts = Layouts.shared.layouts
        if let layout = layouts.first(where: { $0.fileName == layoutName }) {
            openLayout(layout: layout)
        }
    }
}
