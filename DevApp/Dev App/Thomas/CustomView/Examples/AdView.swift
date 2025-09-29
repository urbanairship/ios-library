///* Copyright Airship and Contributors */
//
//import SwiftUI
//import GoogleMobileAds
//
//struct AdView: UIViewControllerRepresentable {
//    var keywords: [String]?
//
//    @State private var viewWidth: CGFloat = UIScreen.main.bounds.width
//    @State private var isLoadingAd = true  // Track ad loading state
//    
//    let googleTestAdUnitID = "ca-app-pub-3940256099942544/2934735716"
//
//    func makeUIViewController(context: Context) -> UIViewController {
//        let bannerViewController = UIViewController()
//        let bannerView = GADBannerView(adSize: GADAdSizeFluid)
//        bannerView.adUnitID = googleTestAdUnitID
//        bannerView.rootViewController = bannerViewController
//        bannerView.delegate = context.coordinator
//        bannerView.translatesAutoresizingMaskIntoConstraints = false
//        bannerViewController.view.addSubview(bannerView)
//        bannerView.isAutoloadEnabled = true
//
//        let loadingIndicator = UIActivityIndicatorView(style: .large)
//        loadingIndicator.startAnimating()
//        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
//        bannerViewController.view.addSubview(loadingIndicator)
//
//        NSLayoutConstraint.activate([
//            loadingIndicator.centerXAnchor.constraint(equalTo: bannerViewController.view.centerXAnchor),
//            loadingIndicator.centerYAnchor.constraint(equalTo: bannerViewController.view.centerYAnchor)
//        ])
//
//        NSLayoutConstraint.activate([
//            bannerView.topAnchor.constraint(equalTo: bannerViewController.view.safeAreaLayoutGuide.topAnchor),
//            bannerView.leadingAnchor.constraint(equalTo: bannerViewController.view.safeAreaLayoutGuide.leadingAnchor),
//            bannerView.trailingAnchor.constraint(equalTo: bannerViewController.view.safeAreaLayoutGuide.trailingAnchor),
//            bannerView.bottomAnchor.constraint(equalTo: bannerViewController.view.safeAreaLayoutGuide.bottomAnchor)
//        ])
//
//        return bannerViewController
//    }
//
//    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
//        if let loadingIndicator = uiViewController.view.subviews.first(where: { $0 is UIActivityIndicatorView }) as? UIActivityIndicatorView {
//            loadingIndicator.isHidden = !isLoadingAd
//        }
//    }
//
//    func makeCoordinator() -> Coordinator {
//        Coordinator(self)
//    }
//
//    class Coordinator: NSObject, GADBannerViewDelegate {
//        var parent: AdView
//
//        init(_ parent: AdView) {
//            self.parent = parent
//        }
//
//        func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
//            print("Banner did receive ad")
//            // Update loading state
//            DispatchQueue.main.async {
//                self.parent.isLoadingAd = false
//            }
//        }
//
//        func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
//            print("Banner failed to receive ad with error: \(error.localizedDescription)")
//            // Update loading state
//            DispatchQueue.main.async {
//                self.parent.isLoadingAd = true
//            }
//        }
//    }
//}
