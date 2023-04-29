/* Copyright Airship and Contributors */

import SwiftUI

struct TopTrapezoid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.width * 0.3 * 2, y: rect.height * 0.3))
        path.addLine(to: CGPoint(x: rect.width * 0.3, y: rect.height * 0.3))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        
        return path
    }
}

struct BottomTrapezoid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        path.move(to: CGPoint(x: rect.width * 0.3, y: rect.height * 0.3 * 2))
        path.addLine(to: CGPoint(x: rect.width * 0.3 * 2, y: rect.height * 0.3 * 2))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.width * 0.3, y: rect.height * 0.3 * 2))
        
        return path
    }
}

struct RightTrapezoid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.width * 0.3 * 2, y: rect.height * 0.3 * 2))
        path.addLine(to: CGPoint(x: rect.width * 0.3 * 2, y: rect.height * 0.3))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        
        return path
    }
}

struct LeftTrapezoid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.width * 0.3, y: rect.height * 0.3 * 2))
        path.addLine(to: CGPoint(x: rect.width * 0.3, y: rect.height * 0.3))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        
        return path
    }
}

struct CenterRectangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.3, y: rect.height * 0.3))
        path.addLine(to: CGPoint(x: rect.width * 0.3 * 2, y: rect.height * 0.3))
        path.addLine(to: CGPoint(x: rect.width * 0.3 * 2, y: rect.height * 0.3 * 2))
        path.addLine(to: CGPoint(x: rect.width * 0.3, y: rect.height * 0.3 * 2))
        path.addLine(to: CGPoint(x: rect.width * 0.3, y: rect.height * 0.3))
        
        return path
    }
}

struct PagerGestureMapExplorer {
    
    let topTrapezoidPath: Path
    let bottomTrapezoidPath: Path
    let leftTrapezoidPath: Path
    let rightTrapezoidPath: Path
    let centerTrapezoidPath: Path
    
    init(_ rect: CGRect) {
        topTrapezoidPath = TopTrapezoid().path(in: rect)
        bottomTrapezoidPath = BottomTrapezoid().path(in: rect)
        leftTrapezoidPath = LeftTrapezoid().path(in: rect)
        rightTrapezoidPath = RightTrapezoid().path(in: rect)
        centerTrapezoidPath = CenterRectangle().path(in: rect)
    }
    
    func location(
        forPoint point: CGPoint
    ) -> PagerGestureLocation {
        if topTrapezoidPath.contains(point) {
            return .top
        }
        if bottomTrapezoidPath.contains(point) {
            return .bottom
        }
        if leftTrapezoidPath.contains(point) {
            return .left
        }
        if rightTrapezoidPath.contains(point) {
            return .right
        }
        if centerTrapezoidPath.contains(point) {
            return .center
        }
        return .none
    }
}

struct PagerGestureMap: View {
    var body: some View {
        Rectangle()
            .stroke(lineWidth: 10)
            .fill(.green)
            .overlay {
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
    }
}

struct PagerGestureMap_Previews: PreviewProvider {
    static var previews: some View {
        PagerGestureMap()
            .frame(width: 400, height: 800)
    }
}
