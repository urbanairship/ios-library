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
