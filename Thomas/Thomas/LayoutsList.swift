/* Copyright Airship and Contributors */

import SwiftUI
import AirshipCore

struct LayoutsList: View {
    
    // Retrieve the list of layouts template names from the 'Layouts' folder
    @State var layoutsArray: [String] = []
    @State var errorMessage: String?
    @State var showError: Bool = false
    
    let delegate = Delegate()

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
            }.alert(isPresented: $showError) {
                Alert(title: Text("Error"), message: Text(self.errorMessage ?? "error"), dismissButton: .default(Text("OK")))
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }.onAppear {
            do {
                self.layoutsArray = try getLayoutsList()
            } catch {
                errorMessage = "Failed with error \(error)"
                showError = true
            }
        }
    }
    
    func openLayout(_ fileName: String, metrics: GeometryProxy) {
        do {
            let data = try loadData(fileName: fileName)
            guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.isKind(of: UIWindowScene.self) }) as? UIWindowScene else {
                throw AirshipErrors.error("Unable to find a window!")
            }

            let extensions = ThomasExtensions(nativeBridgeExtension: ThomasNativeBridgeExtension())
            try Thomas.display(data,
                               scene: scene,
                               extensions: extensions,
                               delegate: self.delegate)
        } catch {
            errorMessage = "Failed with error \(error)"
            showError = true
        }
    }
    
    func loadData(fileName: String) throws -> Data {
        //Retrieve the YML content
        let ymlContent = try getContentOfFile(fileName: fileName)
        
        // Convert YML file to json
        return try getJsonContentFromYmlContent(ymlContent:ymlContent)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        LayoutsList()
    }
}

class Delegate : ThomasDelegate {
    func onFormSubmitted(formResult: ThomasFormResult, layoutContext: ThomasLayoutContext) {
        print("result: \(formResult.formData)")
    }
    
    func onFormDisplayed(formInfo: ThomasFormInfo, layoutContext: ThomasLayoutContext) {
        
    }
    
    func onButtonTapped(buttonIdentifier: String, layoutContext: ThomasLayoutContext) {
        
    }
    
    func onDismissed(layoutContext: ThomasLayoutContext?) {
        
    }
    
    func onDismissed(buttonIdentifier: String, buttonDescription: String, cancel: Bool, layoutContext: ThomasLayoutContext) {
    
    }
    
    func onTimedOut(layoutContext: ThomasLayoutContext?) {
    
    }
    
    func onPageViewed(pagerInfo: ThomasPagerInfo, layoutContext: ThomasLayoutContext) {
    
    }
    
    func onPageSwiped(from: ThomasPagerInfo, to: ThomasPagerInfo, layoutContext: ThomasLayoutContext) {
    }
    
    
}

class ThomasNativeBridgeExtension : NSObject, NativeBridgeExtensionDelegate  {
    func extendJavaScriptEnvironment(_ js: JavaScriptEnvironmentProtocol, webView: WKWebView) {
        js.add("chooChoo", string: "chooooo choooooo!")
    }
}



