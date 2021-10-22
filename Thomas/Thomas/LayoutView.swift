/* Copyright Airship and Contributors */

import SwiftUI
import AirshipCore

struct LayoutView: UIViewControllerRepresentable {
    
    
    typealias UIViewControllerType = UIViewController
    let fileName: String
    func makeUIViewController(context: UIViewControllerRepresentableContext<LayoutView>) -> UIViewController {
        do {
            //Retrieve the YML content
            let ymlContent = try getContentOfFile(fileName: fileName)
            
            //Convert YML file to json
            let jsonContent = try getJsonContentFromYmlContent(ymlContent:ymlContent)
            
            // Create view controller
            return try Thomas.viewController(payload: jsonContent);
        } catch {
            return UIAlertController(title: "Error loading view", message: "Error: \(error)", preferredStyle: .alert)
        }
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
    }
}

