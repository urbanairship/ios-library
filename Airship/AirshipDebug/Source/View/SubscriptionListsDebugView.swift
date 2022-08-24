/* Copyright Urban Airship and Contributors */

import Foundation
import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(AirshipKit)
import AirshipKit
#endif

struct SubscriptionListsDebugView: View {
    private enum SubscriptionListAction: String, Equatable, CaseIterable {
        case subscribe = "Subscribe"
        case unsubscribe = "Unsubscribe"
    }

    let editorFactory: () -> SubscriptionListEditor?

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
                    ForEach(SubscriptionListAction.allCases, id: \.self) { value in
                        Text(value.rawValue.localized())
                    }
                }
                .pickerStyle(.segmented)

                HStack {
                    Text("List ID".localized())
                    Spacer()
                    TextField("", text: self.$listID.preventWhiteSpace())     .freeInput()
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
        let editor = editorFactory()
        switch(self.action) {
        case .subscribe:
            editor?.subscribe(self.listID)
        case .unsubscribe:
            editor?.unsubscribe(self.listID)
        }
        editor?.apply()
        self.listID = ""
    }
}
