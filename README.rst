iOS Urban Airship Library
=========================

Overview
--------

Urban Airship's libUArship is a drop-in static library that provides a simple way to
integrate Urban Airship services into your iOS applications. This entire project will
allow you to build the library files and all sample projects. If you just want to
include the library in your app, you can simply download the latest ``libUAirship.zip``
and a sample project. These zips contain a pre-compiled universal armv6/armv7/armv7s/i386 library.

Working with the Library
------------------------

Copy libUAirship Files
######################

Download and unzip the latest version of libUAirship.  If you are using one of our sample
projects, copy the ``Airship`` directory into the same directory as your project::

    cp -r Airship /SomeDirectory/ (where /SomeDirectory/YourProject/ is your project)

If you are not using a sample project, you'll need to import the source files for the User 
Interface into your project. These are located under /Airship/UI/Default

Required Libraries
##################

The core library requires your application to link against the following Frameworks (sample UIs
have additional linking requirements)::

    libUAirship-<current_version>.a
    CFNetwork.framework
    CoreGraphics.framework
    Foundation.framework
    MobileCoreServices.framework
    Security.framework
    SystemConfiguration.framework
    UIKit.framework
    libz.dylib
    libsqlite3.dylib
    CoreTelephony.framework
    StoreKit.framework
    CoreLocation.framework

Build Settings
##############

**Compiler**
The latest version of LLVM is the default compiler for all projects and the static library.
     
**Header search path**                          
Ensure that your build target's header search path includes the Airship directory.
             
Quickstart
----------

Prerequisite
############

Before getting started you must perform the steps above outlined above.

In addition you'll need to include *UAirship.h* in your source files.

The AirshipConfig File
######################

The library uses a .plist configuration file named `AirshipConfig.plist` to manage your production and development
application profiles. Example copies of this file are available in all of the sample projects. Place this file
in your project and set the following values to the ones in your application at http://go.urbanairship.com

You can also edit the file as plain-text::

        {
         /* NOTE: DO NOT USE THE MASTER SECRET */
		"APP_STORE_OR_AD_HOC_BUILD" = NO; /* set to YES for production builds */
		"DEVELOPMENT_APP_KEY" = "Your development app key";
		"DEVELOPMENT_APP_SECRET" = "Your development app secret";
		"PRODUCTION_APP_KEY" = "Your production app key";
		"PRODUCTION_APP_SECRET" = "Your production app secret";
        }

If you are using development builds and testing using the Apple sandbox set `APP_STORE_OR_AD_HOC_BUILD` to false. For
App Store and Ad-Hoc builds, set it to YES.

Advanced users may add scripting or preprocessing logic to this .plist file to automate the switch from
development to production keys based on the build type.

Push Integration
################

To enable push notifications, you will need to make several additions to your application delegate.
    
.. code:: obj-c

    - (BOOL)application:(UIApplication *)application 
            didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
        // Your other application code.....
    
        // Call takeOff, passing in the launch options so the library can properly record when
        // the app is launched from a push notification
        NSMutableDictionary *takeOffOptions = [[[NSMutableDictionary alloc] init] autorelease];
        [takeOffOptions setValue:launchOptions forKey:UAirshipTakeOffOptionsLaunchOptionsKey];
        
        // This prevents the UA Library from registering with UIApplcation by default when
        // registerForRemoteNotifications is called. This will allow you to prompt your
        // users at a later time. This gives your app the opportunity to explain the benefits
        // of push or allows users to turn it on explicitly in a settings screen.
        // If you just want everyone to immediately be prompted for push, you can
        // leave this line out.
        [UAPush setDefaultPushEnabledValue:NO];
        
        // Create Airship singleton that's used to talk to Urban Airhship servers.
        // Please populate AirshipConfig.plist with your info from http://go.urbanairship.com
        [UAirship takeOff:takeOffOptions];
    
        [[UAPush shared] resetBadge];//zero badge on startup
        
        // Register for remote notfications. With the default value of push set to no,
        // UAPush will record the desired remote notifcation types, but not register for
        // push notfications as mentioned above.
        // When push is enabled at a later time, the registration will occur as normal.
        [[UAPush shared] registerForRemoteNotificationTypes:(UIRemoteNotificationTypeBadge |
                                                             UIRemoteNotificationTypeSound |
                                                             UIRemoteNotificationTypeAlert)];
        return YES;
    }
    
    // Implement the iOS device token registration callback
    - (void)application:(UIApplication *)application
            didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
        UALOG(@"APN device token: %@", deviceToken);

        // Updates the device token and registers the token with UA. This won't occur until
        // push is enabled if the outlined process is followed.
        [[UAPush shared] registerDeviceToken:deviceToken];
    }
    
    // Implement the iOS callback for incoming notifications
    //
    // Incoming Push notifications can be handled by the UAPush default alert handler,
    // which displays a simple UIAlertView, or you can provide you own delegate which
    // conforms to the UAPushNotificationDelegate protocol.
    - (void)application:(UIApplication *)application
            didReceiveRemoteNotification:(NSDictionary *)userInfo {

        // Send the alert to UA
        [[UAPush shared] handleNotification:userInfo
                           applicationState:application.applicationState];
        
        // Reset the badge if you are using that functionality
        [[UAPush shared] resetBadge]; // zero badge after push received
    }
    
To enable push:

.. code:: obj-c

    // Somewhere in the app, this will enable push, setting it to NO will disable push
    // This will trigger the proper registration or de-registration code in the library.
    [[UAPush shared] setPushEnabled:YES];

===================  ========  ======================================================
Third party Package  License   Copyright / Creator 
===================  ========  ======================================================
asi-http-request     BSD       Copyright (c) 2007-2010, All-Seeing Interactive.
fmdb                 MIT       Copyright (c) 2008 Flying Meat Inc. gus@flyingmeat.com
SBJSON               MIT       Copyright (C) 2007-2010 Stig Brautaset.
Base64               BSD       Copyright 2009-2010 Matt Gallagher.
ZipFile-OC           BSD       Copyright (C) 1998-2005 Gilles Vollant.
GHUnit               Apache 2  Copyright 2007 Google Inc.
Google Toolkit	     Apache 2  Copyright 2007 Google Inc.
Reachability         BSD       Copyright (C) 2010 Apple Inc.
MTPopupWindow        MIT       Copyright 2011 Marin Todorov
JRSwizzle            MIT       Copyright 2012 Jonathan Rentzsch
===================  ========  ======================================================