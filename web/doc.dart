part of pixelcycle;

class Doc {
  final js.Proxy gapi;
  final js.Proxy doc;
  final Map<String, Frame> frameById = new Map<String, Frame>();

  Doc(this.gapi, this.doc) {
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
  
  CollaborativeList get _list {
    return new CollaborativeList(doc.getModel().getRoot().get("frames"));    
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
      onChangeSink.add(new FrameChange(this, e.index));      
    };
    
    _strokes.addEventListener(doc.gapi.drive.realtime.EventType.VALUES_ADDED, forward);
    _strokes.addEventListener(doc.gapi.drive.realtime.EventType.VALUES_SET, forward); 
    _strokes.addEventListener(doc.gapi.drive.realtime.EventType.VALUES_REMOVED, forward);
  }
  
  String get id => _strokes.id;
  
  List<Stroke> strokesFrom(int startIndex) {
    var len = _strokes.length;
    var out = new List<Stroke>(len - startIndex);
    for (int i = startIndex; i < len; i++) {
      var proxy = _strokes[i];
      var id = proxy.id;
      strokeById.putIfAbsent(id, () => new Stroke.deserialize(proxy));
      out[i - startIndex] = strokeById[id];
    }
    return out;
  }
  
  Stroke createStroke(int colorIndex) {
    var map = new CollaborativeMap(doc.doc.getModel().createMap());
    var s = new Stroke(map, colorIndex);
    strokeById[s.id] = s;
    return s;
  }
  
  void push(Stroke s) {
    s.save();
    _strokes.push(s.map.proxy);
  }
  
  void remove(Stroke s) {
    _strokes.removeValue(s.map.proxy);
  }
}

class FrameChange {
  final Frame frame;
  final int startIndex;  
  FrameChange(this.frame, this.startIndex);
}

class Stroke {
  final CollaborativeMap map;
  int colorIndex;
  List<int> xs;
  List<int> ys;
  Map<String,dynamic> data;
  
  Stroke(this.map, this.colorIndex) : xs = new List<int>(), ys = new List<int>(), data = new Map() {
    map.retain();
    data["c"] = colorIndex;
    data["xs"] = xs;
    data["ys"] = ys;
  }
  
  Stroke.deserialize(js.Proxy p) : map = new CollaborativeMap(p) {
    map.retain();
    load();
  }
  
  String get id {
    return map.id;
  }
  
  int get length {
    return xs.length;
  }
  
  void load() {
    data = json.parse(map["d"]);
    colorIndex = data["c"];
    xs = data["xs"];
    ys = data["ys"];
  }
  
  String save() {
    map["d"] = json.stringify(data);
  }
}
