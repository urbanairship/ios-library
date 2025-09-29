/* Copyright Airship and Contributors */

import Foundation
import Combine
import SwiftUI

@MainActor
class WeatherViewModel: ObservableObject {
    @Published var time: String = "Loading..."
    let summary: String
    let icon: String
    let precipProbability: String
    let temperature: String
    let apparentTemperature: String
    let humidity: String
    let windSpeed: String

    private var timer: AnyCancellable?

    private func updateTime() {
        withAnimation {
            self.time = getCurrentDateTimeString()
        }
    }

    private func getCurrentDateTimeString() -> String {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a MMMM dd, yyyy"
        return formatter.string(from: now)
    }

    init() {
        self.summary = "Storm Advisory"

        self.icon = "rain"

        self.precipProbability = "100%"

        self.temperature = "53º"

        self.apparentTemperature = "52º"

        self.humidity = "100%"

        self.windSpeed = "22 mph"

        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateTime()
            }
    }
}
