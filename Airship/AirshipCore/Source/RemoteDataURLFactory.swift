/* Copyright Airship and Contributors */

import Foundation

struct RemoteDataURLFactory: Sendable {
    static func makeURL(config: RuntimeConfig, path: String, locale: Locale, randomValue: Int) throws -> URL {
        guard var components = URLComponents(string: config.remoteDataAPIURL ?? "") else {
            throw AirshipErrors.error("URL is null")
        }

        components.path = path

        var queryItems: [URLQueryItem] = []

        let languageItem = URLQueryItem(
            name: "language",
            value: locale.getLanguageCode()
        )

        if languageItem.value?.isEmpty == false {
            queryItems.append(languageItem)
        }

        let countryItem = URLQueryItem(
            name: "country",
            value: locale.getRegionCode()
        )

        if countryItem.value?.isEmpty == false {
            queryItems.append(countryItem)
        }

        let versionItem = URLQueryItem(
            name: "sdk_version",
            value: AirshipVersion.version
        )

        if versionItem.value?.isEmpty == false {
            queryItems.append(versionItem)
        }

        let randomValueItem = URLQueryItem(
            name: "random_value",
            value: String(randomValue)
        )

        if randomValueItem.value?.isEmpty == false {
            queryItems.append(randomValueItem)
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw AirshipErrors.error("URL is null")
        }

        return url
    }
}
