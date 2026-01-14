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
        backgroundColor: nil)
    
    private let environment: ThomasEnvironment
    
    let layout: AirshipLayout
    
    @State
    private var viewConstraints: ViewConstraints?
    
    public init(
        layout: AirshipLayout,
        delegate: any ThomasDelegate,
        timer: (any AirshipTimerProtocol)? = nil,
        extensions: ThomasExtensions? = nil
    ) {
        self.environment = ThomasEnvironment(delegate: delegate, extensions: extensions, timer: timer)
        self.layout = layout
        self.viewConstraints = viewConstraints
    }
    
    public var body: some View {
        RootView(
            thomasEnvironment: environment,
            layout: layout
        ) { orientation, windowSize in
            if #available(iOS 16, tvOS 16, watchOS 9.0, *) {
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
            } else {
                let constraints = ViewConstraints(
                    width: placement.size.width.calculateSize(nil),
                    height: placement.size.height.calculateSize(nil)
                )

                let contentConstraints = constraints.contentConstraints(
                    placement.size,
                    contentSize: nil,
                    margin: placement.margin
                )

                createView(
                    constraints: contentConstraints,
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
