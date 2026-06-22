/* Copyright Airship and Contributors */

public import Foundation

@_spi(AirshipInternal)
public enum AirshipVersionUtils {
    public static func compareVersions(
        _ fromVersion: String,
        toVersion: String,
        maxVersionParts: Int? = nil
    ) -> ComparisonResult {
        if let maxVersionParts, maxVersionParts <= 0 {
            return .orderedSame
        }

        let fromParts = fromVersion.components(separatedBy: ".").map {
            ($0 as NSString).integerValue
        }

        let toParts = toVersion.components(separatedBy: ".").map {
            ($0 as NSString).integerValue
        }

        var i = 0
        while fromParts.count > i || toParts.count > i {
            let from: Int = fromParts.count > i ? fromParts[i] : 0
            let to: Int = toParts.count > i ? toParts[i] : 0

            if from < to {
                return .orderedAscending
            } else if from > to {
                return .orderedDescending
            }
            i += 1

            if let maxVersionParts, maxVersionParts <= i {
                break
            }
        }

        return .orderedSame
    }
}
