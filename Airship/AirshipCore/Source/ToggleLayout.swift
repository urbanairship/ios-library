

import SwiftUI

@MainActor
struct ToggleLayout<Content> : View  where Content : View {
    @EnvironmentObject var thomasState: ThomasState

    @Binding var isOn: Bool
    let onToggleOn: ThomasViewInfo.ToggleActions
    let onToggleOff: ThomasViewInfo.ToggleActions
    let content: () -> Content

    var body: some View {
        Toggle(isOn: $isOn.animation()) {
            content().background(Color.airshipTappableClear)
        }
        .airshipOnChangeOf(self.isOn) { isOn in
            self.handleStateActions(isOn)

        }
        .toggleStyle(PlainButtonToggleStyle())
    }

    private func handleStateActions(_ isOn: Bool) {
        let actions = isOn ? onToggleOn : onToggleOff
        guard let stateActions = actions.stateActions else { return }
        thomasState.processStateActions(stateActions)
    }
}

fileprivate struct PlainButtonToggleStyle: ToggleStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        }
        label: {
            configuration.label
        }
#if os(tvOS)
        .buttonStyle(TVButtonStyle())
#else
        .buttonStyle(.plain)
#endif
    }
}

