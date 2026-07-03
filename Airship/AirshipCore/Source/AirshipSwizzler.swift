/* Copyright Airship and Contributors */

import Foundation
@_spi(AirshipInternal) import AirshipBasement
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
        let key = "\(ObjectIdentifier(clazz)).\(selectorString)"

        if Self.entryMap[key] != nil { return true }

        guard let method = class_getInstanceMethod(clazz, selector) else {
            if let proto = `protocol` {
                AirshipLogger.debug("[UASwizzle] swizzleClass \(key): no method found, using protocol class_addMethod on \(NSStringFromClass(clazz))")
                let desc = protocol_getMethodDescription(proto, selector, false, true)
                return class_addMethod(clazz, selector, implementation, desc.types)
            }
            return false
        }

        AirshipLogger.debug("[UASwizzle] swizzleClass \(key): method found on \(NSStringFromClass(clazz))")
        let typeEncoding = method_getTypeEncoding(method)

        if class_addMethod(clazz, selector, implementation, typeEncoding) {
            let original = method_getImplementation(method)
            AirshipLogger.debug("[UASwizzle] swizzleClass \(key): class_addMethod succeeded (inherited), original=\(original)")
            Self.entryMap[key] = SwizzlerEntry(swizzledClass: clazz, originalImplementation: original, selectorString: selectorString)
        } else {
            let existing = method_setImplementation(method, implementation)
            AirshipLogger.debug("[UASwizzle] swizzleClass \(key): method_setImplementation, existing=\(existing) same=\(implementation == existing)")
            if implementation != existing {
                Self.entryMap[key] = SwizzlerEntry(swizzledClass: clazz, originalImplementation: existing, selectorString: selectorString)
            }
        }

        return true
    }

    func originalImplementation(_ selector: Selector, forClass clazz: AnyClass) -> IMP? {
        let key = "\(ObjectIdentifier(clazz)).\(NSStringFromSelector(selector))"
        return Self.entryMap[key]?.originalImplementation
    }

    private func classForSelector(_ selector: Selector, target: any NSObjectProtocol) -> AnyClass {
        let nominalClass: AnyClass = type(of: target)
        let runtimeClass: AnyClass = object_getClass(target) ?? nominalClass

        AirshipLogger.debug("[UASwizzle] classForSelector \(NSStringFromSelector(selector)): nominal=\(NSStringFromClass(nominalClass)) runtime=\(NSStringFromClass(runtimeClass))")

        if class_getInstanceMethod(runtimeClass, selector) != nil {
            return runtimeClass
        }

        if
            target.responds(to: #selector(NSObject.forwardingTarget(for:))),
            let forwarder = target as? any ForwardingCheck,
            let forwardingTarget = forwarder.forwardingTarget(for: selector) as? any NSObjectProtocol
        {
            return classForSelector(selector, target: forwardingTarget)
        }

        AirshipLogger.debug("[UASwizzle] classForSelector \(NSStringFromSelector(selector)): method not found on \(NSStringFromClass(runtimeClass)), will use class_addMethod")
        return runtimeClass
    }
}
