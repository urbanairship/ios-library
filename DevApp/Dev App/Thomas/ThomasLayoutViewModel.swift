/* Copyright Airship and Contributors */

import Combine
import Foundation
internal import Yams

@MainActor
final class ThomasLayoutViewModel: ObservableObject {

    private let layoutLoader: LayoutLoader = .init()

    @Published
    public private(set) var recentLayouts: [LayoutFile] = []

    init() {
        self.recentLayouts = ThomasUserDefaults.shared.recentLayouts
    }

    func openLayout(_ layout: LayoutFile, addToRecents: Bool = true) throws {
        try layout.open()
        if addToRecents {
            Self.saveToRecent(layout)
            self.recentLayouts = ThomasUserDefaults.shared.recentLayouts
        }
    }

    func layouts(type: LayoutType) -> [LayoutFile] {
        return layoutLoader.load(type: type)
    }
    
    func refreshRecent() {
        self.recentLayouts = ThomasUserDefaults.shared.recentLayouts
    }
    
    static func saveToRecent(_ layout: LayoutFile) {
        ThomasUserDefaults.shared.addRecentLayout(layout)
    }
}

@MainActor
fileprivate final class ThomasUserDefaults {
    static let shared: ThomasUserDefaults = ThomasUserDefaults()

    var recentLayouts: [LayoutFile] {
        get { readCodable("recentLayouts") ?? [] }
        set { write("recentLayouts", codable: newValue) }
    }

    let defaults: UserDefaults

    private init() {
        self.defaults = UserDefaults(suiteName: "airship.layout")!
    }

    private func write<T>(_ key: String, codable: T) where T: Codable {
        let data = try? JSONEncoder().encode(codable)
        write(key, value: data)
    }

    private func readCodable<T>(_ key: String) -> T? where T: Codable {
        guard let value: Data = read(key) else {
            return nil
        }
        return try? JSONDecoder().decode(T.self, from: value)
    }


    private func write(_ key: String, value: Any?) {
        if let value = value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    private func read<T>(_ key: String) -> T? {
        return defaults.value(forKey: key) as? T
    }

    private func readString(_ key: String, trimmingCharacters: CharacterSet? = nil) -> String? {
        guard let value: String = read(key) else {
            return nil
        }

        return if let trimmingCharacters {
            value.trimmingCharacters(in: trimmingCharacters)
        } else {
            value
        }
    }

}

extension ThomasUserDefaults {
    func addRecentLayout(_ layout: LayoutFile) {
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
    }
}
