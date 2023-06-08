/* Copyright Airship and Contributors */

import AirshipCore
import SwiftUI
import WebKit

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
            }
            .alert(isPresented: $showError) {
                Alert(
                    title: Text("Error"),
                    message: Text(self.errorMessage ?? "error"),
                    dismissButton: .default(Text("OK"))
                )
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
        .onAppear {
            do {
                self.layoutsArray = try getLayoutsList()
            } catch {
                errorMessage = "Failed with error \(error)"
                showError = true
            }
        }
    }

    @MainActor
    func openLayout(_ fileName: String, metrics: GeometryProxy) {
        do {
            let data = try loadData(fileName: fileName)
            guard
                let scene = UIApplication.shared.connectedScenes.first(where: {
                    $0.isKind(of: UIWindowScene.self)
                }) as? UIWindowScene
            else {
                throw AirshipErrors.error("Unable to find a window!")
            }

            let extensions = ThomasExtensions(
                nativeBridgeExtension: ThomasNativeBridgeExtension()
            )
            try Thomas.display(
                data,
                scene: scene,
                extensions: extensions,
                delegate: self.delegate
            )
        } catch {
            errorMessage = "Failed with error \(error)"
            showError = true
        }
    }

    func loadData(fileName: String) throws -> Data {
        //Retrieve the YML content
        let ymlContent = try getContentOfFile(fileName: fileName)

        // Convert YML file to json
        return try getJsonContentFromYmlContent(ymlContent: ymlContent)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        LayoutsList()
    }
}

class Delegate: ThomasDelegate {
    
    func onRunActions(
        actions: [String: Any],
        layoutContext: AirshipCore.ThomasLayoutContext
    ) {
        print(
            "Thomas.onRunActions{actions=\(actions), context=\(layoutContext)}"
        )
        let permissionReceiver:
            (AirshipPermission, AirshipPermissionStatus, AirshipPermissionStatus) -> Void = {
                permission,
                start,
                end in
                print(
                    "Thomas.permissionResult{permission=\(permission), start=\(start), end=\(end), context=\(layoutContext)}"
                )
            }

        let metadata: [AnyHashable: Any] = [
            PromptPermissionAction.resultReceiverMetadataKey: permissionReceiver
        ]

        Task {
            let result = await ActionRunner.run(
                actionValues: actions,
                situation: .manualInvocation,
                metadata: metadata
            )
            AirshipLogger.trace(
                "Finishing running actions with result: \(result)"
            )
        }

    }

    func onFormSubmitted(
        formResult: ThomasFormResult,
        layoutContext: ThomasLayoutContext
    ) {
        print(
            "Thomas.onFormSubmitted{formResult=\(formResult), context=\(layoutContext)}"
        )
    }

    func onFormDisplayed(
        formInfo: ThomasFormInfo,
        layoutContext: ThomasLayoutContext
    ) {
        print(
            "Thomas.onFormDisplayed{formInfo=\(formInfo), context=\(layoutContext)}"
        )
    }

    func onDismissed(layoutContext: ThomasLayoutContext?) {
        print(
            "Thomas.onDismissed{context=\(String(describing: layoutContext))}"
        )
    }

    func onDismissed(
        buttonIdentifier: String,
        buttonDescription: String,
        cancel: Bool,
        layoutContext: ThomasLayoutContext
    ) {
        print(
            "Thomas.onDismissed{buttonIdentifier=\(buttonIdentifier), buttonDescription=\(buttonDescription), cancel=\(cancel), context=\(layoutContext)}"
        )
    }

    func onTimedOut(layoutContext: ThomasLayoutContext?) {
        print("Thomas.onTimedOut{context=\(String(describing: layoutContext))}")
    }

    func onPageViewed(
        pagerInfo: ThomasPagerInfo,
        layoutContext: ThomasLayoutContext
    ) {
        print(
            "Thomas.onPageViewed{pagerInfo=\(pagerInfo), context=\(layoutContext)}"
        )
    }
    
    func onButtonTapped(
        buttonIdentifier: String,
        metadata: Any?,
        layoutContext: AirshipCore.ThomasLayoutContext
    ) {
        print(
            "Thomas.onButtonTapped{buttonIdentifier=\(buttonIdentifier)\n, metadata=\(String(describing: metadata))\n, context=\(layoutContext)"
        )
    }
    
    func onPageGesture(
        identifier: String,
        metadata: Any?,
        layoutContext: AirshipCore.ThomasLayoutContext
    ) {
        print(
            "Thomas.onPageGesture{identifier=\(identifier)\n, metadata=\(String(describing: metadata))\n, layoutContext=\(layoutContext)}"
        )
    }
    
    
    func onPageAutomatedAction(
        identifier: String,
        metadata: Any?,
        layoutContext: AirshipCore.ThomasLayoutContext
    ) {
        print(
            "Thomas.onPageAutomatedAction{identifier=\(identifier)\n, metadata=\(String(describing: metadata))\n, layoutContext=\(layoutContext)}"
        )
    }
    
    func onPageSwiped(
        from: ThomasPagerInfo,
        to: ThomasPagerInfo,
        layoutContext: ThomasLayoutContext
    ) {
        print(
            "Thomas.onPageSwiped{from=\(from), to=\(to), context=\(layoutContext)}"
        )
    }
}

class ThomasNativeBridgeExtension: NSObject, NativeBridgeExtensionDelegate {
    
    func extendJavaScriptEnvironment(
        _ js: AirshipCore.JavaScriptEnvironmentProtocol,
        webView: WKWebView
    ) async {
        js.add("chooChoo", string: "chooooo choooooo!")
    }
    
    func actionsMetadata(
        for command: AirshipCore.JavaScriptCommand,
        webView: WKWebView
    ) -> [AnyHashable : Any] {
        return [ : ]
    }
    
}
