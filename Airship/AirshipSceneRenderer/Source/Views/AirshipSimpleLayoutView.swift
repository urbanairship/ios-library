/* Copyright Airship and Contributors */

import Foundation
public import SwiftUI

/// Simple layout class that converts airship layout into a swiftui view
/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
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
            // Placement is always 100%x100% here (never configurable, unlike EmbeddedView) --
            // there's no percent/points/auto math to resolve, no embeddedSize, and no placement
            // selectors, so AdoptLayout's machinery (built for that generality) would be pure
            // overhead. Just read the proposed size directly and synchronously.
            GeometryReader { metrics in
                createView(
                    constraints: ViewConstraints(
                        width: metrics.size.width,
                        height: metrics.size.height,
                        isHorizontalAbsoluteSize: false,
                        isVerticalAbsoluteSize: false
                    ),
                    placement: placement
                )
            }
        }
    }
    
    @MainActor
    private func createView(
        constraints: ViewConstraints,
        placement: ThomasPresentationInfo.Embedded.Placement
    ) -> some View {
        return viewModel.environment.viewFactory
            .createView(layout.view, constraints: constraints)
            .thomasBackground(
                color: placement.backgroundColor,
                border: placement.border
            )
            .margin(placement.margin)
            .constraints(constraints)
    }
}
