/* Copyright Airship and Contributors */

import UIKit

#if canImport(AirshipCore)
import AirshipCore
import AirshipAutomation
#elseif canImport(AirshipKit)
import AirshipKit
#endif


/**
 * The MediaInfoDetailViewController displays the details of an IAA
 * media info block. It is used to display the details of headings,
 * bodies and button labels.
 */
class MediaInfoDetailViewController: StaticTableViewController {
    public static let segueID = "MediaSegue"
    
    /* The UAInAppMessageMediaInfo to be displayed. */
    public var mediaInfo : InAppMessageMediaInfo?
    
    @IBOutlet private weak var contentDescriptionCell: UITableViewCell!
    @IBOutlet private weak var contentDescriptionTitle: UILabel!
    @IBOutlet private weak var contentDescriptionLabel: UILabel!

    @IBOutlet private weak var typeCell: UITableViewCell!
    @IBOutlet private weak var typeTitle: UILabel!
    @IBOutlet private weak var typeLabel: UILabel!

    @IBOutlet private weak var urlCell: UITableViewCell!
    @IBOutlet private weak var urlTitle: UILabel!
    @IBOutlet private weak var urlLabel: UILabel!

    @IBOutlet private weak var mediaCell: UITableViewCell!
    @IBOutlet private weak var imageView: UIImageView!
    
    fileprivate var webView : WKWebView?
    fileprivate let aspectRatio = CGFloat(16.0/9.0)

    func setCellTheme() {
        contentDescriptionCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        contentDescriptionTitle.textColor = ThemeManager.shared.currentTheme.PrimaryText
        contentDescriptionLabel.textColor = ThemeManager.shared.currentTheme.SecondaryText

        typeCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        typeTitle.textColor = ThemeManager.shared.currentTheme.PrimaryText
        typeLabel.textColor = ThemeManager.shared.currentTheme.SecondaryText

        urlCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        urlTitle.textColor = ThemeManager.shared.currentTheme.PrimaryText
        urlLabel.textColor = ThemeManager.shared.currentTheme.SecondaryText

        mediaCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        imageView.backgroundColor = ThemeManager.shared.currentTheme.Background
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setCellTheme()
        refreshView()
    }
    
    @objc func refreshView() {
        guard let mediaInfo = mediaInfo else { return }
        
        var contentDescription : String?
        
        contentDescription = mediaInfo.contentDescription
        
        switch mediaInfo.type {
        case .image:
            typeLabel.text = "ua_mediainfo_type_image".localized()
        case .video:
            typeLabel.text = "ua_mediainfo_type_video".localized()
        case .youTube:
            typeLabel.text = "ua_mediainfo_type_youTube".localized()
        @unknown default:
            typeLabel.text = "ua_mediainfo_type_unknown".localized()
        }
        
        urlLabel.text? = mediaInfo.url

        updateOrHideCell(contentDescriptionCell, label: contentDescriptionLabel, newText: contentDescription)
        
        switch (mediaInfo.type) {
        case .image:
            if let url = URL(string: mediaInfo.url) {
                URLSession.shared.dataTask(with: url) { (data, response, error) in
                    guard let data = data, error == nil else { return }
                    DispatchQueue.main.async() {
                        if let image = UIImage(data: data) {
                            self.imageView.image = image
                            self.imageView.frame.size.height = self.imageView.frame.size.width * (image.size.height / image.size.width)
                            self.tableView.reloadData()
                        }
                    }
                }.resume()
            }
        case .video, .youTube:
            imageView.isHidden = true

            let config = WKWebViewConfiguration()
            config.allowsInlineMediaPlayback = true
            config.allowsPictureInPictureMediaPlayback = true
            config.mediaTypesRequiringUserActionForPlayback = []

            webView = WKWebView(frame: mediaCell.contentView.frame, configuration:config)
            guard let webView = webView else { return }
            
            webView.translatesAutoresizingMaskIntoConstraints=false
            
            mediaCell.contentView.addSubview(webView)

            // Constrain the webview to the same size as the content view
            NSLayoutConstraint(item: webView, attribute: .top, relatedBy: .equal, toItem: mediaCell.contentView, attribute: .top, multiplier: 1, constant: 0).isActive = true
            NSLayoutConstraint(item: webView, attribute: .bottom, relatedBy: .equal, toItem: mediaCell.contentView, attribute: .bottom, multiplier: 1, constant: 0).isActive = true
            NSLayoutConstraint(item: webView, attribute: .leading, relatedBy: .equal, toItem: mediaCell.contentView, attribute: .leading, multiplier: 1, constant: 0).isActive = true
            NSLayoutConstraint(item: webView, attribute: .trailing, relatedBy: .equal, toItem: mediaCell.contentView, attribute: .trailing, multiplier: 1, constant: 0).isActive = true

            webView.scrollView.isScrollEnabled = false
            
            switch (mediaInfo.type) {
            case .image:
                print("ERROR: should never reach here")
            case .video:
                webView.backgroundColor = UIColor.black
                webView.scrollView.backgroundColor = UIColor.black

                let html = String(format: "<body style=\"margin:0\"><video playsinline controls height=\"100%%\" width=\"100%%\" src=\"%@\"></video></body>", mediaInfo.url)
                webView.loadHTMLString(html, baseURL: URL(string: mediaInfo.url))
            case .youTube:
                guard let url = URL(string:String(format: "%@%@", mediaInfo.url, "?playsinline=1")) else { return }
                let request = URLRequest(url: url)
                webView.load(request)
            @unknown default:
                break
            }
        @unknown default:
            break
        }
        
        tableView.reloadData()
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)

        // let superview override
        let heightFromSuperview = super.tableView(tableView, heightForRowAt: indexPath)
        if heightFromSuperview != UITableView.automaticDimension {
            return heightFromSuperview
        }
        
        // superview didn't override, so let's check our cells
        if cell == contentDescriptionCell {
            return heightForCell(cell, resizingLabel:contentDescriptionLabel)
        } else if cell == mediaCell {
            if (!self.imageView.isHidden) {
                if (self.imageView.image == nil) {
                    return 0
                } else {
                    return imageView.frame.height
                }
            } else if (webView != nil) {
                return mediaCell.contentView.frame.width / aspectRatio
            } else {
                return UITableView.automaticDimension
            }
        } else if cell == urlCell {
            return heightForCell(cell, resizingLabel:urlLabel)
        } else {
            return UITableView.automaticDimension
        }
    }
}
