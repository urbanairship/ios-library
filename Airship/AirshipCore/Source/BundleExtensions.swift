import Foundation

public extension Bundle {

    /// Returns the bundle for the AirshipModule.
    /// NOTE: For internal use only. :nodoc:
    static func airshipModule(
        moduleName: String,
        sourceBundle: Bundle
    ) -> Bundle {

        AirshipLogger.trace("Loading Bundle for module \(moduleName)")
#if SWIFT_PACKAGE
        AirshipLogger.trace("Using Bundle.module for \(moduleName)")
        let bundle = Bundle.module
#if DEBUG
        if bundle.resourceURL == nil {
            assertionFailure("""
            Airship module '\(moduleName)' was built with SWIFT_PACKAGE
            but no resources were found. Check your build configuration.
            """)
        }
#endif
        return bundle
#endif

        let candidates = [
            "Airship_\(moduleName)", // SPM/Tuist
            "\(moduleName)Resources",  // Cocoapods
            "\(moduleName)_\(moduleName)" // Fallback for SPM/Tuist
        ]

        for searchContainer in [sourceBundle, Bundle.main] {
            for candidate in candidates {
                guard
                    let path = searchContainer.path(forResource: candidate, ofType: "bundle"),
                    let bundle = Bundle(path: path)
                else
                {
                    continue
                }

                AirshipLogger.trace("Found Bundle for \(moduleName) in \(searchContainer) with path \(candidate)")
                return bundle
            }
        }

        // Fallback to source bundle (XCFrameworks)
        AirshipLogger.trace("Using source Bundle for \(moduleName)")
        return sourceBundle
    }
}
