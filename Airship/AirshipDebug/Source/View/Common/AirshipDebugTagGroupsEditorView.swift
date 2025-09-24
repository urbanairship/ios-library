/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import AirshipCore
import Combine

struct AirshipDebugTagGroupsEditorView: View {
    enum TagAction: String, Equatable, CaseIterable {
        case add = "Add"
        case remove = "Remove"
    }

    @State
    private var tag: String = ""

    @State
    private var group: String = ""

    @State
    private var action: TagAction = .add

    private let subject: AirshipDebugAudienceSubject?

    init() {
        self.subject = nil
    }

    init(for subject: AirshipDebugAudienceSubject) {
        self.subject = subject
    }

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
        defer {
            self.tag = ""
            self.group = ""
        }

        guard Airship.isFlying, let subject else { return }

        subject.editTagGroups { editor in
            switch self.action {
            case .add:
                editor.add([tag], group: group)
            case .remove:
                editor.remove([tag], group: group)
            }
        }
    }
}

#Preview {
    AirshipDebugTagGroupsEditorView()
}
