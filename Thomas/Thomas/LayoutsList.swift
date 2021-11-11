/* Copyright Airship and Contributors */

import SwiftUI
import AirshipCore

struct LayoutsList: View {
    
    //Retrieve the list of layouts template names from the 'Layouts' folder
    let layoutsArray: [String] = (try? getLayoutsList()) ?? []
    
    @State
    private var window : UIWindow?
    
    @State
    private var previousWindow: UIWindow?
    
    var body: some View {
        GeometryReader { metrics in
            NavigationView {
                List {
                    ForEach(layoutsArray, id: \.self) { layoutFileName in
                        Button(layoutFileName) {
                            openLayout(layoutFileName, metrics: metrics)
                        }
                    }
                }
                .navigationTitle("Airship Layouts")
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }
    
    func dismissLayout() {
        self.window?.rootViewController?.dismiss(animated: false) {
            self.window?.windowLevel = .normal
            self.window = nil
            self.previousWindow?.makeKeyAndVisible()
            self.previousWindow = nil
        }
    }
    
    func openLayout(_ fileName: String, metrics: GeometryProxy) {
        let scene = UIApplication.shared.connectedScenes.first(where: { $0.isKind(of: UIWindowScene.self) }) as? UIWindowScene
        
        if let scene = scene  {
            self.previousWindow = scene.windows.first(where: { $0.isKeyWindow })
            let window = UIWindow(windowScene: scene)
            window.windowLevel = .alert
            window.rootViewController = crateViewController(fileName: fileName)
            window.makeKeyAndVisible()
            self.window = window
        }
    }
    
    func crateViewController(fileName: String) -> UIViewController {
        do {
            //Retrieve the YML content
            let ymlContent = try getContentOfFile(fileName: fileName)
            
            //Convert YML file to json
            let jsonContent = try getJsonContentFromYmlContent(ymlContent:ymlContent)
            
            // Create view controller
            return try Thomas.viewController(payload: jsonContent, eventHandler: Eventhandler {
                dismissLayout()
            })
        } catch {
            return UIAlertController(title: "Error loading view", message: "Error: \(error)", preferredStyle: .alert)
        }
    }
}

class Eventhandler: ThomasEventHandler {
    let dismiss: () -> Void
    
    init(onDismiss: @escaping () -> Void) {
        self.dismiss = onDismiss
    }
    
    func onPageView(pagerIdentifier: String, pageIndex: Int, pageCount: Int) {
        AirshipLogger.info("onPageView: \(pagerIdentifier) index: \(pageIndex) count: \(pageCount)")
    }
    
    func onFormResult(formIdentifier: String, formData: [String : Any]) {
        let json = try? JSONUtils.string(formData, options: .prettyPrinted)
        AirshipLogger.info("onFormResult: \(formIdentifier): \(json ?? "")")
    }
    
    func onButtonTap(buttonIdentifier: String) {
        AirshipLogger.info("onButtonTap: \(buttonIdentifier)")
    }
    
    func onRunActions(actions: [String : Any]) {
        AirshipLogger.info("onRunActions: \(actions)")
    }
    
    func onDismiss(buttonIdentifier: String) {
        AirshipLogger.info("onDismiss: \(buttonIdentifier)")
        dismiss()
    }
    
    func onDismiss() {
        AirshipLogger.info("onDismiss")
        dismiss()
    }
    
    func onCancel(buttonIdentifier: String) {
        AirshipLogger.info("onCancel: \(buttonIdentifier)")
        dismiss()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        LayoutsList()
    }
}

