part of pixelcycle;

class PlayerModel {
  final MovieModel movie;
  int frame = 0;
  async.Stream<int> onFrameChange;
  async.EventSink<int> _onFrameChangeSink;

  bool _playing = false;
  bool _reverse = false;
  int fps = 15;
  async.Stream<PlayerModel> onSettingChange;
  async.EventSink<PlayerModel> _onSettingChangeSink;
  async.Timer _ticker;
  
  PlayerModel(this.movie) {
    var controller = new async.StreamController<int>();
    onFrameChange = controller.stream.asBroadcastStream();
    _onFrameChangeSink = controller.sink;    
    var controller2 = new async.StreamController<PlayerModel>();
    onSettingChange = controller2.stream.asBroadcastStream();
    _onSettingChangeSink = controller2.sink;    
  }
  
  void setFrame(int frameIndex) {
    this.frame = frameIndex;
    _onFrameChangeSink.add(frameIndex);
  }
  
  void setFramesPerSecond(int newValue) {
    if (fps == newValue) {
      return;
    }
    fps = newValue;
    _onSettingChangeSink.add(this);
  }
  
  bool get playing {
    return _playing;
  }
  
  void set playing(bool newValue) {
    if (_playing == newValue) {
      return;
    }
    _playing = newValue;
    _onSettingChangeSink.add(this);
    tick();
  }
  
  bool get reverse {
    return _reverse;
  }
  
  void set reverse(bool newValue) {
    if (_reverse == newValue) {
      return;
    }
    _reverse = newValue;
    _onSettingChangeSink.add(this);
  }
  
  void tick() {
    if (playing) {
      scheduleTick();
    }
    if (_reverse) {
      _step(-1);      
    } else {
      _step(1);
    }
  }
  
  void scheduleTick() {
    _cancelTick();
    int delay = (1000/fps).toInt();
    _ticker = new async.Timer(new Duration(milliseconds: delay), () {
      if (playing) {
        tick();  
      }
    });    
  }
  
  void _cancelTick() {
    if (_ticker != null) {
      _ticker.cancel();
      _ticker = null;
    }    
  }
  
  void step(int amount) {
    _step(amount);
    playing = false;
  }
  
  void _step(int amount) {
    int len = movie.frames.length;
    int next = (frame + amount + len) % len;
    setFrame(next);    
  }
}

class PlayerView {
  final PlayerModel player;
  final Element elt = new DivElement();
  final step = new ButtonElement();
  final play = new ButtonElement();
  final slider = new RangeInputElement();
  final reverse = new ButtonElement();
  
  PlayerView(this.player) {
    step.text = "Step";
    slider
      ..min = "1"
      ..max = "60";
    reverse
      ..classes.add("toggle")
      ..innerHtml = "&nbsp;"
      ..title = "Reverses the animation (spacebar)";
    elt..append(step)..append(play)..append(slider)..append(reverse);
      
    step.onClick.listen((e) => player.step(1));
    play.onClick.listen((e) => player.playing = !player.playing);
    slider.onChange.listen((e) => player.setFramesPerSecond(int.parse(slider.value)));
    reverse.onClick.listen((e) => player.reverse = !player.reverse);     
    player.onSettingChange.listen((e) => render());  
    render();
  }
  
  void render() {
    if (player.playing) {
      play.text = "Stop";
    } else {
      play.text = "Play";
    }
    slider.value = player.fps.toString();    
    if (player.reverse) {
      reverse.classes.add("reverse");
    } else {
      reverse.classes.remove("reverse");
    }
  }
}

