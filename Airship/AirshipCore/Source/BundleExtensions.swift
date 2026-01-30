import Foundation

public extension Bundle {

    /// Returns the bundle for the AirshipModule.
    /// NOTE: For internal use only. :nodoc:
    static func airshipFindModule(
        moduleName: String,
        sourceBundle: Bundle
    ) -> Bundle {
        AirshipLogger.trace("Searching for module \(moduleName) Bundle")
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
