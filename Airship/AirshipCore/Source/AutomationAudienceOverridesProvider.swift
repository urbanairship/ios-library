import Foundation


// NOTE: For internal use only. :nodoc:
// Audience overrides that we bridge to the automation module in Obj-c. Eventually
// deferred client should be moved to core and this can go away.
@objc(UAAutomationAudienceOverridesProvider)
public final class _AutomationAudienceOverridesProvider: NSObject, Sendable {

    private let audienceOverridesProvider: AudienceOverridesProvider

    init(
        audienceOverridesProvider: AudienceOverridesProvider
    ) {
        self.audienceOverridesProvider = audienceOverridesProvider
    }

    @objc
    public func audienceOverrides(channelID: String, completionHandler:@escaping (_AutomationAudienceOverrides) -> Void) {
        Task {
            let overrides = await audienceOverridesProvider.channelOverrides(
                channelID: channelID
            )

            var tagsPayload : [String : [String: [String]]] = [:]
            if !overrides.tags.isEmpty {
                AudienceUtils.collapse(overrides.tags).forEach { tagUpdate in
                          switch (tagUpdate.type) {
                          case .add:
                              if (tagsPayload["add"] == nil) {
                                  tagsPayload["add"] = [:]
                              }
                              tagsPayload["add"]?[tagUpdate.group] = tagUpdate.tags
                              break
                          case .remove:
                              if (tagsPayload["remove"] == nil) {
                                  tagsPayload["remove"] = [:]
                              }
                              tagsPayload["remove"]?[tagUpdate.group] = tagUpdate.tags
                              break
                          case .set:
                              if (tagsPayload["set"] == nil) {
                                  tagsPayload["set"] = [:]
                              }
                              tagsPayload["set"]?[tagUpdate.group] = tagUpdate.tags
                              break
                          }
                      }

            }

            let attributesPayload: [[String: Any]] = AudienceUtils.collapse(overrides.attributes)
                .compactMap { (attribute) -> ([String : Any]?) in
                    switch(attribute.type) {
                    case .set:
                        guard let value = attribute.jsonValue?.unWrap() else {
                            return nil
                        }

                        return [
                            "action": "set",
                            "key": attribute.attribute,
                            "value": value,
                            "timestamp": AirshipUtils.isoDateFormatterUTCWithDelimiter().string(from: attribute.date)
                        ]
                    case .remove:
                        return [
                            "action": "remove",
                            "key": attribute.attribute,
                            "timestamp": AirshipUtils.isoDateFormatterUTCWithDelimiter().string(from: attribute.date)
                        ]
                    }
                }

            completionHandler(
                _AutomationAudienceOverrides(
                    tagsPayload: tagsPayload.isEmpty ? nil : tagsPayload,
                    attributesPayload: attributesPayload.isEmpty ? nil : attributesPayload
                )
            )
        }
    }
}

// NOTE: For internal use only. :nodoc:
@objc(UAAutomationAudienceOverrides)
public class _AutomationAudienceOverrides: NSObject {
    @objc
    public let tagsPayload: [String : [String: [String]]]?
    @objc
    public let attributesPayload: [[String: Any]]?


    @objc
    public init(tagsPayload: [String : [String: [String]]]?, attributesPayload: [[String: Any]]?) {
        self.tagsPayload = tagsPayload
        self.attributesPayload = attributesPayload
    }
}


