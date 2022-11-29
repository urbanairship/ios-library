/* Copyright Airship and Contributors */

#if canImport(ActivityKit)

import Foundation
import ActivityKit
import SwiftUI
import WidgetKit

struct DeliveryActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DeliveryAttributes.self) { context in
            LockScreenLiveActivityView(context: context)
                .widgetURL(URL(string: "cool"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image("23Grande")
                        .resizable()
                        .scaledToFill()
                        .clipShape(Circle())
                        .frame(width: 30, height: 30)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Label {
                        Text("\(context.attributes.orderNumber)")
                    } icon: {
                        Image(systemName: "shippingbox.fill")
                            .foregroundColor(.primary)
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    if context.state.stopsAway > 0 {
                        Text("\(context.state.stopsAway) stops away")
                    } else {
                        Text("Delivered")
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    DeliveryStatusView(stopsAway: context.state.stopsAway)
                }
            } compactLeading: {
                Image("23Grande")
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
                    .padding(2)
            } compactTrailing: {
                if context.state.stopsAway > 0 {
                    Text("En Route")
                } else {
                    Text("Delivered")
                }
            } minimal: {
                Image("23Grande")
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
                    .padding(2)
            }
            .keylineTint(.red)
        }
    }
}

struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<DeliveryAttributes>

    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .top) {
                VStack(alignment: .leading) {
                    Image("23Grande")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .cornerRadius(8)

                    Text("Shipping Status")

                    if context.state.stopsAway <= 0 {
                        Text("Delivered!")
                            .font(.footnote)
                    } else if context.state.stopsAway <= 10 {
                        Text("\(context.state.stopsAway) stops away")
                            .font(.footnote)
                    } else {
                        Text("En Route...")
                            .font(.footnote)
                    }
                }

                Spacer()

                VStack {
                    Image(systemName: "shippingbox.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.primary)
                        .frame(width: 48, height: 48)
                    Text("Order: \(context.attributes.orderNumber)")
                }
            }

            DeliveryStatusView(stopsAway: self.context.state.stopsAway)

        }
        .padding(16)

    }
}

struct DeliveryStatusView: View {
    let stopsAway: Int

    @ViewBuilder
    var body: some View {
        VStack {
            HStack(spacing: 0) {
                Circle()
                    .foregroundColor(.red)
                    .frame(width: 16, height: 16)
                    .offset(x: 1)

                Rectangle()
                    .foregroundColor(.red)
                    .frame(height: 6)

                Circle()
                    .foregroundColor(.red)
                    .frame(width: 16, height: 16)
                    .offset(x: -1)

                if self.stopsAway > 0 {
                    ForEach(1..<10, id: \.self) { index in
                        Rectangle()
                            .foregroundColor(.primary)
                            .frame(height: 6)
                            .padding(.horizontal, 2)
                    }

                    Circle()
                        .strokeBorder(.primary, lineWidth: 2)
                        .frame(width: 16, height: 16)
                }
            }
        }

    }
}

struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        return path
    }
}

#endif
