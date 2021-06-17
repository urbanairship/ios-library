/* Copyright Airship and Contributors */

/**
 * @note For internal use only. :nodoc:
 */
@objc
public class UARemoteDataAPIClient : NSObject {
    private let path = "api/remote-data/app"
    private let session: UARequestSession
    private let config: UARuntimeConfig

    @objc
    public init(config: UARuntimeConfig, session: UARequestSession) {
        self.config = config
        self.session = session
        super.init()
    }

    @objc
    public convenience init(config: UARuntimeConfig) {
        self.init(config: config, session: UARequestSession(config: config))
    }

    @objc
    @discardableResult
    public func fetchRemoteData(withLocale locale: Locale, lastModified: String?, completionHandler: @escaping (UARemoteDataResponse?, Error?) -> Void) -> UADisposable {
        let url = remoteDataURL(withLocale: locale)
        let request = UARequest(builderBlock: { builder in
            builder.url = url
            builder.method = "GET"
            builder.setValue(lastModified, header: "If-Modified-Since")
        })

        AirshipLogger.debug("Request to update remote data: \(request)")

        return session.performHTTPRequest(request, completionHandler: { (data, response, error) in

            guard let response = response else {
                AirshipLogger.debug("Fetch finished with \(error?.localizedDescription ?? "")")
                completionHandler(nil, error)
                return
            }

            if response.statusCode == 200 {
                do {
                    let payloads = try self.parseRemoteData(data)
                    let lastModified = response.allHeaderFields["Last-Modified"] as? String
                    let remoteDataResponse = UARemoteDataResponse(
                        status: 200,
                        requestURL: url,
                        payloads: payloads,
                        lastModified: lastModified)
                    completionHandler(remoteDataResponse, nil)
                } catch  {
                    AirshipLogger.debug("Failed to parse remote data with error: \(error)")
                    completionHandler(nil, error)
                    return
                }
            } else {
                let remoteDataResponse = UARemoteDataResponse(
                    status: response.statusCode,
                    requestURL: url,
                    payloads: nil,
                    lastModified: nil)
                completionHandler(remoteDataResponse, nil)
            }
        })
    }

    func parseRemoteData(_ data: Data?) throws -> [AnyHashable]? {
        if data == nil {
            throw AirshipErrors.parseError("Refresh remote data missing response body.")
        }

        // Parse the response
        let jsonResponse = try JSONSerialization.jsonObject(with: data!, options: .allowFragments) as? [AnyHashable : Any]
        return jsonResponse?["payloads"] as? [AnyHashable]
    }

    @objc
    public func remoteDataURL(withLocale locale: Locale) -> URL? {
        let languageItem = URLQueryItem(name: "language", value: locale.languageCode)
        let countryItem = URLQueryItem(name: "country", value: locale.regionCode)
        let versionItem = URLQueryItem(name: "sdk_version", value: UAirshipVersion.get())

        var components = URLComponents(string: config.remoteDataAPIURL ?? "")

        // api/remote-data/app/{appkey}/{platform}?sdk_version={version}&language={language}&country={country}
        components?.path = "/\(path)/\(config.appKey)/\("ios")"

        var queryItems = [versionItem]

        if languageItem.value != nil && (languageItem.value?.count ?? 0) != 0 {
            queryItems.append(languageItem)
        }

        if countryItem.value != nil && (countryItem.value?.count ?? 0) != 0 {
            queryItems.append(countryItem)
        }

        components?.queryItems = queryItems as [URLQueryItem]
        return components?.url
    }
}
