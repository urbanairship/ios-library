/* Copyright Urban Airship and Contributors */

#if canImport(ActivityKit)

import Foundation
import SwiftUI
import Combine
import AirshipCore

import ActivityKit

@available(iOS 16.1, *)
struct LiveActivityManagementView: View {

    @StateObject
    var viewModel = ViewModel()

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Activities")) {
                    List {
                        ForEach(
                            0..<self.$viewModel.activities.count,
                            id: \.self
                        ) {
                            index in
                            DeliveryActivityView(
                                activity: self.viewModel.activities[index]
                            )
                        }
                        .onDelete { (indexSet) in
                            self.viewModel.remove(atOffsets: indexSet)
                        }
                    }
                    .refreshable {
                        self.viewModel.refresh()
                    }
                }
            }
            .navigationTitle("Live Activities!")
            .toolbar {
                ToolbarItem(
                    placement: .navigationBarTrailing
                ) {
                    Button("Add new") {
                        self.viewModel.add()
                    }
                }
            }
        }
    }

    @available(iOS 16.1, *)
    class ViewModel: ObservableObject {

        @Published
        var activities: [Activity<DeliveryAttributes>] = []

        init() {
            refresh()
        }

        func remove(atOffsets: IndexSet) {
            atOffsets.forEach { index in
                let activity = self.activities[index]
                Task {
                    await activity.end(dismissalPolicy: .immediate)
                }
            }
            self.activities.remove(atOffsets: atOffsets)
        }

        func refresh() {
            self.activities =
                Activity<DeliveryAttributes>
                .activities
        }
        func add() {
            let state = DeliveryAttributes.ContentState(
                stopsAway: 10
            )

            let attributes = DeliveryAttributes(
                orderNumber: generateOrderNumber()
            )

            do {
                let activity = try Activity.request(
                    attributes: attributes,
                    contentState: state,
                    pushType: .token
                )

                self.activities.append(activity)

                Task {
                    await Airship.channel.trackLiveActivity(
                        activity,
                        name: attributes.orderNumber
                    )
                }
            } catch (let error) {
                print("Error requesting LiveActivity \(error).")
            }

        }

        private func generateOrderNumber() -> String {
            var number = "#"
            for _ in 1...6 {
                number += "\(Int.random(in: 1...9))"
            }
            return number
        }
    }

    struct Order {
        var orderNumber: String {
            return activity.attributes.orderNumber
        }

        var activity: Activity<DeliveryAttributes>
    }

}

@available(iOS 16.1, *)
struct DeliveryActivityView: View {
    let activity: Activity<DeliveryAttributes>

    @State
    var status: String

    @State
    var pushToken: String?

    init(activity: Activity<DeliveryAttributes>) {
        self.activity = activity
        self.pushToken = activity.pushToken?.deviceToken
        self.status = activity.activityState.stringValue
    }

    @ViewBuilder
    var body: some View {
        VStack(alignment: .leading) {
            Text(activity.attributes.orderNumber)
                .font(.headline)

            Text("State: \(status)")
                .font(.subheadline)

            Text("Token: \(pushToken ?? "")")
                .font(.subheadline)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard let token = self.pushToken else { return }
            copyToClipboard(token)
            print("Token: \(token)")
        }
        .task {
            for await update in activity.activityStateUpdates {
                await MainActor.run {
                    self.status = update.stringValue
                }
            }
        }
        .task {
            for await update in activity.pushTokenUpdates {
                await MainActor.run {
                    self.pushToken = update.deviceToken
                }
            }
        }
    }

    func copyToClipboard(_ value: String) {
        UIPasteboard.general.string = value
    }
}

extension Data {
    var deviceToken: String {
        Utils.deviceTokenStringFromDeviceToken(self)
    }
}

@available(iOS 16.1, *)

extension ActivityState {
    var stringValue: String {
        switch self {
        case .active:
            return "Active"
        case .dismissed:
            return "Dismissed"
        case .ended:
            return "Ended"
        @unknown default:
            fatalError()
        }
    }
}

#endif
