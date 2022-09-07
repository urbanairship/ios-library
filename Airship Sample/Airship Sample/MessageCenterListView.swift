/* Copyright Urban Airship and Contributors */

import Foundation
import AirshipMessageCenter
import AirshipCore
import SwiftUI
import Combine

struct MessageCenterListView: View {

    @State
    private var selection = Set<String>()

    @Environment(\.editMode)
    private var editMode

    @StateObject
    private var viewModel = MessageCenterListViewModel()

    @Binding
    public var messageID: String?

    @State
    private var listOpacity = 0.0

    private func markRead(messages: Set<String>) {
        viewModel.markRead(messages: messages)
        editMode?.animation().wrappedValue = .inactive
    }

    private func delete(messages: Set<String>) {
        viewModel.delete(messages: messages)
        editMode?.animation().wrappedValue = .inactive
    }

    private var messageIDs: [String] {
        var messageIDs = viewModel.messageIDs
        if let deepLink = self.$messageID.wrappedValue,
           !messageIDs.contains(deepLink)
        {
            messageIDs.insert(deepLink, at: 0)
        }

        return messageIDs
    }

    @ViewBuilder
    private func makeList() -> some View {
        let list = List(selection: $selection) {
            ForEach(self.messageIDs, id: \.self) { messageID in
                let item = self.viewModel.messageItem(forID: messageID)
                NavigationLink(
                    destination: MessageView(
                        messageID: messageID,
                        title: item?.title
                    ),
                    tag: messageID,
                    selection: self.$messageID
                ) {
                    if let item = item {
                        MessageCenterListItemView(viewModel: item)
                    } else {
                        EmptyView()
                            .hidden()
                    }
                }
            }
            .onDelete { offsets in
                delete(
                    messages: Set(offsets.map { viewModel.messageIDs[$0] })
                )
            }
        }

        if #available(iOS 15.0, *) {
            list.refreshable {
                await self.viewModel.refreshList()
            }
        } else {
            list
        }
    }


    @ViewBuilder
    private func makeContent() -> some View {
        let deepLinkAvailable =  self.$messageID.wrappedValue == nil ||
        self.viewModel.messageIDs.contains(self.$messageID.wrappedValue ?? "")
        let messagesAvailable = !self.messageIDs.isEmpty

        ZStack {
            makeList()
                .opacity(self.listOpacity)
                .animation(.easeInOut(duration: 0.5), value: self.listOpacity)
                .onReceive(Just(deepLinkAvailable && messagesAvailable)) {
                    if ($0) {
                        self.listOpacity = 1.0
                    } else {
                        self.listOpacity = 0.0
                    }
                }

            if (!deepLinkAvailable) {
                ProgressView()
                    .opacity(1.0 - self.listOpacity)
            } else if (!messagesAvailable) {
                Text("No messages")
                    .opacity(1.0 - self.listOpacity)
            }
        }
    }


    var body: some View {
        makeContent()
            .toolbar {
                EditButton()
            }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    if (self.editMode?.wrappedValue.isEditing == true) {
                        if (self.selection.count == self.viewModel.messageIDs.count) {
                            Button("Select None") {
                                self.selection = Set()
                            }
                        } else {
                            Button("Select All") {
                                self.selection = Set(self.viewModel.messageIDs)
                            }
                        }

                        Spacer()

                        Button(
                            action: {
                                markRead(messages: selection)
                            },
                            label: {
                                if (self.selection.count > 0) {
                                    Text("Mark Read (\(self.selection.count))")
                                } else {
                                    Text("Mark Read")
                                }
                            }
                        )
                        .disabled(self.selection.isEmpty)

                        Spacer()

                        Button(
                            action: {
                                delete(messages: selection)

                            },
                            label: {
                                if (self.selection.count > 0) {
                                    Text("Delete (\(self.selection.count))")
                                } else {
                                    Text("Delete")
                                }
                            }
                        )
                        .disabled(self.selection.isEmpty)
                    }
                }
            }
            .navigationTitle("Message Center")
    }
}


