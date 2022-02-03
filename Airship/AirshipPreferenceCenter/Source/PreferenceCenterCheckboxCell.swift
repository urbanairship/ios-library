import UIKit
import QuartzCore

@objc(UAPreferenceCenterCheckboxCell)
open class PreferenceCenterCheckboxCell: UITableViewCell {
    var callback : ((Bool, [String])->())?
    var activeScopes : [String] = []
    var contentStackView = UIStackView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)

    }

    func draw(item : ContactSubscriptionGroupItem, style: PreferenceCenterStyle?) {
        clear()
        
        let checkBoxWidgetView = UIView(frame: contentView.frame)

        let cellStackView = UIStackView()
        cellStackView.axis = .horizontal
        cellStackView.distribution = .fill
        cellStackView.alignment = .fill
        cellStackView.spacing = 8
        cellStackView.translatesAutoresizingMaskIntoConstraints = false
        
        let count = item.components.count

        for i in 0...count-1 {
          
            let checkBox = PreferenceCenterCheckBox()
            checkBox.callback = callback
            let checkBoxLabel = UILabel()

            let component = item.components[i]
            checkBoxLabel.text = component.display.title
            checkBoxLabel.font = style?.preferenceTextFont
                
            let scopes = component.scopes.values.reduce(into: []) { list, scope in
                list.append(scope.stringValue)
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
            stackView.spacing = 5
            if #available(iOS 13.0, *) {
                stackView.layer.borderColor = UIColor.opaqueSeparator.cgColor
            } else {
                stackView.layer.borderColor = UIColor.black.cgColor
            }
            stackView.layer.borderWidth = 1
            stackView.layer.masksToBounds = true
            stackView.isLayoutMarginsRelativeArrangement = true
            stackView.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 5, leading: 7.5, bottom: 5, trailing: 7.5)

            cellStackView.addArrangedSubview(stackView)
        }

        checkBoxWidgetView.addSubview(cellStackView)
        
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
            contentStackView = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, checkBoxWidgetView])
        } else {
            contentStackView = UIStackView(arrangedSubviews: [titleLabel, checkBoxWidgetView])
        }
        contentStackView.axis = .vertical
        contentStackView.distribution = .fillEqually
        contentStackView.alignment = .fill
        contentStackView.spacing = 5
        contentStackView.isLayoutMarginsRelativeArrangement = true
        contentStackView.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 5, leading: 15, bottom: 30, trailing: 0)

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
