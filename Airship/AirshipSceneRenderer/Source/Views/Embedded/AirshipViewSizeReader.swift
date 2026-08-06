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
    /// The binding is written only when the size changes.
    /// -  Parameter binding: The  binding to store the size.
    @ViewBuilder
    func airshipMeasureView(_ binding: Binding<CGSize?>) -> some View  {
        self.background(
            GeometryReader { geo -> Color in
                let size = geo.size
                DispatchQueue.main.async {
                    // Only write on an actual change — an unconditional write invalidates
                    // layout, which schedules another pass, which writes again.
                    guard binding.wrappedValue != size else { return }
                    binding.wrappedValue = size
                }
                return Color.clear
            }
        )
    }

    /// Adds a geometry reader to the background to fetch the size without causing the view to grow.
    /// Use when you want the size without storing it in `@State`.
    ///
    /// Despite the parameter name this does not dedupe: the closure fires on every layout
    /// pass, whether or not the size changed. Compare against your own stored value if that
    /// matters — the `Binding` overload dedupes for you.
    /// -  Parameter onChange: Closure called with the latest size on every layout pass.
    @ViewBuilder
    func airshipMeasureView(onChange: @escaping (CGSize) -> Void) -> some View  {
        self.background(
            GeometryReader { geo -> Color in
                DispatchQueue.main.async {
                    onChange(geo.size)
                }
                return Color.clear
            }
        )
    }
}
