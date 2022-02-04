/* Copyright Airship and Contributors */

import UIKit
import QuartzCore

#if canImport(AirshipCore)
import AirshipCore
#endif

@objc(UAPreferenceCenterCheckboxCell)
open class PreferenceCenterCheckboxCell: UITableViewCell {
    var callback : ((Bool, [ChannelScope])->())?
    var activeScopes : [ChannelScope] = []
    var contentStackView = UIStackView()
    var contentWidth = 0.0
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        contentWidth = contentView.frame.size.width
    }

    func draw(item : ContactSubscriptionGroupItem, style: PreferenceCenterStyle?) {
        clear()
        
        let spacing = 5
        
        let cellStackView = UIStackView()
        cellStackView.axis = .vertical
        cellStackView.distribution = .fill
        cellStackView.alignment = .fill
        cellStackView.spacing = CGFloat(spacing * 2)
        cellStackView.translatesAutoresizingMaskIntoConstraints = false
        
        let count = item.components.count
        var stackViewArray: [UIStackView] = []
       
        let rowStackView = UIStackView()
        rowStackView.axis = .horizontal
        rowStackView.distribution = .fill
        rowStackView.alignment = .fill
        rowStackView.spacing = CGFloat(spacing * 3)
        rowStackView.translatesAutoresizingMaskIntoConstraints = false
        stackViewArray.append(rowStackView)
        
        var contentSize = spacing * 2

        for i in 0...count-1 {
            
            let checkBox = PreferenceCenterCheckBox()
            checkBox.callback = callback
            let checkBoxLabel = UILabel()

            let component = item.components[i]
            checkBoxLabel.text = component.display.title
            checkBoxLabel.font = style?.preferenceTextFont
            let itemSize = (Int(checkBoxLabel.intrinsicContentSize.width) + Int(checkBox.intrinsicContentSize.width) + spacing * 4)
            contentSize += itemSize
                
            let scopes = component.scopes.values.reduce(into: []) { list, scope in
                list.append(scope)
            }
                
            if scopes.allSatisfy(activeScopes.contains) {
                checkBox.isChecked = true
            } else {
                checkBox.isChecked = false
            }
                
            checkBox.scopes = scopes

            let stackView = UIStackView(arrangedSubviews: [checkBox, checkBoxLabel])
            stackView.axis = .horizontal
            stackView.distribution = .fill
            stackView.alignment = .fill
            stackView.layer.cornerRadius = 18
            stackView.spacing = CGFloat(spacing)
            if #available(iOS 13.0, *) {
                stackView.layer.borderColor = UIColor.opaqueSeparator.cgColor
            } else {
                stackView.layer.borderColor = UIColor.black.cgColor
            }
            stackView.layer.borderWidth = 1
            stackView.layer.masksToBounds = true
            stackView.isLayoutMarginsRelativeArrangement = true
            stackView.directionalLayoutMargins = NSDirectionalEdgeInsets(top: CGFloat(spacing), leading: CGFloat(spacing * 2), bottom: CGFloat(spacing), trailing: CGFloat(spacing * 2))

            if (contentSize >= Int(contentWidth)) {
                let rowStackView = UIStackView()
                rowStackView.axis = .horizontal
                rowStackView.distribution = .fill
                rowStackView.alignment = .fill
                rowStackView.spacing = CGFloat(spacing * 3)
                rowStackView.translatesAutoresizingMaskIntoConstraints = false
                stackViewArray.append(rowStackView)
                contentSize = itemSize + (spacing * 2)
            }
                       
            let currentStackView = stackViewArray.last
            if let currentStackView = currentStackView {
                currentStackView.addArrangedSubview(stackView)
            }
        }

        for stackView in stackViewArray {
            let view = UIView(frame: contentView.frame)
            view.addSubview(stackView)

            stackView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
            stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
             
            cellStackView.addArrangedSubview(view)
        }
        
        let titleLabel = UILabel()
        let subtitleLabel = UILabel()

        titleLabel.text = item.display?.title
        subtitleLabel.text = item.display?.subtitle

        if (style?.preferenceTextFont != nil) {
            titleLabel.font = style?.preferenceTextFont
            subtitleLabel.font = style?.preferenceTextFont
        }
        if (style?.preferenceTextColor != nil) {
            titleLabel.textColor = style?.preferenceTextColor
            subtitleLabel.textColor = style?.preferenceTextColor
        }

        if (item.display?.subtitle != nil && item.display?.subtitle != "") {
            contentStackView = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, cellStackView])
        } else {
            contentStackView = UIStackView(arrangedSubviews: [titleLabel, cellStackView])
        }
        contentStackView.axis = .vertical
        contentStackView.distribution = .fill
        contentStackView.alignment = .fill
        contentStackView.spacing = CGFloat(spacing)
        contentStackView.isLayoutMarginsRelativeArrangement = true
        contentStackView.directionalLayoutMargins = NSDirectionalEdgeInsets(top: CGFloat(spacing), leading: CGFloat(spacing) * 3, bottom: CGFloat(spacing) * 3, trailing: CGFloat(spacing))

        contentStackView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(contentStackView)

        contentStackView.topAnchor.constraint(equalTo: contentView.topAnchor).isActive = true
        contentStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor).isActive = true
        contentStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor).isActive = true
        contentStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor).isActive = true

        self.selectionStyle = .none
    }

    func clear() {
        contentStackView.removeFromSuperview()
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
