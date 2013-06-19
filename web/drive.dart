part of pixelcycle;

var gapi = js.retain(js.context["gapi"]);

once(x) => new js.Callback.once(x);

async.Future<Drive> startDrive() {
    
  async.Future authorize(bool immediate) {
    var c = new async.Completer();
    gapi["auth"]["authorize"](js.map({
      "client_id": "659568974202.apps.googleusercontent.com",
      "immediate": immediate,
      "scope": [
          "https://www.googleapis.com/auth/drive.install",
          "https://www.googleapis.com/auth/drive.file",
          // "openid"
      ],
    }), once((authResult) {
      if (authResult != null && authResult["error"] == null) {
        print("got authorization");
        c.complete();
      } else if (immediate) {
        print("need authorization; showing prompt");
        // Immediate failed, so ask user to authenticate.
        var button = query("#authorize");
        button.onClick.take(1).listen((e) {
          button.classes.add("hidden");
          authorize(false).then((x) => c.complete());            
        });
        query("#loading").classes.add("hidden");
        button.classes.remove("hidden");
        return;
      } else {
        window.alert("Unable to connect to Google Drive");        
      }
    }));
    return c.future;
  }
    
  var c = new async.Completer<Drive>();
  authorize(true).then((x) => c.complete(new Drive()));
  return c.future;
}

class Drive {

  // Returns file id
  async.Future<String> createDoc(String title, String folderId) {
    var c = new async.Completer();
    _loadApi("drive", "v2").then((x) {
      var metadata = {
        "mimeType": 'application/vnd.google-apps.drive-sdk',
        "title": title
      };
      if (folderId != null) {
        metadata["parents"] = js.array([js.map({'id': folderId})]);
      }
      gapi["client"]["drive"]["files"]["insert"](js.map({'resource': metadata}))
        .execute(once((fileInfo, unused) {
          print("document ${fileInfo["id"]} created");        
          c.complete(fileInfo["id"]);  
        }));      
    });
    return c.future;
  }
  
  async.Future<FileMeta> loadFileMeta(String fileId) {
    var c = new async.Completer();
    _loadApi("drive", "v2").then((x) {
      gapi["client"]["drive"]["files"]["get"](js.map({
        'fileId': fileId
      })).execute(once((file, unused) => c.complete(new FileMeta(file))));        
    });
    return c.future;
  }
  
  async.Future<FileMeta> setTitle(String fileId, String newTitle) {
    var c = new async.Completer();    
    _loadApi("drive", "v2").then((x) {
      print("updating title of ${fileId} to ${newTitle}");
      gapi["client"]["drive"]["files"]["update"](js.map({
        'fileId': fileId,
        'resource': {'fileId': fileId, 'title': newTitle}
      })).execute(once((file, unused)  {
        c.complete(new FileMeta(file)); 
      }));        
    });
    return c.future;
  }
  
  async.Future<Doc> loadDoc(String fileId) {
    var c = new async.Completer<Doc>();
    onLoad(js.Proxy jsDoc) {
      var doc = new Doc(this, fileId, jsDoc);
      print("document ${fileId} loaded");
      c.complete(doc);
    }
    
    var ErrorType = gapi["drive"]["realtime"]["ErrorType"];
    onError(js.Proxy err) {
      var type = err["type"];
      if (type == ErrorType["TOKEN_REFRESH_REQUIRED"]) {
        print("token refresh required; reloading");
        window.location.reload();
      } else {
        print("error type: ${type}");
        if (window.confirm(err["message"] + " Reload the page?")) {
          window.location.reload();
          return;
        }
      }
    }
  
    gapi["drive"]["realtime"]["load"](fileId, once(onLoad), once(_initializeModel), once(onError));
    return c.future;
  }
  
  void touch(String fileId) {
    _loadApi("drive", "v2").then((x) {
      gapi["client"]["drive"]["files"]["touch"](js.map({"fileId": fileId}))
        .execute(once((file, unused) {
          print("touched file ${fileId}");
        }));
    });    
  }
  
  async.Future _loadApi(String name, String version) {
    var c = new async.Completer();
    gapi["client"]["load"](name, version, once(() {
      print("${name} api loaded");     
      c.complete();
    }));
    return c.future;
  }
  
  void _initializeModel(js.Proxy model) {
    var createList = model["createList"];
    var frames = createList();
    for (int i = 0; i < 8; i++) {
      frames.push(createList());
    }
    model["getRoot"]()["set"]("frames", frames);
  }
}

class FileMeta {
  final String title;
  final bool editable;
  FileMeta(js.Proxy file) : title = file["title"], editable = file["editable"];
}

typedef void EventListener(js.Proxy p);

class CollaborativeList {
  final js.Proxy proxy;
  
  CollaborativeList(this.proxy);
  
  String get id => proxy["id"];
  int get length => proxy["length"];
  
  operator [](int index) {
    return proxy["get"](index);
  }
  
  List map(mapper(proxy)) {
    var get = proxy["get"];
    return new List.generate(length, (i) => mapper(get(i)));  
  }
  
  void push(item) {
    proxy["push"](item);
  }
  
  void removeValue(item) {
    proxy["removeValue"](item);
  }
  
  void addEventListener(String eventType, EventListener callback) {
    proxy["addEventListener"](eventType, new js.Callback.many(callback));    
  }
  
  void retain() {
    js.retain(proxy);
  }
}

class CollaborativeMap {
  final js.Proxy proxy;
  CollaborativeMap(this.proxy);

  String get id => proxy["id"];

  operator [](String key) {
    return proxy["get"](key);
  }

  operator []=(String key, dynamic value) {
    return proxy["set"](key, value);
  }  

  void retain() {
    js.retain(proxy);
  }
}
