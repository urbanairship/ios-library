/* Copyright Airship and Contributors */

import Foundation

#if !os(tvOS)
import UserNotifications

struct MediaAttachmentPayload: Sendable, Decodable {

    let media: [ContentMedia]
    let textContent: ContentText?
    let options: PayloadOptions
    let thumbnailID: String?
    
    enum CodingKeys: String, CodingKey {
        case url = "url"
        case urlArray = "urls"
        case thumbnail = "thumbnail_id"
        case options = "options"
        case content = "content"
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let payloadUrl: [[String: String]]
        if container.contains(.urlArray) {
            payloadUrl = try container.decode([[String: String]].self, forKey: .urlArray)
        } else if container.contains(.url) {
            let urls: [String]
            do {
                urls = try container.decode([String].self, forKey: .url)
            } catch {
                urls = [try container.decode(String.self, forKey: .url)]
            }
            payloadUrl = urls.map({ [ContentMedia.CodingKeys.url.rawValue: $0] })
        } else {
            throw DecodingError.keyNotFound(CodingKeys.url, .init(codingPath: container.codingPath, debugDescription: "Failed to parse URLs"))
        }
        
        self.media = payloadUrl.compactMap(ContentMedia.init)
        self.thumbnailID = try container.decodeIfPresent(String.self, forKey: .thumbnail)
        self.options = try container.decodeIfPresent(PayloadOptions.self, forKey: .options) ?? PayloadOptions()
        self.textContent = try container.decodeIfPresent(ContentText.self, forKey: .content)
    }
    
    struct ContentText: Decodable, Sendable {
        let title: String?
        let subtitle: String?
        let body: String?
        
        enum CodingKeys: String, CodingKey {
            case title
            case subtitle
            case body
        }
    }
    
    struct ContentMedia: Sendable {
        let url: URL
        let urldID: String?
        
        enum CodingKeys: String, CodingKey {
            case url = "url"
            case urlID = "url_id"
        }
        
        init?(source: [String: String]) {
            guard
                let urlString = source[CodingKeys.url.rawValue],
                let url = URL(string: urlString)
            else {
                return nil
            }
            
            self.url = url
            
            var isValid = true
            (isValid, self.urldID) = validateAndParse(source[CodingKeys.urlID.rawValue])
            if !isValid { return nil }
        }
        
        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let urlString = try container.decode(String.self, forKey: .url)
            guard let url = URL(string: urlString) else {
                throw DecodingError.typeMismatch(URL.self, .init(codingPath: container.codingPath, debugDescription: "Failed to parse URL \(urlString)"))
            }
            self.url = url
            self.urldID = try container.decodeIfPresent(String.self, forKey: .urlID)
        }
    }
    
    struct PayloadOptions: Decodable, Sendable {
        private static let cropRequiredFields = ["x", "y", "width", "height"]
        let crop: [String: Double]?
        let time: Double?
        let hidden: Bool?
        
        enum CodingKeys: String, CodingKey {
            case crop = "crop"
            case time = "time"
            case hidden = "hidden"
        }
        
        init() {
            self.crop = nil
            self.time = nil
            self.hidden = nil
        }
        
        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.time = try container.decodeIfPresent(Double.self, forKey: .time)
            self.hidden = try container.decodeIfPresent(Bool.self, forKey: .hidden)
            self.crop = try container.decodeIfPresent([String: Double].self, forKey: .crop)
            
            try validate()
        }
        
        private func validate() throws {
            guard let crop = self.crop else { return }
            
            for requiredKey in Self.cropRequiredFields {
                guard
                    let value = crop[requiredKey],
                    value >= 0.0 && value <= 1.0
                else {
                    throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Failed to crop key \(requiredKey) \(crop)"))
                }
            }
        }
        
        func generateNotificationAttachmentOptions(hideThumbnail: Bool) -> [String: any Sendable] {
            var result: [String: any Sendable] = [UNNotificationAttachmentOptionsThumbnailHiddenKey: hideThumbnail]

            if let crop = self.crop {
                let normalized = crop.reduce(into: [String: Double]()) { partialResult, entry in
                    partialResult[entry.key.capitalized] = entry.value
                }
                result[UNNotificationAttachmentOptionsThumbnailClippingRectKey] = normalized
            }
            
            if let time = self.time {
                result[UNNotificationAttachmentOptionsThumbnailTimeKey] = time
            }
            
            if let hidden = self.hidden {
                result[UNNotificationAttachmentOptionsThumbnailHiddenKey] = hidden
            }
            
            return result
        }
    }
}

extension MediaAttachmentPayload {
    private static func validateAndParse<T>(_ value: Any?) -> (Bool, T?) {
        guard let value = value else { return (true, nil) }
        guard let parsed = value as? T else { return (false, nil) }
        
        return (true, parsed)
    }
}
#endif
