/* Copyright Airship and Contributors */

import SwiftUI

fileprivate struct TopTrapezoid: Shape {
    func path(in rect: CGRect) -> Path {
        let thirdWidth = rect.width * 0.3
        let thirdHeight = rect.height * 0.3

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - thirdWidth, y: rect.minY + thirdHeight))
        path.addLine(to: CGPoint(x: rect.minX + thirdWidth, y: rect.minY + thirdHeight))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        return path
    }
}

fileprivate struct BottomTrapezoid: Shape {
    func path(in rect: CGRect) -> Path {
        let thirdWidth = rect.width * 0.3
        let thirdHeight = rect.height * 0.3

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - thirdWidth, y: rect.maxY - thirdHeight))
        path.addLine(to: CGPoint(x: rect.minX + thirdWidth, y: rect.maxY - thirdHeight))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        return path
    }
}

fileprivate struct RightTrapezoid: Shape {
    func path(in rect: CGRect) -> Path {
        let thirdWidth = rect.width * 0.3
        let thirdHeight = rect.height * 0.3

        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - thirdWidth, y: rect.maxY - thirdHeight))
        path.addLine(to: CGPoint(x: rect.maxX - thirdWidth, y: rect.minY + thirdHeight))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        return path
    }
}

fileprivate struct LeftTrapezoid: Shape {
    func path(in rect: CGRect) -> Path {
        let thirdWidth = rect.width * 0.3
        let thirdHeight = rect.height * 0.3

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + thirdWidth, y: rect.maxY - thirdHeight))
        path.addLine(to: CGPoint(x: rect.minX + thirdWidth, y: rect.minY + thirdHeight))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        return path
    }
}

fileprivate struct CenterRectangle: Shape {
    func path(in rect: CGRect) -> Path {
        let thirdWidth = rect.width * 0.3
        let thirdHeight = rect.height * 0.3

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + thirdWidth, y: rect.minY + thirdHeight))
        path.addLine(to: CGPoint(x: rect.minX + thirdWidth, y: rect.minY + thirdHeight))
        path.addLine(to: CGPoint(x: rect.maxX - thirdWidth, y: rect.minY + thirdHeight))
        path.addLine(to: CGPoint(x: rect.maxX - thirdWidth, y: rect.maxY - thirdHeight))
        path.addLine(to: CGPoint(x: rect.minX + thirdWidth, y: rect.maxY - thirdHeight))
        return path
    }
}


struct PagerGestureMapExplorer {
    
    let topTrapezoidPath: Path
    let bottomTrapezoidPath: Path
    let leftTrapezoidPath: Path
    let rightTrapezoidPath: Path
    let centerSquarePath: Path


    init(_ rect: CGRect) {
        topTrapezoidPath = TopTrapezoid().path(in: rect)
        bottomTrapezoidPath = BottomTrapezoid().path(in: rect)
        leftTrapezoidPath = LeftTrapezoid().path(in: rect)
        rightTrapezoidPath = RightTrapezoid().path(in: rect)
        centerSquarePath = CenterRectangle().path(in: rect)
    }
    
    func location(
        layoutDirection: LayoutDirection,
        forPoint point: CGPoint
    ) -> [PagerGestureLocation] {
        if topTrapezoidPath.contains(point) {
            return [.top, .any]
        }

        if bottomTrapezoidPath.contains(point) {
            return [.bottom, .any]
        }

        if leftTrapezoidPath.contains(point) {
            if (layoutDirection == .leftToRight) {
                return [.left, .start, .any]
            } else {
                return [.left, .end, .any]
            }
        }

        if rightTrapezoidPath.contains(point) {
            if (layoutDirection == .leftToRight) {
                return [.right, .end, .any]
            } else {
                return [.right, .start, .any]
            }
        }

        if centerSquarePath.contains(point) {
            return [.any]
        }

        return []
    }
}

struct PagerGestureMap: View {
    var body: some View {
        Rectangle()
            .overlayView {
                TopTrapezoid()
                    .fill(.blue)
                BottomTrapezoid()
                    .fill(.red)
                RightTrapezoid()
                    .fill(.yellow)
                LeftTrapezoid()
                    .fill(.purple)
                CenterRectangle()
                    .fill(.green)

            }
            .border(.red, width: 1)
    }
}

struct PagerGestureMap_Previews: PreviewProvider {
    static var previews: some View {
        PagerGestureMap()
    }
}
