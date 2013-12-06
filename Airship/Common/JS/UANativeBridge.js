var callbackID = 0;

UAirship.callbackURL = function() {
    if (!arguments.length) {
      throw new Error("UAirship.callbackURL expects at least one function argument");
    }

    var argumentsArray = Array.prototype.slice.call(arguments);

    //treat the first arguments as the callback name
    var name = argumentsArray[0];

    //the rest are path arguments and query options
    var args = argumentsArray.slice(1);

    var uri = [];
    var dict = null;

    // get iPhone callback arguments and dictionary
    for (var i = 0; i < args.length; i++) {

        var arg = args[i];

        if (arg === undefined || arg === null) {
            arg = '';
        }

        if (typeof(arg) == 'object') {
            dict = arg;
        } else {
            uri.push(encodeURIComponent(arg));
        }
    }

    // flatten arguments into url
    var url = "ua://" + name + "/" + uri.join("/");

    // flatten dictionary into url
    if (dict !== null) {
        var query_args = [];
        for (var name in dict) {
            query_args.push(encodeURIComponent(name) + "=" + encodeURIComponent(dict[name]));
        }

        if (query_args.length > 0) {
            url += "?" + query_args.join("&");
        }
    }

    return url;
}

UAirship.invoke = function(url) {
    var frame = document.createElement('iframe');
    frame.style.display = 'none';
    frame.src = url;

    document.body.appendChild(frame);
    frame.parentNode.removeChild(frame);
}

UAirship.runAction = function(actionName, argument, callback) {
    var opt = {};

    callbackID++;
    var callbackKey = 'ua-cb-' + (callbackID);

    opt[actionName] = JSON.stringify(argument);

    var url = UAirship.callbackURL('run-action', callbackKey, opt);

    window[callbackKey] = onready;

    function onready(err, data) {
        delete window[callbackKey];

        try {
            callback(err, JSON.parse(data));
        } catch(err) {
            return callback(new Error("could not decode response"));
        }
    }

    UAirship.invoke(url);
}


UAirship.finishAction = function(err, data, callbackKey) {
    if (callbackKey in window) {
        var cb = window[callbackKey];
        cb(err, data);
    };
}

