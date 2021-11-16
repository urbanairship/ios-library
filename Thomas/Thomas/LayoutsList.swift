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

            try Thomas.display(data, scene: scene, delegate: self.delegate)
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
    
    func onDismiss(buttonIdentifier: String?, cancel: Bool) {
        AirshipLogger.info("onDismiss: \(buttonIdentifier ?? "") \(cancel)")
    }
    
    func onTimedOut() {
        AirshipLogger.info("onTimedOut")
    }
}

