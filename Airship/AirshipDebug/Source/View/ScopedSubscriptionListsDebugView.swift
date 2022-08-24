/* Copyright Urban Airship and Contributors */

import Foundation
import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(AirshipKit)
import AirshipKit
#endif

struct ScopedSubscriptionListsDebugView: View {
    private enum SubscriptionListAction: String, Equatable, CaseIterable {
        case subscribe = "Subscribe"
        case unsubscribe = "Unsubscribe"
    }

    private enum Scope: String, Equatable, CaseIterable {
        case app = "App"
        case web = "Web"
        case email = "Email"
        case sms = "SMS"

        var channelScope: ChannelScope {
            switch(self) {
            case .app: return .app
            case .web: return .web
            case .email: return .email
            case .sms: return .sms
            }
        }
    }

    let editorFactory: () -> ScopedSubscriptionListEditor?

    @State
    private var listID: String = ""

    @State
    private var action: SubscriptionListAction = .subscribe

    @State
    private var scope: Scope = .app

    @ViewBuilder
    var body: some View {
        Form {
            Section(header: Text("Subscription Info".localized())) {
                HStack {
                    Text("List ID".localized())
                    Spacer()
                    TextField("", text: self.$listID.preventWhiteSpace())     .freeInput()
                }

                Picker("Scope".localized(), selection: $scope) {
                    ForEach(Scope.allCases, id: \.self) { value in
                        Text(value.rawValue.localized())
                    }
                }
                .pickerStyle(.segmented)

                Picker("Action".localized(), selection: $action) {
                    ForEach(SubscriptionListAction.allCases, id: \.self) { value in
                        Text(value.rawValue.localized())
                    }
                }
                .pickerStyle(.segmented)
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
        let editor = editorFactory()
        switch(self.action) {
        case .subscribe:
            editor?.subscribe(self.listID, scope: self.scope.channelScope)
        case .unsubscribe:
            editor?.unsubscribe(self.listID, scope: self.scope.channelScope)
        }
        editor?.apply()
        self.listID = ""
    }
}




