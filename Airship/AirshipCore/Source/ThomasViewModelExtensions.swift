/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
extension HexColor {
    func toColor() -> Color {
        guard let uiColor = ColorUtils.color(self.hex) else {
            return Color.clear
        }
        
        let alpha = self.alpha ?? 1
        return Color(uiColor).opacity(alpha)
    }
    
    func toUIColor() -> UIColor {
        let hexColor = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard let int = Scanner(string: hexColor).scanInt32(representation: .hexadecimal) else { return UIColor.white }
        
        let r, g, b: Int32
        switch hexColor.count {
        case 3:
            (r, g, b) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)  // RGB (12-bit)
        case 6:
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)                    // RGB (24-bit)
        default:
            (r, g, b) = (0, 0, 0)
        }
        
        return UIColor(red: CGFloat(r) / 255.0, green: CGFloat(g) / 255.0, blue: CGFloat(b) / 255.0, alpha: alpha ?? 0)
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
extension ThomasColor {
    func toColor(_ colorScheme: ColorScheme) -> Color {
        let darkMode = colorScheme == .dark
        for selector in selectors ?? [] {
            if let platform = selector.platform, platform != .ios {
                continue
            }
            
            if let selectorDarkMode = selector.darkMode, darkMode != selectorDarkMode {
                continue
            }
            
            return selector.color.toColor()
        }
        
        return defaultColor.toColor()
    }
    
    func toUIColor(_ colorScheme: ColorScheme) -> UIColor {
        if #available(iOS 14.0.0, tvOS 14.0.0, *) {
            return UIColor(toColor(colorScheme))
        } else {
            let darkMode = colorScheme == .dark
            for selector in selectors ?? [] {
                if let platform = selector.platform, platform != .ios {
                    continue
                }
                
                if let selectorDarkMode = selector.darkMode, darkMode != selectorDarkMode {
                    continue
                }
                
                return selector.color.toUIColor()
            }
            
            return defaultColor.toUIColor()
        }
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
extension VerticalPosition {
    func toAlignment() -> VerticalAlignment {
        switch (self) {
        case .top: return VerticalAlignment.top
        case .center: return VerticalAlignment.center
        case .bottom: return VerticalAlignment.bottom
        }
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
extension HorizontalPosition {
    func toAlignment() -> HorizontalAlignment {
        switch (self) {
        case .start: return HorizontalAlignment.leading
        case .center: return HorizontalAlignment.center
        case .end: return HorizontalAlignment.trailing
        }
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
extension HexColor {
    static let clear = HexColor(hex: "#000000", alpha: 0.00001)
}


private enum ParentController {
    case form
    case pager
    case radio
    case checkbox
}

extension Layout {
    func validate() throws {
        /// We only need to validate that the layout wont produce runtime exceptions due to expected environments
        try self.view.validate(Set<ParentController>())
    }
}

private extension ViewModel {

    func validate(_ parentControllers: Set<ParentController>) throws {
        var controllers = parentControllers

        switch (self) {
        case .container(let model):
            try model.items.forEach { try $0.view.validate(controllers) }
        case .linearLayout(let model):
            try model.items.forEach { try $0.view.validate(controllers) }
        case .scrollLayout(let model):
            try model.view.validate(controllers)
        case .pager(let model):
            if (!parentControllers.contains(.pager)) {
                throw AirshipErrors.error("Pager must be a descendent of a pager controller")
            }
            try model.items.forEach { try $0.view.validate(controllers) }
        case .pagerIndicator(_):
            if (!parentControllers.contains(.pager)) {
                throw AirshipErrors.error("Pager indicator must be a descendent of a pager controller")
            }
        case .pagerController(let model):
            controllers.insert(.pager)
            try model.view.validate(controllers)
            
        case .npsController(let model):
            if (model.submit == nil && !controllers.contains(.form)) {
                throw AirshipErrors.error("Child NPS controller must be a descendent of a form or nps controller")
            }
            
            controllers.insert(.form)
            try model.view.validate(controllers)
        case .formController(let model):
            if (model.submit == nil && !controllers.contains(.form)) {
                throw AirshipErrors.error("Child form controller must be a descendent of a form or nps controller")
            }
            
            controllers.insert(.form)
            try model.view.validate(controllers)
        case .checkbox(_):
            if (!controllers.contains(.checkbox)) {
                throw AirshipErrors.error("Checkbox form controller must be a descendent of a form or nps controller")
            }
        case .checkboxController(let model):
            if (!controllers.contains(.form)) {
                throw AirshipErrors.error("Checkbox controller must be a descendent of a form or nps controller")
            }
            
            controllers.insert(.checkbox)
            try model.view.validate(controllers)
        case .radioInput(_):
            if (!controllers.contains(.radio)) {
                throw AirshipErrors.error("Radio input must be a descendent of a radio input controller")
            }
        case .radioInputController(let model):
            if (!controllers.contains(.form)) {
                throw AirshipErrors.error("Radio input controller must be a descendent of a form or nps controller")
            }
            
            controllers.insert(.radio)
            try model.view.validate(controllers)
        case .textInput(_):
            if (!controllers.contains(.form)) {
                throw AirshipErrors.error("Text input must be a descendent of a form or nps controller")
            }
        case .score(_):
            if (!controllers.contains(.form)) {
                throw AirshipErrors.error("Score input must be a descendent of a form or nps controller")
            }

        case .toggle(_):
            if (!controllers.contains(.form)) {
                throw AirshipErrors.error("Toggle input must be a descendent of a form or nps controller")
            }
        case .imageButton(let model):
           try model.clickBehaviors?.forEach {
               switch ($0) {
               case .formSubmit:
                   if (!controllers.contains(.form)) {
                       throw AirshipErrors.error("Toggle input must be a descendent of a form or nps controller")
                   }
               case .pagerNext:
                   if (!controllers.contains(.form)) {
                       throw AirshipErrors.error("Toggle input must be a descendent of a form or nps controller")
                   }
               case .pagerPrevious:
                   if (!controllers.contains(.form)) {
                       throw AirshipErrors.error("Toggle input must be a descendent of a form or nps controller")
                   }
               default:
                   return
               }
            }
        default:
            return
        }
    }
    
    private func validateButtonBehaviors(_ clickBehaviors: [ButtonClickBehavior]?,
                                         _ enableBehaviors: [EnableBehavior]?,
                                         _ controllers: Set<ParentController>) throws {
        
        try clickBehaviors?.forEach {
             switch ($0) {
             case .formSubmit:
                 if (!controllers.contains(.form)) {
                     throw AirshipErrors.error("Button with form subimt behavior must be a descendent of a form or nps controller")
                 }
             case .pagerNext:
                 if (!controllers.contains(.pager)) {
                     throw AirshipErrors.error("Button with pager next behavior must be a descendent of a pager controller")
                 }
             case .pagerPrevious:
                 if (!controllers.contains(.pager)) {
                     throw AirshipErrors.error("Button with pager previous behavior must be a descendent of a pager controller")
                 }
             default:
                 return
             }
            
         }
        
        try enableBehaviors?.forEach {
             switch ($0) {
             case .formValidation:
                 if (!controllers.contains(.form)) {
                     throw AirshipErrors.error("Button with form subimt behavior must be a descendent of a form or nps controller")
                 }
             case .formSubmission:
                 if (!controllers.contains(.form)) {
                     throw AirshipErrors.error("Button with form submission behavior must be a descendent of a form or nps controller")
                 }
             case .pagerNext:
                 if (!controllers.contains(.pager)) {
                     throw AirshipErrors.error("Button with pager next behavior must be a descendent of a pager controller")
                 }
             case .pagerPrevious:
                 if (!controllers.contains(.pager)) {
                     throw AirshipErrors.error("Button with pager previous behavior must be a descendent of a pager controller")
                 }
             }
        }
    }
}

