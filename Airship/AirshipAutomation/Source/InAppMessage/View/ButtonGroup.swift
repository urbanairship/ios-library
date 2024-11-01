/* Copyright Airship and Contributors */

import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

private let defaultButtonMargin: CGFloat = 15
private let defaultFooterMargin: CGFloat = 0
private let buttonDefaultBorderWidth: CGFloat = 2

struct ViewHeightKey: PreferenceKey {
    typealias Value = CGFloat
    static var defaultValue = CGFloat.zero
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value += nextValue()
    }
}

struct ButtonGroup: View {
    /// Prevent cycling onPreferenceChange to set rest of the buttons' minHeight to the largest button's height
    @State private var buttonMinHeight: CGFloat = 33
    @State private var lastButtonHeight: CGFloat?
    @EnvironmentObject var environment: InAppMessageEnvironment
    @Binding private var isDisabled: Bool

    let layout: InAppMessageButtonLayoutType
    let buttons: [InAppMessageButtonInfo]
    let theme: InAppMessageTheme.Button

    init(
        isDisabled: Binding<Bool>? = nil,
        layout: InAppMessageButtonLayoutType,
        buttons: [InAppMessageButtonInfo],
        theme: InAppMessageTheme.Button
    ) {
        self._isDisabled = isDisabled ?? Binding.constant(false)
        self.layout = layout
        self.buttons = buttons
        self.theme = theme
    }

    private func makeButtonView(buttonInfo: InAppMessageButtonInfo, roundedEdge: RoundedEdge = .all) -> some View {
        return ButtonView(
            buttonInfo: buttonInfo,
            roundedEdge: roundedEdge,
            relativeMinHeight: $buttonMinHeight,
            minHeight: theme.height,
            isDisabled: $isDisabled
        )
        .frame(minHeight:buttonMinHeight)
        .environmentObject(environment)
        .background(
            GeometryReader {
                Color.airshipTappableClear.preference(
                    key: ViewHeightKey.self,
                    value: $0.frame(in: .global).size.height
                )
            }.onPreferenceChange(ViewHeightKey.self) { value in
                DispatchQueue.main.async {
                    let buttonHeight = round(value)
                    /// Prevent cycling by storing the last button height
                    if self.lastButtonHeight ?? 0 != buttonHeight {
                        /// Minium button height is the height of the largest button in the group
                        self.buttonMinHeight = max(buttonMinHeight, buttonHeight)
                        self.lastButtonHeight = buttonHeight
                    }
                }
            }
        )
    }

    var body: some View {
        switch layout {
        case .stacked:
            VStack(spacing: theme.stackedSpacing) {
                ForEach(buttons, id: \.identifier)  { button in
                    makeButtonView(buttonInfo: button)
                }
            }

            .fixedSize(horizontal: false, vertical: true) /// Hug children in vertical axis
        case .joined:
            HStack(spacing: 0) {
                ForEach(Array(buttons.enumerated()), id: \.element.identifier) { index, button in
                    if buttons.count > 1 {
                        if index == 0 {
                            // If first button of n buttons: only round leading edge
                            makeButtonView(buttonInfo: button, roundedEdge: .leading)
                        } else if index == buttons.count - 1 {
                            // If last button of n buttons: only round trailing edge
                            makeButtonView(buttonInfo: button, roundedEdge: .trailing)
                        } else {
                            // If middle button of n buttons: round trailing and leading edges
                            makeButtonView(buttonInfo: button, roundedEdge: .none)
                        }
                    } else {
                        // Round all button edges by default
                        makeButtonView(buttonInfo: button)
                    }
                }
            }.fixedSize(horizontal: false, vertical: true) /// Hug children in horizontal axis and veritcal axis
        case .separate:
            HStack(spacing: theme.separatedSpacing) {
                ForEach(buttons, id: \.identifier)  { button in
                    makeButtonView(buttonInfo: button)
                }
            }.fixedSize(horizontal: false, vertical: true) /// Hug children in horizontal axis and veritcal axis
        }
    }
}

struct ButtonView: View {
    @EnvironmentObject var environment: InAppMessageEnvironment
    @ScaledMetric var scaledPadding: CGFloat = 12

    @Binding var isDisabled: Bool
    let buttonInfo: InAppMessageButtonInfo
    let roundedEdge: RoundedEdge
    let minHeight: CGFloat

    /// Min height of the button that can be dynamically set to size to the largest button in the group
    /// This is so buttons normalize in height to match the button with the largest font size
    @Binding private var relativeMinHeight:CGFloat

    internal init(
        buttonInfo: InAppMessageButtonInfo,
        roundedEdge:RoundedEdge = .all,
        relativeMinHeight: Binding<CGFloat>? = nil,
        minHeight: CGFloat = 33,
        isDisabled: Binding<Bool>? = nil
    ) {
        self.buttonInfo = buttonInfo
        self.roundedEdge = roundedEdge
        _relativeMinHeight = relativeMinHeight ?? Binding.constant(CGFloat(0))
        self.minHeight = minHeight
        _isDisabled = isDisabled ?? Binding.constant(false)
    }


    @ViewBuilder
    var buttonLabel: some View {
        TextView(
            textInfo: buttonInfo.label,
            textTheme: InAppMessageTheme.Text(
                letterSpacing: 0,
                lineSpacing: 0,
                padding: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
            )
        )
    }

    var body: some View {
        Button(action: onTap) {
            buttonLabel
                .padding(scaledPadding)
                .frame(maxWidth: .infinity, minHeight: max(relativeMinHeight, minHeight))
                .background(buttonInfo.backgroundColor?.color)
                .roundEdge(radius: buttonInfo.borderRadius ?? 0,
                           edge: roundedEdge,
                           borderColor: buttonInfo.borderColor?.color ?? .clear,
                           borderWidth: 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func onTap() {
        if (!isDisabled) {
            environment.onButtonDismissed(buttonInfo: self.buttonInfo)
            environment.runActions(actions: self.buttonInfo.actions)
        }
    }
}

enum RoundedEdge {
    case none
    case leading
    case trailing
    case all
}

struct RoundEdgeModifier: ViewModifier {
    var radius: CGFloat
    var edge: RoundedEdge
    var borderColor: Color
    var borderWidth: CGFloat

    func body(content: Content) -> some View {
        content
            .clipShape(RoundedEdgeShape(radius: radius, edge: edge))
            .overlay(RoundedEdgeShape(radius: radius, edge: edge)
                .stroke(borderColor, lineWidth: borderWidth))
    }
}

struct RoundedEdgeShape: Shape {
    var radius: CGFloat
    var edge: RoundedEdge

    func path(in rect: CGRect) -> Path {
        var corners: UIRectCorner = []

        switch edge {
        case .none:
            corners = []
        case .leading:
            corners = [.topLeft, .bottomLeft]
        case .trailing:
            corners = [.topRight, .bottomRight]
        case .all:
            corners = [.topLeft, .bottomLeft, .topRight, .bottomRight]
        }

        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

extension View {
    func roundEdge(radius: CGFloat, edge: RoundedEdge, borderColor: Color = .clear, borderWidth: CGFloat = 0) -> some View {
        self.modifier(RoundEdgeModifier(radius: radius, edge: edge, borderColor: borderColor, borderWidth: borderWidth))
    }
}
