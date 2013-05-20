part of pixelcycle;

class PlayerModel {
  final MovieModel movie;
  int frame = 0;
  async.Stream<int> onFrameChange;
  async.EventSink<int> _onFrameChangeSink;
  
  bool playing = false;
  int fps;
  async.Stream<PlayerModel> onSettingChange;
  async.EventSink<PlayerModel> _onSettingChangeSink;
  async.Timer _ticker;
  
  PlayerModel(this.movie, this.fps) {
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
    if (fps != newValue) {
      fps = newValue;
      _onSettingChangeSink.add(this);
    }
  }
  
  void setPlaying(bool newValue) {
    if (playing == newValue) {
      return;
    }
    playing = newValue;
    _onSettingChangeSink.add(this);
    if (playing) {
      _tick();
    } else {
      _cancelTick();
    }
  }

  void _scheduleTick() {
    _cancelTick();
    int delay = (1000/fps).toInt();
    _ticker = new async.Timer(new Duration(milliseconds: delay), _tick);    
  }
  
  void _cancelTick() {
    if (_ticker != null) {
      _ticker.cancel();
      _ticker = null;
    }    
  }
  
  void _tick() {
    if (!playing) {
      return;
    }
    _scheduleTick();
    _step(1);
  }
  
  void step(int amount) {
    _step(amount);
    setPlaying(false);
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
  
  PlayerView(this.player) {
    step.text = "Step";
    slider
      ..min = "1"
      ..max = "60";  
    elt..append(step)..append(play)..append(slider);
      
    step.onClick.listen((e) => player.step(1));
    play.onClick.listen((e) => player.setPlaying(!player.playing));
    slider.onChange.listen((e) => player.setFramesPerSecond(int.parse(slider.value)));;
    
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
  }
}

