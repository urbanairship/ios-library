/* Copyright Airship and Contributors */

public import Foundation
@_spi(AirshipInternal) import AirshipBasement

/// - NOTE: For internal use only. :nodoc:
@_spi(AirshipInternal)
@MainActor
public final class ExtendableAssetCacheImageProvider: AirshipImageProvider {

    private var parent: (any AirshipImageProvider)?
    private var children = [String: any AirshipImageProvider]()

    public init(
        parent: (@Sendable (URL) -> AirshipImageData?)? = nil
    ) {
        if let parent = parent {
            self.parent = ParentClosureCache(getter: parent)
        }
    }

    public func get(url: URL) -> AirshipImageData? {
        if let cached = parent?.get(url: url) { return cached }

        for child in children.values {
            if let result = child.get(url: url) {
                return result
            }
        }

        return nil
    }

    public func tryAddChild(_ cache: any AirshipImageProvider) -> String? {
        let id = UUID().uuidString
        children[id] = cache
        return id
    }

    public func removeChild(token: String) {
        self.children.removeValue(forKey: token)
    }
}

@MainActor
private final class ParentClosureCache: AirshipImageProvider {
    private let getter: (@Sendable (URL) -> AirshipImageData?)

    init(getter: @escaping (@Sendable (URL) -> AirshipImageData?)) {
        self.getter = getter
    }

    func get(url: URL) -> AirshipImageData? {
        return getter(url)
    }

    func tryAddChild(_ cache: any AirshipImageProvider) -> String? {
        return nil
    }

    func removeChild(token: String) {}
}

@_spi(AirshipInternal)
@MainActor
public final class NonExtendableAssetCacheImageProvider: AirshipImageProvider {
    private let load: @Sendable (URL) -> AirshipImageData?

    public init(getter: @escaping @Sendable (URL) -> AirshipImageData?) {
        self.load = getter
    }

    public func get(url: URL) -> AirshipImageData? {
        load(url)
    }

    public func tryAddChild(_ cache: any AirshipImageProvider) -> String? {
        return nil
    }

    public func removeChild(token: String) {}
}
