/* Copyright Airship and Contributors */

import Foundation
public import SwiftUI

/// Simple layout class that converts airship layout into a swiftui view
/// - Note: for internal use only.  :nodoc:
public struct AirshipSimpleLayoutView: View {
    private let placement: ThomasPresentationInfo.Embedded.Placement = .init(
        margin: nil,
        size: .init(width: .percent(100), height: .percent(100)),
        border: nil,
        backgroundColor: nil
    )

    @ObservedObject
    private var viewModel: AirshipSimpleLayoutViewModel
    private let layout: AirshipLayout

    @State
    private var viewConstraints: ViewConstraints?

    /// - Parameter viewModel: Owns the layout environment and state. Create one per layout session and reuse it so state is preserved across view updates.
    public init(layout: AirshipLayout, viewModel: AirshipSimpleLayoutViewModel) {
        self.layout = layout
        self.viewModel = viewModel
    }

    public var body: some View {
        RootView(
            thomasEnvironment: viewModel.environment,
            layout: layout
        ) { orientation, windowSize in
            AdoptLayout(
                placement: placement,
                viewConstraints: $viewConstraints,
                embeddedSize: nil
            ) {
                if let constraints = viewConstraints {
                    createView(
                        constraints: constraints,
                        placement: placement
                    )
                } else {
                    Color.clear
                }
            }
        }
    }
    
    @MainActor
    private func createView(
        constraints: ViewConstraints,
        placement: ThomasPresentationInfo.Embedded.Placement
    ) -> some View {
        return ViewFactory
            .createView(layout.view, constraints: constraints)
            .thomasBackground(
                color: placement.backgroundColor,
                border: placement.border
            )
            .margin(placement.margin)
            .constraints(constraints)
    }
}
