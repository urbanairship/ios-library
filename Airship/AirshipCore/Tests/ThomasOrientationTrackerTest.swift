/* Copyright Airship and Contributors */

import Testing
import CoreGraphics

@testable import AirshipCore

@MainActor
struct ThomasOrientationTrackerTest {

    @Test
    func landscapeWhenWiderThanTall() {
        let tracker = ThomasOrientationTracker()
        tracker.update(CGSize(width: 800, height: 400))
        #expect(tracker.orientation == .landscape)
    }

    @Test
    func portraitWhenTallerThanWide() {
        let tracker = ThomasOrientationTracker()
        tracker.update(CGSize(width: 400, height: 800))
        #expect(tracker.orientation == .portrait)
    }

    /// A square window has to tip somewhere. It goes to portrait, matching Android, where
    /// `Configuration.orientation` reports portrait unless width strictly exceeds height.
    @Test
    func squareCountsAsPortrait() {
        let tracker = ThomasOrientationTracker()
        tracker.update(CGSize(width: 500, height: 500))
        #expect(tracker.orientation == .portrait)
    }

    /// Nothing has reported a window yet, so the seed must not be mistaken for a real measurement.
    @Test
    func emptySizesAreIgnored() {
        let tracker = ThomasOrientationTracker()
        tracker.update(CGSize(width: 800, height: 400))
        #expect(tracker.orientation == .landscape)

        tracker.update(.zero)
        tracker.update(CGSize(width: 0, height: 400))
        tracker.update(CGSize(width: 800, height: 0))
        tracker.update(nil)

        #expect(tracker.orientation == .landscape)
    }

    @Test
    func tracksAcrossAResize() {
        let tracker = ThomasOrientationTracker(initialSize: CGSize(width: 400, height: 800))
        #expect(tracker.orientation == .portrait)

        tracker.update(CGSize(width: 800, height: 400))
        #expect(tracker.orientation == .landscape)

        tracker.update(CGSize(width: 400, height: 800))
        #expect(tracker.orientation == .portrait)
    }

    @Test
    func initialSizeSeedsOrientation() {
        #expect(ThomasOrientationTracker(initialSize: CGSize(width: 800, height: 400)).orientation == .landscape)
        #expect(ThomasOrientationTracker(initialSize: CGSize(width: 400, height: 800)).orientation == .portrait)
    }
}

// MARK: - Diagnostic: does the scene reader re-report after a window resize?

#if os(iOS)
import SwiftUI
import UIKit

@MainActor
private final class ReportBox {
    var sizes: [CGSize] = []
}

@MainActor
struct ThomasSceneSizeReaderResizeTest {

    private func runResize<V: View>(content: V) async throws -> [CGSize] {
        let box = ReportBox()
        let probed = content.background(
            ThomasSceneSizeReader { size in
                if let size { box.sizes.append(size) }
            }
        )

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        let host = UIHostingController(rootView: probed)
        window.rootViewController = host
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(60))

        box.sizes.removeAll()   // ignore insertion-time reports; we want post-resize behavior

        window.frame = CGRect(x: 0, y: 0, width: 800, height: 400)
        window.layoutIfNeeded()
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(60))

        return box.sizes
    }

    @Test
    func windowFillingContentReportsAfterResize() async throws {
        let reports = try await runResize(
            content: Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
        )
        print("FILLING reports: \(reports)")
        #expect(!reports.isEmpty)
    }

    /// A points-sized embedded placement: `AdoptLayout` pins the frame, so the probe's own bounds
    /// never change across a resize.
    @Test
    func fixedSizeContentReportsAfterResize() async throws {
        let reports = try await runResize(
            content: Color.clear.frame(width: 100, height: 100)
        )
        print("FIXED reports: \(reports)")
        #expect(!reports.isEmpty)
    }

    /// The `AirshipSimpleLayoutView` shape: content that fills 100% of whatever it is given, placed
    /// by a host app inside a container that does not resize. Nothing in a payload can prevent this.
    @Test
    func fillingContentInFixedContainerReportsAfterResize() async throws {
        let reports = try await runResize(
            content: Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(width: 320, height: 480)
        )
        print("FILLING-IN-FIXED reports: \(reports)")
        #expect(!reports.isEmpty)
    }
}
#endif
