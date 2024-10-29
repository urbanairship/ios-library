/* Copyright Airship and Contributors */

import SwiftUI

extension PagerModel {
    var isDefaultSwipeEnabled: Bool {
        return disableSwipe != true && self.items.count > 1
    }

    func retrieveGestures<T: PagerGesture>(type: T.Type) -> [T] {
        guard let gestures = self.gestures else {
            return []
        }

        return gestures.compactMap { gesture in
            switch gesture {
            case .tapGesture(let model):
                return model as? T
            case .swipeGesture(let model):
                return model as? T
            case .holdGesture(let model):
                return model as? T
            }
        }
    }

    func containsGestures(_ types: [PagerGestureType]) -> Bool {
        guard let gestures = gestures else {
            return false
        }

        return gestures.contains(where: { gesture in
            switch(gesture) {
            case .swipeGesture(let gesture): return types.contains(gesture.type)
            case .tapGesture(let gesture): return types.contains(gesture.type)
            case .holdGesture(let gesture): return types.contains(gesture.type)
            }
        })
    }
}

extension Array where Element == AutomatedAction {
    var earliestNavigationAction: AutomatedAction? {
        return self.first {
            return $0.behaviors?.filter {
                return switch($0) {
                case .dismiss: true
                case .cancel: true
                case .pagerNext: true
                case .pagerPrevious: true
                case .pagerNextOrDismiss: true
                case .pagerNextOrFirst: true

                case .formSubmit: false
                case .pagerPause: false
                case .pagerResume: false
                }
            }.isEmpty == false
        }
    }
}

extension View {
#if !os(tvOS)
    @ViewBuilder
    func addPagerTapGesture(onTouch: @escaping (Bool) -> Void, onTap: @escaping (CGPoint) -> Void) -> some View {
        if #available(iOS 16.0, macOS 13.0, watchOS 9.0, visionOS 1.0, *) {
            self.onTouch { isPressed in
                onTouch(isPressed)
            }
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { event in
                        onTap(event.location)
                    }
                )
        } else {
            self.onTouch { isPressed in
                onTouch(isPressed)
            }
        }
    }
#endif
}
