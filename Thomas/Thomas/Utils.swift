/* Copyright Airship and Contributors */

import AirshipCore
import Foundation
import Yams

let directoryName = "/Layouts"

// Returns the list of layouts file from Layouts folder
func getLayoutsList() throws -> [String] {
    let docsPath = Bundle.main.resourcePath! + directoryName
    return try FileManager.default.contentsOfDirectory(atPath: docsPath)
        .sorted()
}

// Returns the YML file contents
func getContentOfFile(fileName: String) throws -> String {
    let filePath = Bundle.main.resourcePath! + directoryName + "/" + fileName
    return try String(contentsOfFile: filePath, encoding: String.Encoding.utf8)
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
