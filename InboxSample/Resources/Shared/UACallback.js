
// UADelegate is the object that communicate with InboxJSDelegate on iPhone side
UADelegate = {
    result : {},
    error : {},
    iOSCallbackDidSucceed : function() {
        // implement your own successCallback here
        // retrieve result created in iPhone callback
        // e.g. var res0 = this.result[0];
        alert("Original success callback: "+UADelegate.result);
    },
    iOSCallbackDidFail : function() {
        // implement your own errorCallback here
        // you can set error info in iPhone callback and reference it from here
        // e.g. document.write(this.error);
        
        alert("Original failure callback: "+UADelegate.result);
    }
};

UADelegate.invokeIPhoneCallback = function() {
    var args = arguments;
    var uri = [];
    var dict = null;
    
    // get iPhone callback arguments and dictionary
    for (var i = 0; i < args.length; i++) {
        
        var arg = args[i];

        if (arg == undefined || arg == null) {
            arg = '';
        }

        if (typeof(arg) == 'object') {
            dict = arg;
        } else {
            uri.push(encodeURIComponent(arg));
        }
    }

    // flatten arguments into url
    var url = "ua://callbackArguments:withDictionary:/" + uri.join("/");

    // flatten dictionary into url
    if (dict != null) {
        var query_args = [];
        for (var name in dict) {
            if (typeof(name) != 'string') {
                continue;
            }
            query_args.push(encodeURIComponent(name) + "=" + encodeURIComponent(dict[name]));
        }

        if (query_args.length > 0) {
            url += "?" + query_args.join("&");
        }
    }

    // send to iPhone
    document.location = url;
};

// This is a demo function that illustrate how to invoke iPhone side callback
function demoFunction() {

    // Customize UADelegate
    // Register your own JS callback that might be invoked when iPhone callback finished

    UADelegate.iOSCallbackDidSucceed = function(){
        console.log("iOS callback succeeded");
        alert("Result: "+UADelegate.result);
    };
    
    UADelegate.iOSCallbackDidFail = function(){
        console.log("iOS callback failed");
        alert("UADelegate.iOSCallbackDidFail: "+UADelegate.error);
    };

    // set options
    var opt = {};
    opt.property1 = 1;
    opt.property2 = "option 2";

    // invoke iPhone delegate
    UADelegate.invokeIPhoneCallback("arg0", "arg1", "Called from JavaScript running on UIWebView", opt);
};
