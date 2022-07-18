/* Copyright Airship and Contributors */

import Foundation

/// Url Info
/// - Note: for internal use only.  :nodoc:
@objc(UAURLInfo)
public class URLInfo : NSObject {
    @objc
    public enum URLType : Int {
        case web
        case video
        case image
    }
    
    @objc
    public let urlType: URLType
    
    @objc
    public let url: String
    
    @objc
    public init(urlType: URLType, url: String) {
        self.urlType = urlType
        self.url = url
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
extension Layout {
    
    func urlInfos() -> [URLInfo] {
        return extractUrlInfos(model: self.view) ?? []
    }
    
    private func extractUrlInfos(model: ViewModel) -> [URLInfo]? {
        switch (model) {
        case .container(let model):
            return model.items
                .compactMap { extractUrlInfos(model: $0.view) }
                .reduce([], +)
        case .linearLayout(let model):
            return model.items
                .compactMap { extractUrlInfos(model: $0.view) }
                .reduce([], +)
        case .pager(let model):
            return model.items
                .compactMap { extractUrlInfos(model: $0.view) }
                .reduce([], +)
        case .scrollLayout(let model):
            return extractUrlInfos(model: model.view)
        case .checkboxController(let model):
            return extractUrlInfos(model: model.view)
        case .radioInputController(let model):
            return extractUrlInfos(model: model.view)
        case .formController(let model):
            return extractUrlInfos(model: model.view)
        case .npsController(let model):
            return extractUrlInfos(model: model.view)
        case .pagerController(let model):
            return extractUrlInfos(model: model.view)
        case .media(let model):
            switch(model.mediaType) {
            case .image:
                return [URLInfo(urlType: .image, url: model.url)];
            case .youtube:
                return [URLInfo(urlType: .video, url: model.url)];
            case .video:
                return [URLInfo(urlType: .video, url: model.url)];
            }
        #if !os(tvOS) && !os(watchOS)
        case .webView(let model):
            return [URLInfo(urlType: .web, url: model.url)];
        #endif
        case .imageButton(let model):
            switch(model.image) {
            case .url(let imageModel):
                return [URLInfo(urlType: .image, url: imageModel.url)]
            case .icon(_):
                return nil
            }
        case .label(_):
            return nil
        case .labelButton(_):
            return nil
        case .emptyView(_):
            return nil
        case .pagerIndicator(_):
            return nil
        case .checkbox(_):
            return nil
        case .radioInput(_):
            return nil
        case .textInput(_):
            return nil
        case .score(_):
            return nil
        case .toggle(_):
            return nil
        case .stateController(_):
            return nil
        }
    }
}
