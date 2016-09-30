UAirship.callbackID = 0;

UAirship.delegateCallURL = function() {
  if (!arguments.length) {
    throw new Error("UAirship.delegateCallURL expects at least one function argument");
  }

  var argumentsArray = Array.prototype.slice.call(arguments);

  //treat the first arguments as the command name
  var name = argumentsArray[0];

  //the rest are path arguments and query options
  var args = argumentsArray.slice(1);

  var uri = [];
  var dict = null;

  // get arguments and dictionary
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
  var url = "uairship://" + name + "/" + uri.join("/");

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

  UAirship.callbackID++;
  var callbackKey = 'ua-cb-' + (UAirship.callbackID);

  opt[actionName] = JSON.stringify(argument);

  var url = UAirship.delegateCallURL('run-action-cb', callbackKey, opt);

  window[callbackKey] = onready;

  function onready(err, data) {
    delete window[callbackKey];

    if (!callback) {
      return;
    }

    if(err) {
      callback(err);
    } else {
      callback(null, data);
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

UAirship.close = function() {
  UAirship.runAction('__close_window_action', null, null);
}

UAirship.isReady = true;

var uaLibraryReadyEvent = document.createEvent('Event');
uaLibraryReadyEvent.initEvent('ualibraryready', true, true);
document.dispatchEvent(uaLibraryReadyEvent);
