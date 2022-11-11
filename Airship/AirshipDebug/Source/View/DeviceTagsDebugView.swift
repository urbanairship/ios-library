/* Copyright Urban Airship and Contributors */

import Foundation
import SwiftUI

#if canImport(AirshipCore)
    import AirshipCore
#elseif canImport(AirshipKit)
    import AirshipKit
#endif

struct DeviceTagsDebugView: View {

    @StateObject
    private var viewModel = ViewModel()

    var body: some View {
        Form {
            Section(header: Text("Current Tags".localized())) {
                List {
                    ForEach(self.viewModel.tags, id: \.self) { tag in
                        Text(tag)
                    }
                    .onDelete {
                        $0.forEach { index in
                            let tag = self.viewModel.tags[index]
                            self.viewModel.removeTag(tag)
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(
                    "Add",
                    destination: AddTagView {
                        self.viewModel.addTag($0)
                    }
                )
            }
        }
        .navigationTitle("Tags".localized())
    }

    class ViewModel: ObservableObject {

        @Published
        private(set) var tags: [String]

        init() {
            if Airship.isFlying {
                self.tags = Airship.channel.tags
            } else {
                self.tags = []
            }
        }

        func addTag(_ tag: String) {
            if Airship.isFlying {
                Airship.channel.editTags {
                    $0.add(tag)
                }
                self.tags = Airship.channel.tags
            }
        }

        func removeTag(_ tag: String) {
            if Airship.isFlying {
                Airship.channel.editTags {
                    $0.remove(tag)
                }
                self.tags = Airship.channel.tags
            }
        }
    }
}

private struct AddTagView: View {

    @State
    private var tag: String = ""

    let onAdd: (String) -> Void

    @Environment(\.presentationMode)
    private var presentationMode: Binding<PresentationMode>

    var body: some View {
        let title = "Tag".localized()
        Form {
            HStack {
                Text(title)
                Spacer()
                TextField("", text: self.$tag.preventWhiteSpace())
                    .freeInput()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        onAdd(tag)
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Text("Save".localized())
                    }
                    .disabled(tag.isEmpty)
                }
            }
        }
        .navigationTitle("Add Tag".localized())

    }
}
