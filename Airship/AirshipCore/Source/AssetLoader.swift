/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Combine

@available(iOS 13.0.0, tvOS 13.0, *)
class AssetLoader: ObservableObject {
    let retries = 10
    var loaded: PassthroughSubject<Data, Never> = PassthroughSubject()
    var data = Data() {
        didSet {
            loaded.send(data)
        }
    }

    func load(url: String) -> AnyCancellable? {
        let pub = URLSession.shared.dataTaskPublisher(for: URL(string: url)!)
            .retry(retries)
        var cancellable: AnyCancellable? = nil
        cancellable = pub
            .sink(receiveCompletion: { (completion) in
                        }) { (value) in
                            self.data = value.data
                        }
        return cancellable
    }
}

