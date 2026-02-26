/* Copyright Airship and Contributors */

import Foundation
import ObjectiveC

fileprivate struct SwizzlerEntry {
    let swizzledClass: AnyClass
    let originalImplementation: IMP
    let selectorString: String
}

@MainActor
internal class AirshipSwizzler {
    @objc fileprivate protocol ForwardingCheck {
        @objc func forwardingTarget(for aSelector: Selector!) -> Any?
    }

    private static var entryMap: [String: SwizzlerEntry] = [:]

    @discardableResult
    func swizzleInstance(
        _ instance: any NSObjectProtocol,
        selector: Selector,
        protocol: Protocol? = nil,
        implementation: IMP
    ) -> Bool {
        let clazz: AnyClass = classForSelector(selector, target: instance)
        return swizzleClass(clazz, selector: selector, protocol: `protocol`, implementation: implementation)
    }

    @discardableResult
    func swizzleClass(
        _ clazz: AnyClass,
        selector: Selector,
        protocol: Protocol? = nil,
        implementation: IMP
    ) -> Bool {
        let selectorString = NSStringFromSelector(selector)
        let key = "\(String(describing: clazz)).\(selectorString)"

        if Self.entryMap[key] != nil { return true }

        guard let method = class_getInstanceMethod(clazz, selector) else {
            if let proto = `protocol` {
                let desc = protocol_getMethodDescription(proto, selector, false, true)
                return class_addMethod(clazz, selector, implementation, desc.types)
            }
            return false
        }

        let typeEncoding = method_getTypeEncoding(method)

        if class_addMethod(clazz, selector, implementation, typeEncoding) {
            let original = method_getImplementation(method)
            Self.entryMap[key] = SwizzlerEntry(swizzledClass: clazz, originalImplementation: original, selectorString: selectorString)
        } else {
            let existing = method_setImplementation(method, implementation)
            if implementation != existing {
                Self.entryMap[key] = SwizzlerEntry(swizzledClass: clazz, originalImplementation: existing, selectorString: selectorString)
            }
        }

        return true
    }

    func originalImplementation(_ selector: Selector, forClass clazz: AnyClass) -> IMP? {
        let key = "\(String(describing: clazz)).\(NSStringFromSelector(selector))"
        return Self.entryMap[key]?.originalImplementation
    }

    private func classForSelector(_ selector: Selector, target: any NSObjectProtocol) -> AnyClass {
        if class_getInstanceMethod(type(of: target), selector) != nil {
            return type(of: target)
        }

        if
            target.responds(to: #selector(NSObject.forwardingTarget(for:))),
            let forwarder = target as? any ForwardingCheck,
            let forwardingTarget = forwarder.forwardingTarget(for: selector) as? any NSObjectProtocol
        {
            return classForSelector(selector, target: forwardingTarget)
        }

        return type(of: target)
    }
}
