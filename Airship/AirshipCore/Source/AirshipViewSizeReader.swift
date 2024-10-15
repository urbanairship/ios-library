/* Copyright Airship and Contributors */

public import SwiftUI
import Foundation


/// A view that wraps the view and returns the size without causing the view to expand.
public struct AirshipViewSizeReader<Content> : View where Content : View {
    @State
    private var viewSize: CGSize?
    private let contentBlock: (CGSize?) -> Content

    /// Default constructor
    /// - Parameters:
    ///     - contentBlock: The content block that will have the view size if available and returns the actual content.
    public init(@ViewBuilder contentBlock: @escaping  (CGSize?) -> Content) {
        self.contentBlock = contentBlock
    }

    public var body: some View {
        return contentBlock(viewSize).airshipMeasureView($viewSize)
    }
}


public extension View {

    /// Adds a geometry reader to the background to fetch the size without causing the view to grow.
    /// -  Parameter binding: The  binding to store the size.
    @ViewBuilder
    func airshipMeasureView(_ binding: Binding<CGSize?>) -> some View  {
        self.background(
            GeometryReader { geo -> Color in
                DispatchQueue.main.async {
                    binding.wrappedValue = geo.size
                }
                return Color.clear
            }
        )
    }
}
