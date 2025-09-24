/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Combine
import AirshipCore

struct AirshipDebugChannelTagView: View {

    @StateObject
    private var viewModel = ViewModel()

    @State
    private var tag: String = ""

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("New Tag".localized())

                    TextField("", text: self.$tag.preventWhiteSpace()).freeInput()
                        .frame(maxWidth: .infinity)

                    Button {
                        self.viewModel.addTag(self.tag)
                        self.tag = ""
                    } label: {
                        Text("Save".localized())
                    }
                    .disabled(tag.isEmpty)
                }
            }

            Section("Current Tags".localized()) {
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
        .navigationTitle("Tags".localized())
    }

    @MainActor
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

#Preview {
    AirshipDebugChannelTagView()
}
