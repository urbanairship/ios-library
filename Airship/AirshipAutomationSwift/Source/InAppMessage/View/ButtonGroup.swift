/* Copyright Airship and Contributors */

import SwiftUI

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
    @EnvironmentObject var environment: InAppMessageEnvironment
    let layout:InAppMessageButtonLayoutType
    let buttons:[InAppMessageButtonInfo]

    /// Prevent cycling onPreferenceChange to set rest of the buttons' minHeight to the largest button's height
    @State private var buttonMinHeight: CGFloat = 33
    @State private var lastButtonHeight: CGFloat?

    var stackedButtonSpacing: CGFloat {
        switch environment.theme {
        case .banner(let theme):
            return theme.buttonTheme.stackedButtonSpacing
        case .modal(let theme):
            return theme.buttonTheme.stackedButtonSpacing
        case .fullScreen(let theme):
            return theme.buttonTheme.stackedButtonSpacing
        case .html(_):
            return 0 /// HTML views do not currently support stacked buttons
        }
    }

    var separateButtonSpacing: CGFloat {
        switch environment.theme {
        case .banner(let theme):
            return theme.buttonTheme.separatedButtonSpacing
        case .modal(let theme):
            return theme.buttonTheme.separatedButtonSpacing
        case .fullScreen(let theme):
            return theme.buttonTheme.separatedButtonSpacing
        case .html(_):
            return 0 /// HTML views do not currently support separate buttons
        }
    }

    private func makeButtonView(buttonInfo: InAppMessageButtonInfo, roundedEdge: RoundedEdge = .all) -> some View {
        return ButtonView(buttonInfo: buttonInfo, roundedEdge: roundedEdge, relativeMinHeight: $buttonMinHeight)
            .frame(minHeight:buttonMinHeight)
            .environmentObject(environment)
            .background(
                GeometryReader {
                    Color.tappableClear.preference(key: ViewHeightKey.self,
                                                   value: $0.frame(in: .global).size.height) }
                    .onPreferenceChange(ViewHeightKey.self) { value in
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
            VStack(spacing: stackedButtonSpacing) {
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
            HStack(spacing: separateButtonSpacing) {
                ForEach(buttons, id: \.identifier)  { button in
                    makeButtonView(buttonInfo: button)
                }
            }.fixedSize(horizontal: false, vertical: true) /// Hug children in horizontal axis and veritcal axis
        }
    }
}

struct ButtonView: View {
    @EnvironmentObject var environment: InAppMessageEnvironment

    let buttonInfo: InAppMessageButtonInfo
    let roundedEdge: RoundedEdge

    @ScaledMetric var scaledPadding: CGFloat = 12

    @State private var isPressed = false
    private let pressedOpacity: Double = 0.7

    /// Min height of the button that can be dynamically set to size to the largest button in the group
    /// This is so buttons normalize in height to match the button with the largest font size
    @Binding private var relativeMinHeight:CGFloat

    internal init(buttonInfo: InAppMessageButtonInfo,
                  roundedEdge:RoundedEdge = .all,
                  relativeMinHeight: Binding<CGFloat>? = nil) {
        self.buttonInfo = buttonInfo
        self.roundedEdge = roundedEdge

        _relativeMinHeight = relativeMinHeight ?? Binding.constant(CGFloat(0))
    }

    private var buttonHeight: CGFloat {
        switch environment.theme {
        case .banner(let theme):
            return theme.buttonTheme.buttonHeight
        case .fullScreen(let theme):
            return theme.buttonTheme.buttonHeight
        case .html(_):
            return 0 /// HTML views do not currently support button views
        case .modal(let theme):
            return theme.buttonTheme.buttonHeight
        }
    }

    @ViewBuilder
    var buttonLabel: some View {
        TextView(textInfo: buttonInfo.label,
                 textTheme: TextTheme(letterSpacing: 0,
                                      lineSpacing: 0,
                                      additionalPadding: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)))
        .opacity(isPressed ? pressedOpacity : 1.0)

    }

    var body: some View {
        Button(action:onTap) {
            buttonLabel
                .padding(scaledPadding)
                .frame(maxWidth: .infinity, minHeight: max(relativeMinHeight, buttonHeight))
                .background(buttonInfo.backgroundColor?.color)
                .roundEdge(radius: buttonInfo.borderRadius ?? 0,
                           edge: roundedEdge,
                           borderColor: buttonInfo.borderColor?.color ?? .clear,
                           borderWidth: 2)
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .pressable(isPressed: $isPressed)
    }

    private func onTap() {
        if buttonInfo.behavior == .cancel {
            environment.onUserDismissed()
        } else {
            environment.onButtonDismissed(buttonInfo: self.buttonInfo)
        }
    }
}

extension View {
    func pressable(isPressed: Binding<Bool>) -> some View {
        self.simultaneousGesture(DragGesture(minimumDistance: 0)
            .onChanged({ _ in isPressed.wrappedValue = true })
            .onEnded({ _ in isPressed.wrappedValue = false })
        )
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
