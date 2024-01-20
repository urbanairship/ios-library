/* Copyright Airship and Contributors */

import AirshipCore
import Foundation
import Yams
import WebKit
import AirshipAutomationSwift
import AirshipAutomation

final class Layouts {
    public static let shared: Layouts = Layouts()

    let layouts: [LayoutFile] = Layouts.getLayoutsList(directory: "/Scenes/Modal", type: .sceneModal) +
    Layouts.getLayoutsList(directory: "/Scenes/Banner", type: .sceneBanner) +
    Layouts.getLayoutsList(directory: "/Scenes/Embedded", type: .sceneEmbedded) +
    Layouts.getLayoutsList(directory: "/Messages/Modal", type: .messageModal) +
    Layouts.getLayoutsList(directory: "/Messages/Banner", type: .messageBanner) +
    Layouts.getLayoutsList(directory: "/Messages/Fullscreen", type: .messageFullscreen) +
    Layouts.getLayoutsList(directory: "/Messages/HTML", type: .messageHTML)

    private static func getLayoutsList(directory: String, type: LayoutType) -> [LayoutFile] {
        let path = Bundle.main.resourcePath! + directory
        do {
            return try FileManager.default.contentsOfDirectory(atPath: path).sorted().map { fileName in
                LayoutFile(filePath:  "\(path)/\(fileName)", fileName: fileName, type: type)
            }
        } catch {
            return []
        }
    }

    // Returns the file contents
    private func getContentOfFile(filePath: String) throws -> String {
        return try String(contentsOfFile: filePath, encoding: String.Encoding.utf8)
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

    @MainActor
    private func displayScene(_ data: Data) throws {
        /// TODO clean this up to be a message?
        let layout = try JSONDecoder().decode(AirshipLayout.self, from: data)

        let message = InAppMessage(name: "thomas", displayContent: .airshipLayout(layout))
        let scene = try SceneManager.shared.lastActiveScene

        Task { @MainActor in
            try await message.display(scene: scene)
        }
    }

    @MainActor
    private func displayMessage(_ data: Data) throws {
        let message = try JSONDecoder().decode(InAppMessage.self, from: data)
        let scene = try SceneManager.shared.lastActiveScene

        Task { @MainActor in
            try await message.display(scene: scene)
        }
    }

    @MainActor
    private func displayLegacyMessage(_ data: Data) throws {
        if let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any], let legacyInAppMessage = try? AirshipAutomation.InAppMessage.init(json: jsonObject) {

            let schedule = InAppMessageSchedule(message: legacyInAppMessage) { builder in
                builder.triggers = [ScheduleTrigger.activeSessionTrigger(withCount: 1)]
                builder.identifier = "legacy-in-app-message"
                builder.delay = ScheduleDelay(builderBlock: { builder in
                    builder.seconds = 0
                })
                builder.limit = 1
            }

            InAppAutomation.shared.cancelSchedule(withID: schedule.identifier)

            InAppAutomation.shared.schedule(schedule) { success in
                print("Schedule attempt \(success ? "succeeded ✅" : "failed 🚨")")
            }
        } else {
            print("Schedule attempt failed 🚨")
        }
    }

    @MainActor
    public func openLayout(_ layout: LayoutFile, useLegacyDisplay:Bool? = nil) throws {
        let data = try loadData(filePath: layout.filePath)

        switch layout.type {
        case .sceneModal, .sceneBanner, .sceneEmbedded:
            try displayScene(data)
        case .messageModal, .messageBanner, .messageFullscreen, .messageHTML:
            if useLegacyDisplay == true {
                try displayLegacyMessage(data)
            } else {
                try displayMessage(data)
            }
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
}


struct LayoutFile: Equatable, Hashable {
    let filePath: String
    let fileName: String
    let type: LayoutType
}

enum LayoutType: Equatable, Hashable {
    case sceneModal
    case sceneBanner
    case sceneEmbedded
    case messageModal
    case messageBanner
    case messageFullscreen
    case messageHTML
}
