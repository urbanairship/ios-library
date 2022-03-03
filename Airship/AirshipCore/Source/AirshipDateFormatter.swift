/* Copyright Airship and Contributors */

import Foundation

/// - Note: for internal use only.  :nodoc:
@objc(UADateFormatter)
public class AirshipDateFormatter : NSObject {

    @objc(UADateFormatterFormat)
    public enum Format : Int {
        /// ISO 8601
        case iso
        /// ISO 8601 with delimitter
        case isoDelimitter
        /// Short date & time format
        case relativeShort
        /// Short date format
        case relativeShortDate
        /// Full date & time format
        case relativeFull
        /// Full date format
        case relativeFullDate
    }

    private static let dateFormatterISO : DateFormatter = createDateFormatter { formatter in
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeStyle = .full
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
    }

    private static let dateFormatterISOWithDelimiter : DateFormatter = createDateFormatter { formatter in
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeStyle = .full
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
    }

    private static let dateFormatterRelativeFull : DateFormatter = createDateFormatter { formatter in
        formatter.timeStyle = .full
        formatter.dateStyle = .full
        formatter.doesRelativeDateFormatting = true
    }

    private static let dateFormatterRelativeShort : DateFormatter = createDateFormatter { formatter in
        formatter.timeStyle = .short
        formatter.dateStyle = .short
        formatter.doesRelativeDateFormatting = true
    }

    private static let dateFormatterRelativeShortDate : DateFormatter = createDateFormatter { formatter in
        formatter.timeStyle = .none
        formatter.dateStyle = .short
        formatter.doesRelativeDateFormatting = true
    }

    private static let dateFormatterRelativeFullDate : DateFormatter = createDateFormatter { formatter in
        formatter.timeStyle = .none
        formatter.dateStyle = .full
        formatter.doesRelativeDateFormatting = true
    }

    /// Parses ISO 8601 date strings.
    ///
    /// Supports timestamps with just year all the way up to seconds with and without the optional `T` delimeter.
    ///
    /// - Parameter from: The ISO 8601 timestamp.
    ///
    /// - Returns: A parsed Date object, or nil if the timestamp is not a valid format.
    @objc
    public class func date(fromISOString from: String) -> Date? {
        if let date = dateFormatterISO.date(from: from) {
            return date
        }

        if let date = dateFormatterISOWithDelimiter.date(from: from) {
            return date
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        // All the various formats
        let formats = ["yyyy-MM-dd'T'HH:mm:ss.SSS",
                       "yyyy-MM-dd'T'HH:mm:ss",
                       "yyyy-MM-dd'T'HH:mm:ss'Z'",
                       "yyyy-MM-dd HH:mm:ss",
                       "yyyy-MM-dd'T'HH:mm",
                       "yyyy-MM-dd HH:mm",
                       "yyyy-MM-dd'T'HH",
                       "yyyy-MM-dd HH",
                       "yyyy-MM-dd",
                       "yyyy-MM",
                       "yyyy"];

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: from) {
                return date
            }
        }

        return nil
    }

    @objc
    public static func string(fromDate date: Date, format: Format) -> String {
        switch(format) {
        case .iso:
            return self.dateFormatterISO.string(from: date)
        case .isoDelimitter:
            return self.dateFormatterISOWithDelimiter.string(from: date)
        case .relativeShortDate:
            return self.dateFormatterRelativeShortDate.string(from: date)
        case .relativeFullDate:
            return self.dateFormatterRelativeFullDate.string(from: date)
        case .relativeFull:
            return self.dateFormatterRelativeFull.string(from: date)
        case .relativeShort:
            return self.dateFormatterRelativeShort.string(from: date)
        }
    }

    private static func createDateFormatter(editBlock:(DateFormatter) -> Void) -> DateFormatter {
        let formatter = DateFormatter()
        editBlock(formatter)
        return formatter
    }
}
