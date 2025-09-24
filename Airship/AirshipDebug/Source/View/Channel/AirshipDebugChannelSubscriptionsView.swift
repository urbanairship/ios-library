/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import AirshipCore

struct AirshipDebugChannelSubscriptionsView: View {
    private enum SubscriptionListAction: String, Equatable, CaseIterable {
        case subscribe = "Subscribe"
        case unsubscribe = "Unsubscribe"
    }

    @State
    private var listID: String = ""

    @State
    private var action: SubscriptionListAction = .subscribe

    @ViewBuilder
    var body: some View {
        Form {
            Section(
                header: Text("Subscription Info".localized())
            ) {
                Picker("Action".localized(), selection: $action) {
                    ForEach(SubscriptionListAction.allCases, id: \.self) {
                        value in
                        Text(value.rawValue.localized())
                    }
                }
                .pickerStyle(.segmented)

                HStack {
                    Text("List ID".localized())
                    Spacer()
                    TextField("", text: self.$listID.preventWhiteSpace())
                        .freeInput()
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    apply()
                } label: {
                    Text("Apply".localized())
                }
                .disabled(listID.isEmpty)
            }
        }
        .navigationTitle("Subscription Lists".localized())
    }

    private func apply() {
        defer {
            self.listID = ""
        }

        guard Airship.isFlying else { return }

        Airship.channel.editSubscriptionLists { editor in
            switch self.action {
            case .subscribe:
                editor.subscribe(self.listID)
            case .unsubscribe:
                editor.unsubscribe(self.listID)
            }
        }
    }
}

#Preview {
    AirshipDebugChannelSubscriptionsView()
}
