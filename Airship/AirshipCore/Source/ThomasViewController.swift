//
//  ThomasViewController.swift
//  Airship
//
//  Created by Ryan Lepinski on 11/11/21.
//  Copyright © 2021 Urban Airship. All rights reserved.
//

import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
class ThomasViewController : UIHostingController<RootView> {
    
    var onDismiss: (() -> Void)?
    var autoResizeFrame = false
    
    override init(rootView: RootView) {
        super.init(rootView: rootView)
        self.view.backgroundColor = .clear
        self.modalPresentationStyle = .overCurrentContext
    }
    
    @objc
    required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        self.onDismiss?()
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateSize()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        updateSize()
    }
    
    private func updateSize() {
        if autoResizeFrame, let superView = self.view.superview {
            self.view.bounds = superView.bounds
            self.view.frame = superView.frame
        }
    }
}
    
