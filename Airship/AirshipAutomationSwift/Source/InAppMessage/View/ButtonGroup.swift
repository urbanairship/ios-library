/* Copyright Airship and Contributors */

import SwiftUI

private let defaultButtonMargin: CGFloat = 15
private let defaultFooterMargin: CGFloat = 0
private let buttonDefaultBorderWidth: CGFloat = 2

struct ButtonGroup: View {
    @EnvironmentObject var environment: InAppMessageEnvironment
    let layout:InAppMessageButtonLayoutType
    let buttons:[InAppMessageButtonInfo]

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
        return ButtonView(buttonInfo: buttonInfo, roundedEdge: roundedEdge).environmentObject(environment)
    }

    var body: some View {
        switch layout {
        case .stacked:
            VStack(spacing: stackedButtonSpacing) {
                ForEach(buttons, id: \.identifier)  { button in
                    makeButtonView(buttonInfo: button)
                }
            }
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
            }
        case .separate:
            HStack(spacing: separateButtonSpacing) {
                ForEach(buttons, id: \.identifier)  { button in
                    makeButtonView(buttonInfo: button)
                }
            }
        }
    }
}

struct ButtonView: View {
    @EnvironmentObject var environment: InAppMessageEnvironment
    
    let buttonInfo: InAppMessageButtonInfo
    let roundedEdge: RoundedEdge

    @ScaledMetric var scaledPadding: CGFloat = 8

    @State private var isPressed = false
    private let pressedOpacity: Double = 0.7

    internal init(buttonInfo: InAppMessageButtonInfo, roundedEdge:RoundedEdge = .all) {
        self.buttonInfo = buttonInfo
        self.roundedEdge = roundedEdge
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
            ZStack {
                Rectangle()
                    .foregroundColor(buttonInfo.backgroundColor?.color)
                    .roundEdge(radius: buttonInfo.borderRadius ?? 0,
                               edge: roundedEdge,
                               borderColor: buttonInfo.borderColor?.color ?? .clear,
                               borderWidth: 2)
                buttonLabel
                    .frame(minHeight:buttonHeight)
                    .padding(scaledPadding)
            }
            .roundEdge(radius: buttonInfo.borderRadius ?? 0,
                       edge: roundedEdge,
                       borderColor: buttonInfo.borderColor?.color ?? .clear,
                       borderWidth: 2)
        }.frame(minHeight: buttonHeight)
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
