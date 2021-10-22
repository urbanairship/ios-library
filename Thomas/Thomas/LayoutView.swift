/* Copyright Airship and Contributors */

import SwiftUI
import AirshipCore

struct LayoutView: UIViewControllerRepresentable {
    typealias UIViewControllerType = UIViewController
    let fileName: String
    func makeUIViewController(context: UIViewControllerRepresentableContext<LayoutView>) -> UIViewController {
        //Retrieve the YML content
        let ymlContent = getContentOfFile(fileName: fileName)
        //Convert YML file to json
        let jsonContent = getJsonContentFromYmlContent(ymlContent:ymlContent)
        if (jsonContent != nil) {
            do {
                return try Thomas.viewController(payload: jsonContent!);
            } catch {
                print("An error occurred while displaying the view controller", error);
            }
        }
        return UIViewController();
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: UIViewControllerRepresentableContext<LayoutView>) {
    }
}

