# Airship iOS SDK Migration Guide

# Airship SDK 16.x to 17.0.0

## Core module changes

### Live Activities 

Await is no longer needed.

```
// 16.x
    Task {
        await Airship.channel.trackLiveActivity(
        activity,
        name: "order-1234"
    )
}

// 17.x
    Airship.channel.trackLiveActivity(
        activity,
        name: "order-1234"
    )
```

### Deep link delegate 

Deep link delegate is now async.

```
// 16.x
    deepLinkDelegate.receivedDeepLink(deepLink) {
        completionHandler(true)
    }   

// 17.x
    await deepLinkDelegate.receivedDeepLink(deepLink) {
        completionHandler(true)
    }  
```

### Subscription lists

Subscription list access is now async. 

```
// 16.x
/ AirshipChannelProtocol
    Airship.channel.fetchSubscriptionLists { channelSubscriptionLists, Error in
    // Use the channelSubscriptionLists
    }

// AirshipContactProtocol
    Airship.contact.fetchSubscriptionLists { contactSubscriptionLists, error in
    // Use the contactSubscriptionLists
    }

// 17.x
// AirshipChannelProtocol
    await Airship.channel.fetchSubscriptionLists { channelSubscriptionLists, Error in
    // Use the channelSubscriptionLists
    }

// AirshipContactProtocol
    await Airship.contact.fetchSubscriptionLists { contactSubscriptionLists, error in
    // Use the contactSubscriptionLists
    }
```

### Contact

Contact conflict event is now NSNotification or a Publisher.

```
// 16.x
   conflictDelegate?.onConflict(anonymousContactData: anonData, namedUserID: namedUserID)

// 17.x
    Airship.contact.conflictEventPublisher.sink { event in
        // ...
    }
        
    NotificationCenter.default.addObserver(
        self,
        selector: #selector(conflictEventReceived),
        name: AirshipContact.contactConflictEvent
    )
```

Named user id access is now async.

```
// 16.x
   let namedUserID = Airship.contact.namedUserID

// 17.x
   let namedUserID = await Airship.contact.namedUserID
```

## Removed modules

Accengage and Location modules are removed in SDK 17. 


## Message Center

### Message Center UI

#### SwitUI:

Now our Message Center View is written on SwiftUI, wich means it's integration in a swiftUI project is more sample.

Example:

```
struct CustomMessageCenter: View {
    let controller = MessageCenterController()
    
    var body: some View {
        MessageCenterView(controller: controller)
    }
}
```

### Message Center APIs

The `messageList` has been renamed to `inbox`.

All message center methods are `async` now.

To fetch the list of messages:

```let messages = MessageCenter.shared.messageList.messages  -> let messages = MessageCenter.shared.inbox.messages ```

To refresh the list of messages:

SDK 16:
```
MessageCenter.shared.messageList.retrieveMessageList(successBlock: {
   // handle success
}, withFailureBlock: {
    // handle failure
})
```

SDK 17:
```
MessageCenter.shared.inbox.refreshMessages()
```

To mark a messag as read:

SDK 16:
```
let message = MessageCenter.shared.messageList.message(forID: "messageID")
MessageCenter.shared.messageList.markMessagesRead([message as Any]) {}
```

SDK 17:
```
await MessageCenter.shared.inbox.markRead(messageIDs: ["messageID"])

Or

let message = await MessageCenter.shared.inbox.message(forID: "messageID")
if let message = message {
    await MessageCenter.shared.inbox.markRead(messages: [message])
}
```

To delete a message:

SDK 16:
```
let message = MessageCenter.shared.messageList.message(forID: "messageID")
MessageCenter.shared.messageList.markMessagesDeleted([message as Any]) {}
```

SDK 17:
```
await MessageCenter.shared.inbox.delete(messageIDs: ["messageID"])

Or

if let message = message {
    await MessageCenter.shared.inbox.delete(messages: [message])
}
```

### Theme

`MessageCenterStyle` has been renamed to `MessageCenterTheme`.

SDK 16:
```
let style = MessageCenterStyle()

// Customize the style object
style.titleColor = UIColor(red: 0.039, green: 0.341, blue: 0.490, alpha: 1)
style.tintColor = UIColor(red: 0.039, green: 0.341, blue: 0.490, alpha: 1)

// Set the style on the default Message Center UI
MessageCenter.shared.defaultUI.style = style
```

SDK 17:
```
let messageCenterTheme = MessageCenterTheme()

// Set the message center theme
messageCenterTheme.iconsEnabled = true
```

#### SwitUI:

You can also set the message center theme with SwiftUI.

Example:

```
struct CustomMessageCenter: View {
    let controller = MessageCenterController()
    static var messageCenterTheme: MessageCenterTheme {
        let messageCenterTheme = MessageCenterTheme()
        messageCenterTheme.iconsEnabled = true
        return messageCenterTheme
    }
    
    var body: some View {
        MessageCenterView(controller: controller)
            .messageCenterTheme(CustomMessageCenter.messageCenterTheme)
    }
}
```


## Preference Center

### Preference Center UI

#### SwitUI:

Now our Preference Center View is written on SwiftUI, wich means it's integration in a swiftUI project is more sample.

```
PreferenceCenterView(preferenceCenterID: "preferenceCenter-ID")
```


### Theme

`PreferenceCenterStyle` has been renamed to `PreferenceCenterTheme`.

SDK 16:
```
let style = PreferenceCenterStyle()

// Customize the style object
style.titleFont = UIFont(name: "Roboto-Regular", size: 17.0)
style.sectionTextFont = UIFont(name: "Roboto-Bold", size: 14.0)
style.preferenceTextFont = UIFont(name: "Roboto-Light", size: 12.0)

// Set the style on the default Preference Center UI
PreferenceCenter.shared.style = style
```

SDK 17:
```
let preferenceCenterTheme = PreferenceCenterTheme()
/// Set the preference center theme
```

#### SwitUI:

You can also set the preference center theme with SwiftUI.

Example:

```
struct CustomPreferenceCenter: View {
    
    static var preferenceCenterTheme: PreferenceCenterTheme {
        let preferenceCenterTheme = PreferenceCenterTheme()
       // Set the preference center theme
        return preferenceCenterTheme
    }
    
    var body: some View {
        PreferenceCenterView(preferenceCenterID: "neat")
            .messageCenterTheme(CustomPreferenceCenter.preferenceCenterTheme)
    }
}
```

