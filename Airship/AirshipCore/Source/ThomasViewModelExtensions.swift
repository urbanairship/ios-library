/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

extension HexColor {
    func toColor() -> Color {
        guard let uiColor = AirshipColorUtils.color(self.hex) else {
            return Color.clear
        }

        let alpha = self.alpha ?? 1
        return Color(uiColor).opacity(alpha)
    }

    func toUIColor() -> UIColor {
        let hexColor = hex.trimmingCharacters(
            in: CharacterSet.alphanumerics.inverted
        )
        guard
            let int = Scanner(string: hexColor)
                .scanInt32(
                    representation: .hexadecimal
                )
        else { return UIColor.white }

        let r: Int32
        let g: Int32
        let b: Int32
        switch hexColor.count {
        case 3:
            (r, g, b) = (
                (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17
            )  // RGB (12-bit)
        case 6:
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)  // RGB (24-bit)
        default:
            (r, g, b) = (0, 0, 0)
        }

        return UIColor(
            red: CGFloat(r) / 255.0,
            green: CGFloat(g) / 255.0,
            blue: CGFloat(b) / 255.0,
            alpha: alpha ?? 0
        )
    }
}

extension ThomasColor {
    func toColor(_ colorScheme: ColorScheme) -> Color {
        let darkMode = colorScheme == .dark
        for selector in selectors ?? [] {
            if let platform = selector.platform, platform != .ios {
                continue
            }

            if let selectorDarkMode = selector.darkMode,
                darkMode != selectorDarkMode
            {
                continue
            }

            return selector.color.toColor()
        }

        return defaultColor.toColor()
    }

    func toUIColor(_ colorScheme: ColorScheme) -> UIColor {
        guard #available(iOS 14.0.0, tvOS 14.0.0, *) else {
            let darkMode = colorScheme == .dark
            for selector in selectors ?? [] {
                if let platform = selector.platform, platform != .ios {
                    continue
                }

                if let selectorDarkMode = selector.darkMode,
                    darkMode != selectorDarkMode
                {
                    continue
                }

                return selector.color.toUIColor()
            }

            return defaultColor.toUIColor()
        }
        return UIColor(toColor(colorScheme))
    }
}

extension VerticalPosition {
    func toAlignment() -> VerticalAlignment {
        switch self {
        case .top: return VerticalAlignment.top
        case .center: return VerticalAlignment.center
        case .bottom: return VerticalAlignment.bottom
        }
    }
}

extension HorizontalPosition {
    func toAlignment() -> HorizontalAlignment {
        switch self {
        case .start: return HorizontalAlignment.leading
        case .center: return HorizontalAlignment.center
        case .end: return HorizontalAlignment.trailing
        }
    }
}

extension HexColor {
    static let clear = HexColor(hex: "#000000", alpha: 0.00001)
    static let disabled = HexColor(hex: "#020202", alpha: 0.38)
}

private enum ParentController {
    case form
    case pager
    case radio
    case checkbox
}

extension AirshipLayout {
    static let minLayoutVersion = 1
    static let maxLayoutVersion = 2

    public func validate() -> Bool
    {
        guard
            self.version >= Self.minLayoutVersion
                && self.version <= Self.maxLayoutVersion else {
            return false
        }
        /// We only need to validate that the layout wont produce runtime exceptions due to expected environments
        /// Pass in an initially empty set here for storing parent controllers since they're nested
        return self.view.validate(Set<ParentController>())
    }
}

extension ViewModel {
    fileprivate func validate(_ parentControllers: Set<ParentController>) -> Bool
    {
        var controllers = parentControllers

        switch self {
        case .container(let model):
            return model.items.allSatisfy{ $0.view.validate(controllers) }
        case .linearLayout(let model):
            return model.items.allSatisfy { $0.view.validate(controllers) }
        case .scrollLayout(let model):
            return model.view.validate(controllers)
        case .pager(let model):
            return model.items.allSatisfy { $0.view.validate(controllers) }
        case .pagerIndicator(_):
            if !parentControllers.contains(.pager) {
                AirshipLogger.debug("Pager indicator must be a descendent of a pager controller")
                return false
            }
        case .pagerController(let model):
            controllers.insert(.pager)
            return model.view.validate(controllers)
        case .npsController(let model):
            if model.submit == nil && !controllers.contains(.form) {
                AirshipLogger.debug("Child NPS controller must be a descendent of a form or nps controller")
                return false
            }

            controllers.insert(.form)
            return model.view.validate(controllers)
        case .formController(let model):
            if model.submit == nil && !controllers.contains(.form) {
                AirshipLogger.debug("Child form controller must be a descendent of a form or nps controller")
                return false
            }

            controllers.insert(.form)
            return model.view.validate(controllers)
        case .checkbox(_):
            if !controllers.contains(.checkbox) {
                AirshipLogger.debug("Checkbox form controller must be a descendent of a form or nps controller")
                return false
            }
        case .checkboxController(let model):
            if !controllers.contains(.form) {
                AirshipLogger.debug("Checkbox controller must be a descendent of a form or nps controller")
                return false
            }

            controllers.insert(.checkbox)
            return model.view.validate(controllers)
        case .radioInput(_):
            if !controllers.contains(.radio) {
                AirshipLogger.debug("Radio input must be a descendent of a radio input controller")
                return false
            }
        case .radioInputController(let model):
            if !controllers.contains(.form) {
                AirshipLogger.debug("Radio input controller must be a descendent of a form or nps controller")
                return false
            }

            controllers.insert(.radio)
            return model.view.validate(controllers)
        case .textInput(_):
            if !controllers.contains(.form) {
                AirshipLogger.debug("Text input must be a descendent of a form or nps controller")
                return false
            }
        case .score(_):
            if !controllers.contains(.form) {
                AirshipLogger.debug("Score input must be a descendent of a form or nps controller")
                return false
            }

        case .toggle(_):
            if !controllers.contains(.form) {
                AirshipLogger.debug("Toggle input must be a descendent of a form or nps controller")
                return false
            }
        case .imageButton(let model):
            guard let clickBehaviors = model.clickBehaviors else {
                return true
            }

            return clickBehaviors
                .allSatisfy {
                    switch $0 {
                    case .formSubmit:
                        if !controllers.contains(.form) {
                            AirshipLogger.debug("Toggle input must be a descendent of a form or nps controller")
                            return false
                        }
                    case .pagerNext:
                        if !controllers.contains(.form) {
                            AirshipLogger.debug("Toggle input must be a descendent of a form or nps controller")
                            return false
                        }
                    case .pagerPrevious:
                        if !controllers.contains(.form) {
                            AirshipLogger.debug("Toggle input must be a descendent of a form or nps controller")
                            return false
                        }
                    default:
                       return true
                    }

                    return true
                }
        default:
            return true
        }

        return true
    }

    private func validateButtonBehaviors(
        _ clickBehaviors: [ButtonClickBehavior]?,
        _ enableBehaviors: [EnableBehavior]?,
        _ controllers: Set<ParentController>
    ) -> Bool {
        var clickBehaviorsValid:Bool = true
        var enableBehaviorsValid:Bool = true

        if let clickBehaviors = clickBehaviors {
            clickBehaviorsValid = clickBehaviors
                .allSatisfy {
                    switch $0 {
                    case .formSubmit:
                        if !controllers.contains(.form) {
                            AirshipLogger.debug("Button with form submit behavior must be a descendent of a form or nps controller")
                            return false
                        }
                    case .pagerNext:
                        if !controllers.contains(.pager) {
                            AirshipLogger.debug("Button with pager next behavior must be a descendent of a pager controller")
                            return false
                        }
                    case .pagerPrevious:
                        if !controllers.contains(.pager) {
                            AirshipLogger.debug("Button with pager previous behavior must be a descendent of a pager controller")
                            return false
                        }
                    default:
                        return true
                    }

                    return true
                }
        }

        if let enableBehaviors = enableBehaviors {
            enableBehaviorsValid =  enableBehaviors
                .allSatisfy {
                    switch $0 {
                    case .formValidation:
                        if !controllers.contains(.form) {
                            AirshipLogger.debug("Button with form submit behavior must be a descendent of a form or nps controller")
                            return false
                        }
                    case .formSubmission:
                        if !controllers.contains(.form) {
                            AirshipLogger.debug("Button with form submission behavior must be a descendent of a form or nps controller")
                            return false
                        }
                    case .pagerNext:
                        if !controllers.contains(.pager) {
                            AirshipLogger.debug("Button with pager next behavior must be a descendent of a pager controller")
                            return false
                        }
                    case .pagerPrevious:
                        if !controllers.contains(.pager) {
                            AirshipLogger.debug("Button with pager previous behavior must be a descendent of a pager controller")
                            return false
                        }
                    }

                    return true
                }
        }

        return clickBehaviorsValid && enableBehaviorsValid
    }
}
