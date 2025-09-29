#if !os(visionOS)
/* Copyright Airship and Contributors */

import SwiftUI
import AVFoundation

struct CameraView : UIViewControllerRepresentable {
    func makeUIViewController(context: UIViewControllerRepresentableContext<CameraView>) -> UIViewController {
        let controller = CameraViewController()
        return controller
    }
    func updateUIViewController(_ uiViewController: CameraView.UIViewControllerType, context: UIViewControllerRepresentableContext<CameraView>) {}
}

class CameraViewController : UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        loadCamera()
    }

    func loadCamera() {
        let avSession = AVCaptureSession()

        guard let captureDevice = AVCaptureDevice.default(for: .video) else { return }
        guard let input = try? AVCaptureDeviceInput(device : captureDevice) else { return }
        avSession.addInput(input)
        avSession.startRunning()

        let cameraPreview = AVCaptureVideoPreviewLayer(session: avSession)
        view.layer.addSublayer(cameraPreview)
        cameraPreview.frame = view.frame
        cameraPreview.videoGravity = .resizeAspectFill
    }
}
#endif
