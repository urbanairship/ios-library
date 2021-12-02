/* Copyright Airship and Contributors */

#if !os(tvOS)

import Foundation
import SwiftUI
import Combine
import WebKit

@available(iOS 13.0.0, *)
class WebViewState: ObservableObject {
    var isLoading = PassthroughSubject<Bool, Never>()
}

/// Airship Webview
@available(iOS 13.0.0, *)
struct AirshipWebView : View {

    let model: WebViewModel

    let constraints: ViewConstraints
    
    @ObservedObject var webViewState = WebViewState()
    @State var isLoading = false
   
    var body: some View {
        ZStack {
            WebViewView(request: URLRequest(url: URL(string: model.url)!), webViewState: webViewState)
                .constraints(constraints)
                .onReceive(self.webViewState.isLoading.receive(on: RunLoop.main)) { value in
                    self.isLoading = value
                }
            if (self.isLoading) {
                if #available(iOS 14.0.0,  *) {
                    ProgressView()
                } else {
                    Loader(isAnimating: true)
                }
            }
        }        
    }
}

/// Webview
@available(iOS 13.0.0, *)
struct WebViewView : UIViewRepresentable {
    
    typealias UIViewType = WKWebView
    
    let request: URLRequest
    
    @ObservedObject var webViewState: WebViewState
    
    func makeUIView(context: Context) -> WKWebView  {
        let webView = WKWebView()
        context.coordinator.webView = webView
        webView.navigationDelegate = context.coordinator
        return webView
    }
        
    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.load(request)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator : NSObject, WKNavigationDelegate {
           
        var webViewView: WebViewView
        var webView : WKWebView?
            
        init(_ uiWebView: WebViewView) {
            self.webViewView = uiWebView
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            self.webViewView.webViewState.isLoading.send(false)
        }
                
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            self.webViewView.webViewState.isLoading.send(false)
        }
                
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            self.webViewView.webViewState.isLoading.send(false)
            self.webView!.reload()
        }
                
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            self.webViewView.webViewState.isLoading.send(true)
        }
    }

}

/// Loader
@available(iOS 13.0.0, *)
struct Loader: UIViewRepresentable {
    
    typealias UIView = UIActivityIndicatorView
    var isAnimating: Bool
 
    fileprivate var configuration = { (indicator: UIView) in }

    func makeUIView(context: UIViewRepresentableContext<Self>) -> UIView { UIView() }
 
    func updateUIView(_ uiView: UIView, context: UIViewRepresentableContext<Self>) {
        isAnimating ? uiView.startAnimating() : uiView.stopAnimating()
        configuration(uiView)
    }
}

#endif
