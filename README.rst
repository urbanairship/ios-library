iOS Urban Airship Library
=========================

Overview
--------

Urban Airship's libUArship is a drop-in static library that provides a simple way to
integrate Urban Airship services into your iOS applications. This entire project will
allow you to build the library files and all sample projects. If you just want to
include the library in your app, you can simply download the latest ``libUAirship.zip``
and a sample project. These zips contain a pre-compiled universal arm6/arm7 library.
We do not support i386 or simulator usage.

Working with the Library
------------------------

Copy libUAirship Files (When Not Building From Source)
######################################################

Download and unzip the latest version of libUAirship.  If you are using one of our sample
projects, copy the ``Airship`` directory into the same directory as your project::

    cp -r Airship /SomeDirectory/ (where /SomeDirectory/YourProject/ is your project)

If you are not using a sample project, you'll need to import the source files for the User 
Interface into your project. These are located under /Airship/UI/Default

Building libUAirship From Source As Part Of A Project
#####################################################

If you are building from source (an archive or a github clone), you will have an ios-library
directory. Copy this entire directory into your source tree in a location of your choosing.

Next, you'll need to include the AirshipLib.xcodeproj file as a subproject in your project.
You'll then need to mark AirshipLib as a direct dependency of your target, and add
libUAirship-1.0.3.a to the libraries your target links against.

Required Libraries
##################

AirMail Inbox requires your application to link against the following Frameworks::

    libUAirship-1.0.3.a
    CFNetwork.framework
    CoreGraphics.framework
    Foundation.framework
    MobileCoreServices.framework
    Security.framework
    SystemConfiguration.framework
    UIKit.framework
    libz.dylib
    libsqlite3.dylib
    CoreTelephony.framework (Exists in iOS 4+ only, so make it a weak link for 3.x compatibility)
    StoreKit.framework

Build Settings
##############

**Compiler**
    
LLVM 1.6 is the default compiler for all projects and the static library. GCC 4.2 is also supported.
     
**Header search path**
                                         
Ensure that your build target's header search path includes the Airship directory.

**Linker**

In order to properly link against the Urban Airship static library, you will need to set the ``-all_load``
flag and ``-weak_library /usr/lib/libSystem.B.dylib`` in your build target's ``Other Linker Flags``.
             
Quickstart
----------

Prerequisite
############

Before getting started you must perform the steps above outlined above.

In addition you'll need to include *UAirship.h* in your source files.

The AirshipConfig File
######################

The library uses a .plist configuration file named `Airship.plist` to manage your production and development
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

