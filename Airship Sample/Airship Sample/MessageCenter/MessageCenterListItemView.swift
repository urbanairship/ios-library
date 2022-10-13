/* Copyright Urban Airship and Contributors */

import Foundation
import SwiftUI
import AirshipCore
import AirshipMessageCenter

struct MessageCenterListItemView: View {

    @ObservedObject
    var viewModel: MessageCenterListItemViewModel

    private var placeHolder: some View {
        Image(systemName: "photo")
            .resizable()
            .scaledToFit()
            .foregroundColor(.primary)
            .frame(width: 60)
    }

    @ViewBuilder
    func makeIcon() -> some View {
        if let listIcon = self.viewModel.listIcon {
            AirshipAsyncImage(url: listIcon) { image, _ in
                image.resizable()
                    .scaledToFit()
                    .frame(width: 60)
            } placeholder: {
                self.placeHolder
            }
        } else {
            self.placeHolder
        }
    }

    @ViewBuilder
    func makeUnreadIndicator() -> some View {
        if (self.viewModel.unread) {
            Image(systemName: "circle.fill")
                .foregroundColor(.blue)
                .frame(width: 8, height: 8)
        }
    }

    @ViewBuilder
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            makeIcon()
            VStack(alignment: .leading, spacing: 4) {
                Text(self.viewModel.title)
                    .font(.headline)

                if let subtitle = self.viewModel.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                }

                if let messageSent = self.viewModel.messageSent {
                    Text(messageSent, style: .date)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }.padding(.leading, 10)

            Spacer()
        }
        .padding(4)
        .overlay(makeUnreadIndicator(), alignment: .topLeading)
    }
}

