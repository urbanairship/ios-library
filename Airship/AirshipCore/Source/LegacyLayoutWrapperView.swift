/* Copyright Airship and Contributors */

#if !os(watchOS)

import SwiftUI
import UIKit
import Combine

struct LegacyLayoutWrapperView: UIViewRepresentable {
    
    let placement: EmbeddedPlacement
    let bounds: AirshipEmbeddedViewBounds

    @Binding var viewConstraints: ViewConstraints?
    
    func makeUIView(context: Context) -> some UIView {
        return FrameListenerView { parentBounds in
            let constraints = ConstraintsHelper.calculate(with: bounds, frame: parentBounds)
            
            DispatchQueue.main.async {
                self.viewConstraints = constraints
            }
        }
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
        // this method is also called when the content embedded view is changed, so we need to update the placement
        if let view = uiView as? FrameListenerView {
            view.placement = placement
        }
    }
}

private class FrameListenerView: UIView {
    
    let onFrameChanged: (CGRect) -> Void
    var placement: EmbeddedPlacement? // can't store it as let property, becuase SwiftUI re-uses views
    
    private var reportedFrame: CGRect?
    
    init(handler: @escaping (CGRect) -> Void) {
        self.onFrameChanged = handler
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if
            let frame = superview?.frame,
            reportedFrame != frame {
            
            reportedFrame = frame
            onFrameChanged(frame)
        }
    }
    
    override var intrinsicContentSize: CGSize {
        let orig = super.intrinsicContentSize
        guard let placement = self.placement else { return orig }
        
        let height = placement.size.height.isFixedSize(false) ? placement.size.height.calculateSize(nil) : nil
        let width = placement.size.width.isFixedSize(false) ? placement.size.width.calculateSize(nil) : nil
        
        return CGSize(width: width ?? orig.width, height: height ?? orig.height)
    }
}

#endif
