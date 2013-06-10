part of pixelcycle;

class Doc {
  final Drive drive;
  String fileId;
  final js.Proxy model;
  final Map<String, Frame> frameById = new Map<String, Frame>();
  async.Timer _touchedTimer;

  Doc(this.drive, this.fileId, js.Proxy jsDoc) : this.model = js.retain(jsDoc["getModel"]()) {
    for (var f in _list.map((p) {
      return new Frame(this, new CollaborativeList(p));    
    })) {
      frameById[f.id] = f;      
    }
  }
  
  List<Frame> getFrames() {
    // TODO: handle frame insert and delete
    return _list.map((p) => frameById[p.id]);
  }
  
  CollaborativeMap createMap() {
    return new CollaborativeMap(model["createMap"]());
  }
  
  CollaborativeList get _list {
    return new CollaborativeList(model["getRoot"]()["get"]("frames"));    
  }
  
  async.Future<FileMeta> loadFileMeta() {
    return drive.loadFileMeta(fileId);
  }
  
  async.Future<FileMeta> setTitle(String newTitle) {
    return drive.setTitle(fileId, newTitle);
  }
  
  // Touch the file after waiting at least five seconds.
  // (It will be delayed until there are no touch calls for five seconds.)
  void touchLater() {
    if (_touchedTimer != null) {
      _touchedTimer.cancel();  
    }
    _touchedTimer = new async.Timer(new Duration(seconds: 5), () {
      drive.touch(fileId);
    });
  }
}

class Frame {
  final Doc doc;
  final CollaborativeList _strokes;
  final Map<String, Stroke> strokeById = new Map<String, Stroke>();
  async.Stream<FrameChange> onChange;
  async.EventSink<FrameChange> onChangeSink;
  
  Frame(this.doc, this._strokes) {
    _strokes.retain();

    var control = new async.StreamController<FrameChange>();
    onChange = control.stream.asBroadcastStream();
    onChangeSink = control.sink;
    
    EventListener forward = (js.Proxy e) {
      onChangeSink.add(new FrameChange(this, e["index"]));      
    };
    
    var EventType = gapi["drive"]["realtime"]["EventType"];
    _strokes.addEventListener(EventType["VALUES_ADDED"], forward);
    _strokes.addEventListener(EventType["VALUES_SET"], forward); 
    _strokes.addEventListener(EventType["VALUES_REMOVED"], forward);
  }
  
  String get id => _strokes.id;
  
  List<Stroke> strokesFrom(int startIndex) {
    var len = _strokes.length;
    var out = new List<Stroke>(len - startIndex);
    for (int i = startIndex; i < len; i++) {
      var proxy = _strokes[i];
      var id = proxy["id"];
      strokeById.putIfAbsent(id, () => new Stroke.deserialize(proxy));
      out[i - startIndex] = strokeById[id];
    }
    return out;
  }
  
  Stroke createStroke(int colorIndex) {
    var s = new Stroke(doc.createMap(), colorIndex);
    strokeById[s.id] = s;
    return s;
  }
  
  void push(Stroke s) {
    s.save();
    _strokes.push(s.shared.proxy);
  }
  
  void remove(Stroke s) {
    _strokes.removeValue(s.shared.proxy);
  }
}

class FrameChange {
  final Frame frame;
  final int startIndex;  
  FrameChange(this.frame, this.startIndex);
}

class Stroke {
  final CollaborativeMap shared;
  int colorIndex;
  List<int> xs;
  List<int> ys;
  Map<String,dynamic> data;
  
  Stroke(this.shared, this.colorIndex) : xs = new List<int>(), ys = new List<int>(), data = new Map() {
    shared.retain();
    data["c"] = colorIndex;
    data["xs"] = xs;
    data["ys"] = ys;
  }
  
  Stroke.deserialize(js.Proxy p) : shared = new CollaborativeMap(p) {
    shared.retain();
    load();
  }
  
  String get id {
    return shared.id;
  }
  
  int get length {
    return xs.length;
  }
  
  void load() {
    data = json.parse(shared["d"]);
    colorIndex = data["c"];
    xs = data["xs"];
    ys = data["ys"];
  }
  
  String save() {
    shared["d"] = json.stringify(data);
  }
}
