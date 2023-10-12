/* Copyright Airship and Contributors */

import AirshipCore
import Foundation
import Yams
import WebKit

final class Layouts {
    public static let shared: Layouts = Layouts()
    
    private let delegate = Delegate()
    let layouts: [LayoutFile] = Layouts.getLayoutsList(directory: "/Modal", type: .modal) +
    Layouts.getLayoutsList(directory: "/Banner", type: .banner) +
    Layouts.getLayoutsList(directory: "/Embedded", type: .embedded)


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


    // Returns the YML file contents
    private func getContentOfFile(filePath: String) throws -> String {
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


    @MainActor
    public func openLayout(_ layout: LayoutFile) throws {
        let data = try loadData(filePath: layout.filePath)

        let extensions = ThomasExtensions(
            nativeBridgeExtension: ThomasNativeBridgeExtension()
        )
        try Thomas.display(
            data,
            scene: {
                return UIApplication.shared.connectedScenes.first(where: {
                    $0.isKind(of: UIWindowScene.self)
                }) as? UIWindowScene
            },
            extensions: extensions,
            delegate: self.delegate
        )
    }

    private func loadData(filePath: String) throws -> Data {
        //Retrieve the YML content
        let ymlContent = try getContentOfFile(filePath: filePath)

        // Convert YML file to json
        return try getJsonContentFromYmlContent(ymlContent: ymlContent)
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

        let metadata: [String: Sendable] = [
            PromptPermissionAction.resultReceiverMetadataKey: permissionReceiver
        ]


        Task {
            let result = await ActionRunner.run(
                actionsPayload: try AirshipJSON.wrap(actions),
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

    func onPromptPermissionResult(
        permission: AirshipCore.AirshipPermission,
        startingStatus: AirshipCore.AirshipPermissionStatus,
        endingStatus: AirshipCore.AirshipPermissionStatus,
        layoutContext: AirshipCore.ThomasLayoutContext
    ) {
        print(
            "Thomas.onPromptPermissionResult{permission=\(startingStatus), startingStatus=\(startingStatus), endingStatus=\(endingStatus), layoutContext=\(layoutContext)}"
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
    ) -> [String : String] {
        return [ : ]
    }
}


struct LayoutFile: Equatable, Hashable {
    let filePath: String
    let fileName: String
    let type: LayoutType
}


enum LayoutType: Equatable, Hashable {
    case modal
    case banner
    case embedded
}
