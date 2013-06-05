part of pixelcycle;

class Doc {
  final js.Proxy model;
  final Map<String, Frame> frameById = new Map<String, Frame>();

  Doc(js.Proxy jsDoc) : this.model = js.retain(jsDoc["getModel"]()) {
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
