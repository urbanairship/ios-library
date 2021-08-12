UAPrivacyManager:
 enable -> enableFeatures
 UAPrivacyManagerEnabledFeaturesChangedEvent -> UAPrivacyManager.changeEvent

UALocaleManager:
  currentLocale is no longer null_resettable. Use `clearLocale` instead.

UARegionEvent:
- proximityRegion and circularRegion  are no longer mutable properties. Use one of the factory methods to set them instead.

UACircularRegion:
 - radius, lat, and longs are now Double instead of NSNumber

UAProximityRegion:
 - major, minor, lat, and longs are now Double instead of NSNumber
 - rssi, lat, long are no longer mutable properties. Use one of the factory methods to set them instead.

UACustomEvent:
- UACustomEventMaxPropertiesCount -> UACustomEvent.maxPropertiesCount
- UACustomEventNameKey  -> UACustomEvent.eventNameKey
- UACustomEventValueKey -> UACustomEvent.eventValueKey
- UACustomEventPropertiesKey UACustomEvent.eventPropertiesKey
- UACustomEventTransactionIDKey -> UACustomEvent.eventTransactionIDKey
- UACustomEventInteractionIDKey -> UACustomEvent.eventInteractionIDKey
- UACustomEventInteractionTypeKey -> UACustomEvent.eventInteractionTypeKey

ActionRegistry:
  - removeName, removeEntry, etc.. will no longer return a BOOL
  - UAActionRegistryEntry is no longer mutable, mutate the entry through the registry

ActionPredicate
 - When loading from a file, the default init will be used instead of the factory method `predicate`.