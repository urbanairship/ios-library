/* Copyright Airship and Contributors */

import AirshipCore
@_spi(AirshipInternal) import AirshipBasement
import Foundation
internal import Yams
@_spi(AirshipInternal) import AirshipAutomation
import AirshipScenes
@_spi(AirshipInternal) import AirshipSceneRenderer

@MainActor
final class LayoutLoader: Sendable {
    private var cache: [LayoutType: [LayoutFile]] = [:]

    func load(type: LayoutType) -> [LayoutFile] {
        if let cached = cache[type] {
            return cached
        }

        let layouts = switch(type) {
        case .sceneModal:
            loadLayouts(directory: "/Scenes/Modal", type: .sceneModal)
        case .sceneBanner:
            loadLayouts(directory: "/Scenes/Banner", type: .sceneBanner)
        case .sceneEmbedded:
            loadLayouts(directory: "/Scenes/Embedded", type: .sceneEmbedded)
        case .messageModal:
            loadLayouts(directory: "/Messages/Modal", type: .messageModal)
        case .messageBanner:
            loadLayouts(directory: "/Messages/Banner", type: .messageBanner)
        case .messageFullscreen:
            loadLayouts(directory: "/Messages/Fullscreen", type: .messageFullscreen)
        case .messageHTML:
            loadLayouts(directory: "/Messages/HTML", type: .messageHTML)
        }

        self.cache[type] = layouts
        return layouts
    }

    private func loadLayouts(directory: String, type: LayoutType) -> [LayoutFile] {
        let path = Bundle.main.resourcePath! + directory
        do {
            return try FileManager.default.contentsOfDirectory(atPath: path).sorted().map { fileName in
                LayoutFile(directory: directory, fileName: fileName, type: type)
            }
        } catch {
            return []
        }
    }
}


struct LayoutFile: Equatable, Hashable, Codable, Identifiable {
    let directory: String
    let fileName: String
    let type: LayoutType
    var id: String { directory + "/" + fileName }
}

enum LayoutType: Equatable, Hashable, Codable {
    case sceneModal
    case sceneBanner
    case sceneEmbedded
    case messageModal
    case messageBanner
    case messageFullscreen
    case messageHTML
}

extension LayoutFile {
    /// - Parameter imageURLOverride: when set, every piece of remote content in a scene is stubbed
    ///   before display (see `stubbingRemoteContent`), with images pointed at this URL. UI tests
    ///   use it so screenshots never depend on the network or on animation timing.
    @MainActor
    func open(imageURLOverride: URL? = nil) async throws {
        let filePath = Bundle.main.resourcePath! + directory + "/" + fileName
        let data = try loadData(filePath: filePath)

        switch self.type {
        case .sceneModal, .sceneBanner, .sceneEmbedded:
            try await displayScene(data, imageURLOverride: imageURLOverride)
        case .messageModal, .messageBanner, .messageFullscreen, .messageHTML:
            try await displayMessage(data)
        }
    }

    /// Decodes the file's layout without displaying it, so a host other than the normal
    /// presentation pipeline can render it (see "MC mode" in `LayoutsList`).
    @MainActor
    func loadAirshipLayout() throws -> AirshipLayout {
        let filePath = Bundle.main.resourcePath! + directory + "/" + fileName
        let data = try loadData(filePath: filePath)
        var layoutData = try extractLayoutFromPayload(data)
        layoutData = try Self.resolvingTestLayoutURLs(in: layoutData)
        return try JSONDecoder().decode(AirshipLayout.self, from: layoutData)
    }

    private func loadData(filePath: String) throws -> Data {
        /// Retrieve the content
        let stringContent = try getContentOfFile(filePath: filePath)

        /// If we already have json in the file, don't bother to convert it from yaml
        if isJSONString(stringContent) {
            guard let jsonData = stringContent.data(using: .utf8),
                  let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] else {
                throw NSError(domain: "Invalid JSON", code: 1001, userInfo: nil)
            }
            return try JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted)
        }

        // Convert YML file to json
        return try getJsonContentFromYmlContent(ymlContent: stringContent)
    }

    /// Extracts a layout object from a potentially wrapped JSON payload.
    ///
    /// Supports multiple wrapper formats by traversing known key paths:
    /// - `in_app_message.message.display.layout`
    /// - `message.display.layout`
    /// - `display.layout`
    /// - `layout`
    ///
    /// If the payload is already a raw layout (has version, presentation, view), returns it as-is.
    private func extractLayoutFromPayload(_ data: Data) throws -> Data {
        guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return data
        }

        if let layout = extractLayout(from: jsonObject) {
            return try JSONSerialization.data(withJSONObject: layout, options: .prettyPrinted)
        }

        return data
    }

    /// Traverses the JSON structure to find the layout object.
    private func extractLayout(from json: [String: Any]) -> [String: Any]? {
        // Check if this is already a valid layout
        if isValidLayout(json) {
            return json
        }

        // Define the possible key paths to the layout, from most to least nested
        let keyPaths: [[String]] = [
            ["in_app_message", "message", "display", "layout"],
            ["message", "display", "layout"],
            ["display", "layout"],
            ["layout"]
        ]

        for keyPath in keyPaths {
            if let layout = traverse(json: json, keyPath: keyPath), isValidLayout(layout) {
                return layout
            }
        }

        return nil
    }

    /// Traverses a JSON dictionary along a key path.
    private func traverse(json: [String: Any], keyPath: [String]) -> [String: Any]? {
        var current: [String: Any] = json
        for key in keyPath {
            guard let next = current[key] as? [String: Any] else {
                return nil
            }
            current = next
        }
        return current
    }

    /// Checks if a dictionary contains the required layout keys.
    private func isValidLayout(_ json: [String: Any]) -> Bool {
        json["version"] != nil && json["presentation"] != nil && json["view"] != nil
    }

    /// Check if a string is JSON
    func isJSONString(_ jsonString: String) -> Bool {
        if let jsonData = jsonString.data(using: .utf8) {
            do {
                _ = try JSONSerialization.jsonObject(with: jsonData, options: [])
                return true
            } catch {
                return false
            }
        }
        return false
    }

    /// Convert YML content to json content using Yams
    func getJsonContentFromYmlContent(ymlContent: String) throws -> Data {
        guard
            let jsonContentOfFile = try Yams.load(yaml: ymlContent) as? NSDictionary
        else {
            throw AirshipErrors.error("Invalid content: \(ymlContent)")
        }
        return try JSONSerialization.data(
            withJSONObject: jsonContentOfFile,
            options: .prettyPrinted
        )
    }

    // Returns the file contents
    private func getContentOfFile(filePath: String) throws -> String {
        return try String(contentsOfFile: filePath, encoding: String.Encoding.utf8)
    }


    @MainActor
    private func displayScene(_ data: Data, imageURLOverride: URL?) async throws {
        // Extract layout from potentially wrapped payload (in_app_message.message.display.layout)
        var layoutData = try extractLayoutFromPayload(data)
        if let imageURLOverride {
            layoutData = try Self.stubbingRemoteContent(in: layoutData, imageURL: imageURLOverride)
        } else {
            layoutData = try Self.resolvingTestLayoutURLs(in: layoutData)
        }
        let layout = try JSONDecoder().decode(AirshipLayout.self, from: layoutData)

        let message = InAppMessage(name: "thomas", displayContent: .airshipLayout(layout))
        try await Airship.inAppAutomation.viewTester.display(message: message)
    }

    /// Makes a scene render deterministically without the network, for UI test screenshots:
    ///   - image media, image buttons and every `url_selectors` entry point at `imageURL`
    ///   - video, YouTube and Vimeo media become image media showing `imageURL`, so the frame
    ///     never lands at a random playback phase (the player chrome itself is not exercised)
    ///   - web views load a small inline placeholder page instead of remote content
    ///   - pager `automated_actions` are dropped, so stories stay on their first page
    ///   - `randomize_children` is turned off, so option order is stable
    /// The generator in `uitests/tools/generate-flows.js` mirrors these rules when it decides
    /// what is capturable; keep the two in sync.
    private static func stubbingRemoteContent(in data: Data, imageURL: URL) throws -> Data {
        let webViewPlaceholder = "data:text/html," + "<html><body style=\"margin:0;background:#dbe6f7;font:24px -apple-system,sans-serif;color:#1a4099\"><div style=\"padding:24px\">web view placeholder</div></body></html>"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        // A `test-layout.internal` URL already renders deterministically at the aspect ratio the
        // scene asked for, so it's left alone rather than flattened to the one override image.
        func resolvedURL(_ original: String?) -> String {
            if let original, let resolved = TestLayoutPlaceholder.resolve(urlString: original) {
                return resolved.absoluteString
            }
            return imageURL.absoluteString
        }
        func rewrite(_ node: Any) -> Any {
            if var dict = node as? [String: Any] {
                let type = dict["type"] as? String
                if type == "media" {
                    let mediaType = dict["media_type"] as? String
                    if mediaType == "image" || mediaType == "video" || mediaType == "youtube" || mediaType == "vimeo" {
                        dict["media_type"] = "image"
                        dict["url"] = resolvedURL(dict["url"] as? String)
                        if let selectors = dict["url_selectors"] as? [[String: Any]] {
                            dict["url_selectors"] = selectors.map { selector in
                                var selector = selector
                                selector["url"] = resolvedURL(selector["url"] as? String)
                                return selector
                            }
                        }
                    }
                } else if type == "url" && dict["url"] is String {
                    dict["url"] = imageURL.absoluteString
                } else if type == "web_view" {
                    dict["url"] = webViewPlaceholder
                }
                dict["automated_actions"] = nil
                // Randomized child order is a different screenshot on every run.
                if dict["randomize_children"] as? Bool == true {
                    dict["randomize_children"] = false
                }
                for (key, value) in dict {
                    dict[key] = rewrite(value)
                }
                return dict
            }
            if let array = node as? [Any] {
                return array.map(rewrite)
            }
            return node
        }
        let json = try JSONSerialization.jsonObject(with: data)
        return try JSONSerialization.data(withJSONObject: rewrite(json))
    }

    /// Resolves any `test-layout.internal` media URL (see `TestLayoutPlaceholder`) to its
    /// synthesized image, leaving every other URL and field untouched. Runs on ordinary scene
    /// display, where `stubbingRemoteContent`'s blanket override doesn't apply.
    private static func resolvingTestLayoutURLs(in data: Data) throws -> Data {
        func rewrite(_ node: Any) -> Any {
            if var dict = node as? [String: Any] {
                if dict["type"] as? String == "media",
                   let mediaType = dict["media_type"] as? String,
                   mediaType == "image" || mediaType == "video" || mediaType == "youtube" || mediaType == "vimeo" {
                    if let url = dict["url"] as? String,
                       let resolved = TestLayoutPlaceholder.resolve(urlString: url) {
                        dict["url"] = resolved.absoluteString
                    }
                    if let selectors = dict["url_selectors"] as? [[String: Any]] {
                        dict["url_selectors"] = selectors.map { selector in
                            var selector = selector
                            if let url = selector["url"] as? String,
                               let resolved = TestLayoutPlaceholder.resolve(urlString: url) {
                                selector["url"] = resolved.absoluteString
                            }
                            return selector
                        }
                    }
                }
                for (key, value) in dict {
                    dict[key] = rewrite(value)
                }
                return dict
            }
            if let array = node as? [Any] {
                return array.map(rewrite)
            }
            return node
        }
        let json = try JSONSerialization.jsonObject(with: data)
        return try JSONSerialization.data(withJSONObject: rewrite(json))
    }

    @MainActor
    private func displayMessage(_ data: Data) async throws {
        let message: InAppMessage

        // Try to unwrap server-formatted JSON with in_app_message wrapper
        if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let inAppMessage = jsonObject["in_app_message"] as? [String: Any],
           let messageObject = inAppMessage["message"] as? [String: Any] {
            // Extract just the message object and decode it
            let messageData = try JSONSerialization.data(withJSONObject: messageObject)
            message = try JSONDecoder().decode(InAppMessage.self, from: messageData)
        } else {
            // Fall back to direct InAppMessage decoding (for legacy format)
            message = try JSONDecoder().decode(InAppMessage.self, from: data)
        }
        try await Airship.inAppAutomation.viewTester.display(message: message)
    }
}
