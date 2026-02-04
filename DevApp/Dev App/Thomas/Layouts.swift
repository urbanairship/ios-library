/* Copyright Airship and Contributors */

import AirshipCore
import Foundation
internal import Yams
import AirshipAutomation

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
    @MainActor
    func open() throws {
        let filePath = Bundle.main.resourcePath! + directory + "/" + fileName
        let data = try loadData(filePath: filePath)

        switch self.type {
        case .sceneModal, .sceneBanner, .sceneEmbedded:
            try displayScene(data)
        case .messageModal, .messageBanner, .messageFullscreen, .messageHTML:
            try displayMessage(data)
        }
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
    private func displayScene(_ data: Data) throws {
        // Extract layout from potentially wrapped payload (in_app_message.message.display.layout)
        let layoutData = try extractLayoutFromPayload(data)
        let layout = try JSONDecoder().decode(AirshipLayout.self, from: layoutData)

        let message = InAppMessage(name: "thomas", displayContent: .airshipLayout(layout))

        Task { @MainActor in
            try await message._display()
        }
    }

    @MainActor
    private func displayMessage(_ data: Data) throws {
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

        Task { @MainActor in
            try await message._display()
        }
    }
}
