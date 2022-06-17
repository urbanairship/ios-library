/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@available(iOS 13.0, *)
class ContactViewController: UIViewController {
    let contentView = UIHostingController(rootView: ContactList())
    
    var launchPathComponents : [String]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(contentView)
        view.addSubview(contentView.view)
        setupConstraints()
    }
    
    fileprivate func setupConstraints() {
        contentView.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentView.view.topAnchor.constraint(equalTo: view.topAnchor),
            contentView.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentView.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentView.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
}

