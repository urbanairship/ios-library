/* Copyright 2019 Urban Airship and Contributors */

import UIKit

class SearchFooter: UIView {

    let label: UILabel = UILabel()

    override public init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }

    func configureView() {
        alpha = 0.0
        label.textAlignment = .center
        label.textColor = UIColor.white
        addSubview(label)
    }

    override func draw(_ rect: CGRect) {
        label.frame = bounds
    }

    fileprivate func hideFooter() {
        UIView.animate(withDuration: 0.7) {[unowned self] in
            self.alpha = 0.0
        }
    }

    fileprivate func showFooter() {
        UIView.animate(withDuration: 0.7) {[unowned self] in
            self.alpha = 1.0
        }
    }
}

extension SearchFooter {
    public func setNotFiltering() {
        label.text = ""
        hideFooter()
    }

    public func setIsFilteringToShow(filteredItemCount: Int, of totalItemCount: Int) {
        if (filteredItemCount == totalItemCount) {
            setNotFiltering()
        } else if (filteredItemCount == 0) {
            label.text = "No items match your query"
            showFooter()
        } else {
            label.text = "Filtering \(filteredItemCount) of \(totalItemCount)"
            showFooter()
        }
    }

}
