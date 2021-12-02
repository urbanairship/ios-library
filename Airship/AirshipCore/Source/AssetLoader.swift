/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Combine

@available(iOS 13.0.0, tvOS 13.0, *)
class AssetLoader: ObservableObject {
    let retries = 10
    var loaded: PassthroughSubject<UIImage?, Never> = PassthroughSubject()
    var image: UIImage? {
        didSet {
            loaded.send(image)
        }
    }

    func load(url: String) -> AnyCancellable? {
        let pub = URLSession.shared.dataTaskPublisher(for: URL(string: url)!)
            .retry(retries)
        var cancellable: AnyCancellable? = nil
        cancellable = pub
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { (completion) in
                        }) { (value) in
                            self.image = UIImage.fancyImage(with: value.data, fillIn: false)
                        }
        return cancellable
    }
}

