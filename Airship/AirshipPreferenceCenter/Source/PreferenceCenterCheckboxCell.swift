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

    private var isDarkMode: Bool {
        var isDarkMode = false
        if #available(iOS 12.0, *) {
            isDarkMode = self.traitCollection.userInterfaceStyle == .dark
        }
        return isDarkMode
    }
    
    private var defaultBorderColor: UIColor {
        if #available(iOS 13.0, *) {
            return UIColor.separator
        } else {
            return .systemGray
        }
    }
    
    private static let imageSize = 24.0
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
    }
    

    func draw(item : ContactSubscriptionGroupItem, style: PreferenceCenterStyle?) {
        clear()
        
        let borderColor = style?.preferenceChipBorderColor ?? self.defaultBorderColor
        let defaultFillColor = isDarkMode ? UIColor.black : UIColor.white
        let fillColor = style?.preferenceChipCheckmarkBackgroundColor ?? defaultFillColor
        let checkedFillColor = style?.preferenceChipCheckmarkCheckedBackgroundColor ?? .systemBlue
        let checkMarkColor = style?.preferenceChipCheckmarkColor ?? .white

        let uncheckedImage = PreferenceCenterCheckboxCell.uncheckedImage(border: borderColor,
                                                                         fill: fillColor)

        let checkedImage = PreferenceCenterCheckboxCell.checkedImage(border: borderColor,
                                                                     fill: checkedFillColor,
                                                                     checkMarkColor: checkMarkColor)
        
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
            
            let scopes = item.components[i].scopes.values
            let checkbox = PreferenceCenterCheckbox(component: item.components[i],
                                                    checkedImage: checkedImage,
                                                    uncheckedImage: uncheckedImage) { checked in
                self.callback?(checked, scopes)
            }
        
            applyStyle(style, button: checkbox)
            let itemSize = Int(checkbox.intrinsicContentSize.width)
            contentSize += itemSize
            if scopes.allSatisfy(activeScopes.contains) {
                checkbox.isChecked = true
            } else {
                checkbox.isChecked = false
            }

            if (contentSize >= Int(self.frame.width)) {
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
                currentStackView.addArrangedSubview(checkbox)
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
        
        if let font = style?.preferenceTitleTextFont ?? style?.preferenceTextFont {
            titleLabel.font = font
        }
        
        if let fontColor = style?.preferenceTitleTextColor ?? style?.preferenceTextColor {
            titleLabel.textColor = fontColor
        }
        
        if let font = style?.preferenceSubtitleTextFont ?? style?.preferenceTextFont {
            subtitleLabel.font = font
        }
        
        if let fontColor = style?.preferenceSubtitleTextColor ?? style?.preferenceTextColor {
            subtitleLabel.textColor = fontColor
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
    
    private class func uncheckedImage(border: UIColor,
                                      fill: UIColor) -> UIImage {
        
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: imageSize, height: imageSize))
        return renderer.image { ctx in
            drawCircle(context: ctx, border: border, fill: fill)
        }
    }
    
    private func applyStyle(_ style: PreferenceCenterStyle?, button: UIButton) {
        button.titleLabel?.font = style?.preferenceChipTextFont ?? style?.preferenceTextFont ?? .systemFont(ofSize: 12)
        
        button.backgroundColor = isDarkMode ? ColorUtils.color("#333333") : ColorUtils.color("#f3f3f3")
        button.layer.borderColor = style?.preferenceChipBorderColor?.cgColor ?? self.defaultBorderColor.cgColor
        
        if #available(iOS 13.0, *) {
            let color = style?.preferenceChipTextColor ?? style?.preferenceTextColor ?? UIColor.label
            button.setTitleColor(color, for: .normal)
        } else {
            let defaultFontColor = isDarkMode ? UIColor.white : UIColor.black
            let color = style?.preferenceChipTextColor ?? style?.preferenceTextColor ?? defaultFontColor
            button.setTitleColor(color, for: .normal)
        }
    }
    
    private class func checkedImage(border: UIColor,
                                    fill: UIColor,
                                    checkMarkColor: UIColor) -> UIImage {
        
        let size = CGSize(width: imageSize, height: imageSize)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            drawCircle(context: ctx, border: border, fill: fill)
            
            ctx.cgContext.setStrokeColor(checkMarkColor.cgColor)
            let bezierPath = UIBezierPath()
            bezierPath.move(to: CGPoint(x: 0.2857 * imageSize, y: 0.5714 * imageSize))
            bezierPath.addLine(to: CGPoint(x: 0.4000 * imageSize, y: 0.6857 * imageSize))
            bezierPath.addLine(to: CGPoint(x: 0.6715 * imageSize, y: 0.3142 * imageSize))
            bezierPath.lineWidth = 2
            bezierPath.lineCapStyle = CGLineCap.round
            bezierPath.stroke()
        }
    }
    
    private class func drawCircle(context: UIGraphicsImageRendererContext,
                                  border: UIColor,
                                  fill: UIColor) {
        context.cgContext.setFillColor(border.cgColor)
        let outerRect = CGRect(x: 0, y: 0, width: imageSize, height: imageSize)
        context.cgContext.addEllipse(in: outerRect)
        context.cgContext.drawPath(using: .fill)
        
        context.cgContext.setFillColor(fill.cgColor)
        let innerRect = CGRect(x: 0.5, y: 0.5, width: imageSize - 1, height: imageSize - 1)
        context.cgContext.addEllipse(in: innerRect)
        context.cgContext.drawPath(using: .fill)
    }
}
