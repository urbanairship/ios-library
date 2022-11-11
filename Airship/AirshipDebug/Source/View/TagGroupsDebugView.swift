/* Copyright Urban Airship and Contributors */

import Foundation
import SwiftUI

#if canImport(AirshipCore)
    import AirshipCore
#elseif canImport(AirshipKit)
    import AirshipKit
#endif

struct TagGroupsDebugView: View {
    enum TagAction: String, Equatable, CaseIterable {
        case add = "Add"
        case remove = "Remove"
    }

    let editorFactory: () -> TagGroupsEditor?

    @State
    private var tag: String = ""

    @State
    private var group: String = ""

    @State
    private var action: TagAction = .add

    @ViewBuilder
    var body: some View {
        Form {
            Section(header: Text("Tag Info".localized())) {
                Picker("Action".localized(), selection: $action) {
                    ForEach(TagAction.allCases, id: \.self) { value in
                        Text(value.rawValue.localized())
                    }
                }
                .pickerStyle(.segmented)

                HStack {
                    Text("Tag")
                    Spacer()
                    TextField("", text: self.$tag.preventWhiteSpace())
                        .freeInput()
                }

                HStack {
                    Text("Group")
                    Spacer()
                    TextField("", text: self.$group.preventWhiteSpace())
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
                .disabled(tag.isEmpty || group.isEmpty)
            }
        }
        .navigationTitle("Tag Groups".localized())
    }

    private func apply() {
        let editor = editorFactory()
        switch self.action {
        case .add:
            editor?.add([tag], group: group)
        case .remove:
            editor?.remove([tag], group: group)
        }
        editor?.apply()
        self.tag = ""
        self.group = ""
    }
}
