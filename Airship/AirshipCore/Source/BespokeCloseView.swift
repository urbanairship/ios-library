/* Copyright Airship and Contributors */

import UIKit
#if !os(watchOS)
import QuartzCore

/**
 * A circle with an X in it, drawn to fill the frame.
 */
@objc(UABespokeCloseView)
public class BespokeCloseView : UIView {

    @objc
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.isOpaque = false
    }

    @objc
    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.isOpaque = false
    }

    public override func draw(_ rect: CGRect) {
        let strokeColor = UIColor.white

        // Draw a white circle
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(UIColor.black.cgColor)

        let circleInset = 5
        let circleRect = bounds.insetBy(dx: CGFloat(circleInset), dy: CGFloat(circleInset))
        context?.fillEllipse(in: circleRect)

        context?.setLineWidth(2)
        context?.setStrokeColor(strokeColor.cgColor)
        context?.strokeEllipse(in: circleRect)

        // The X gets to be a little smaller than the circle
        let xInset = 7

        let xFrame = circleRect.insetBy(dx: CGFloat(xInset), dy: CGFloat(xInset))

        // CGRect gymnastics
        let aPath = UIBezierPath()
        aPath.move(to: xFrame.origin) //minx, miny
        aPath.addLine(to: CGPoint(x: xFrame.maxX, y: xFrame.maxY))

        let bPath = UIBezierPath()
        bPath.move(to: CGPoint(x: xFrame.maxX, y: xFrame.minY))
        bPath.addLine(to: CGPoint(x: xFrame.minX, y: xFrame.maxY))

        // Set the render colors.
        strokeColor.setStroke()

        // Adjust the drawing options as needed.
        aPath.lineWidth = 3
        bPath.lineWidth = 3

        // Line cap style
        aPath.lineCapStyle = .butt
        bPath.lineCapStyle = .butt

        // Draw both strokes
        aPath.stroke()
        bPath.stroke()
    }
}

#endif
