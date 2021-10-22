/* Copyright Airship and Contributors */

import Foundation
import Yams

let directoryName = "/Layouts"

// Returns the list of layouts file from Layouts folder
func getLayoutsList() -> [String] {
    
    let docsPath = Bundle.main.resourcePath! + directoryName
    
    var layoutsList:[String] = [];
    do {
        let contentOfFile = try FileManager.default.contentsOfDirectory(atPath: docsPath)
        layoutsList = contentOfFile
    } catch {
        print("An error occurred while retrieving the list of YAML files", error);
    }
    return layoutsList;
}

// Returns the YML file contents
func getContentOfFile(fileName:String) -> String {
    
    let filePath = Bundle.main.resourcePath! + directoryName + "/" + fileName
    
    var content:String = "";
    do {
        let contentOfFile = try String(contentsOfFile: filePath, encoding: String.Encoding.utf8)
        content = contentOfFile;
    } catch {
        print("An error occurred while retrieving the content of the YAML file", error);
    }
    return content;
}

//Convert YML content to json content using Yams
func getJsonContentFromYmlContent(ymlContent:String) -> Data! {
    
    var jsonContent:Data?;
    
    do {
        let jsonContentOfFile = try Yams.load(yaml:ymlContent) as? NSDictionary;
        if (jsonContentOfFile != nil) {
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: jsonContentOfFile!, options: .prettyPrinted) ;
                jsonContent = jsonData;
            } catch {
                print(error.localizedDescription)
            }
        }
    } catch {
        print(error);
    }
    return jsonContent;
}
