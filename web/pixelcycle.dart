library pixelcycle;
import 'dart:html';
import 'dart:async' as async;

part 'palette.dart';
part 'player.dart';

class GridModel {
  final PaletteModel palette;
  final List<int> pixels;
  final int width;
  final int height;
  final Rect all;
  CanvasElement buffer;
  async.Stream<Rect> onChange;
  async.EventSink<Rect> onChangeSink;
  
  GridModel(this.palette, int width, int height, int startColor) : 
    pixels = new List<int>(width * height),
    this.width = width,
    this.height = height,
    all = new Rect(0, 0, width, height),
    buffer = new CanvasElement() {
    
    buffer.width = width;
    buffer.height = height;
          
    var controller = new async.StreamController<Rect>();
    onChange = controller.stream.asBroadcastStream();
    onChangeSink = controller.sink;

    clear(startColor);
  }

  void clear(int colorIndex) {
    for (int i = 0; i < pixels.length; i++) {
      pixels[i] = colorIndex;
    }
    buffer.context2d.fillStyle = palette.getColor(colorIndex);
    buffer.context2d.fillRect(0, 0, width, height);
    onChangeSink.add(all);    
  }
    
  bool inRange(int x, int y) {
    return x >=0 && x < width && y >= 0 && y < height;
  }
  
  int get(int x, int y) {
    return pixels[x + y*width];    
  }
  
  void set(int x, int y, int colorIndex) {
    if (!inRange(x, y)) {
      return;
    }
    int i = x + y*width;
    if (colorIndex == pixels[i]) {
      return;
    }
    pixels[i] = colorIndex;
    buffer.context2d.fillStyle = palette.getColor(colorIndex);
    buffer.context2d.fillRect(x, y, 1, 1);        
    onChangeSink.add(new Rect(x, y, 1, 1));
  }

  String getColor(num x, num y) {
    return palette.getColor(get(x, y));    
  }
  
  void render(CanvasRenderingContext2D c, int pixelsize, Rect clip) {
    c.imageSmoothingEnabled = false;
    c.drawImageScaledFromSource(buffer,
        clip.left, clip.top, clip.width, clip.height,
        clip.left * pixelsize, clip.top * pixelsize, clip.width * pixelsize, clip.height * pixelsize);
  }
}

class GridView {
  GridModel m;
  final int pixelsize;
  final CanvasElement elt;
  Rect damage = null;
  var _cancelOnChange = () {};
  
  GridView(GridModel model, this.pixelsize) : elt = new CanvasElement() {       
    elt.onMouseDown.listen((MouseEvent e) {
      e.preventDefault(); // don't allow selection
    });
    setModel(model);
  }
  
  void setModel(GridModel newM) {
    _cancelOnChange();
    m = newM;
    var newWidth = m.width * pixelsize;
    if (elt.width != newWidth) {
      elt.width = newWidth;
    }
    var newHeight = m.height * pixelsize;
    if (elt.height != newHeight) {
      elt.height = newHeight;
    }
    var sub = m.onChange.listen((Rect damage) {
      renderAsync(damage);  
    });
    _cancelOnChange = sub.cancel;
    renderAsync(m.all);
  }
  
  void renderAsync(Rect clip) {
    if (damage != null) {
      damage = damage.union(clip);
      return;
    }
    damage = clip;
    window.requestAnimationFrame((t) {
      m.render(elt.context2D, pixelsize, damage);
      damage = null;
    });
  }
  
  void enablePainting(PaletteModel palette) {
    var stopPainting = () {};
    elt.onMouseDown.listen((MouseEvent e) {
      if (e.button == 0) {
        paint(e, palette.getSelection());
        var sub = elt.onMouseMove.listen((MouseEvent e) {
          paint(e, palette.getSelection());
        });
        stopPainting = sub.cancel;
        e.preventDefault(); // don't change the cursor
      }
    });
    
    query("body").onMouseUp.listen((MouseEvent e) {
      stopPainting();
    });
    
    elt.onMouseOut.listen((MouseEvent e) {
      stopPainting();      
    });    
  }
  
  void paint(MouseEvent e, int colorIndex) {
    int x = (e.offsetX / pixelsize).toInt();
    int y = (e.offsetY / pixelsize).toInt();
    m.set(x, y, colorIndex);
  }
}

class MovieModel {
  final frames = new List<GridModel>();
  MovieModel(PaletteModel palette, int width, int height, int frameCount, int colorIndex) {
    for (int i = 0; i < frameCount; i++) {
      var f = new GridModel(palette, width, height, colorIndex);
      frames.add(f);
    }   
  }
}

class FrameListView {
  final PlayerModel player;
  final Element elt = new DivElement();
  final views = new List<GridView>();
  
  FrameListView(MovieModel movie, this.player) {
    var frames = movie.frames;
    for (int i = 0; i < frames.length; i++) {
      var v = new GridView(frames[i], 1);
      v.elt.classes.add("frame");
      v.elt.dataset["id"] = i.toString();
      elt.append(v.elt);
      views.add(v);
    }
    
    elt.onClick.listen((e) {
      Element elt = e.target;
      var id = elt.dataset["id"];
      if (id != null) {
        player.setPlaying(false);
        player.setFrame(int.parse(id));
      }
    });
    
    player.onFrameChange.listen((e) => render());
  }
  
  void render() {
    elt.queryAll(".selectedFrame").every((e) => e.classes.remove("selectedFrame"));
    views[player.frame].elt.classes.add("selectedFrame");
  }
}

void main() {
  PaletteModel pm = new PaletteModel.standard();
  pm.select(51);
  
  MovieModel movie = new MovieModel(pm, 60, 36, 8, 0);
  
  GridView big = new GridView(movie.frames[0], 14);
  big.enablePainting(pm);
  
  PlayerModel player = new PlayerModel(movie, 15);  
  player.onFrameChange.listen((int frame) {
    big.setModel(movie.frames[frame]);
  });

  query("#frames").append(new FrameListView(movie, player).elt);
  query("#player").append(new PlayerView(player).elt);
  query("#grid").append(big.elt);
  query("#palette").append(new PaletteView(pm, pm.colors.length~/4).elt);
  
  document.onKeyDown.listen((KeyboardEvent e) {
    switch (e.keyCode) {
      case KeyCode.RIGHT:
        player.step(1);
        break;
      case KeyCode.LEFT:
        player.step(-1);
        break;    
    }
  });
  
  document.onKeyPress.listen((KeyboardEvent e) {
    switch (e.keyCode) {
      case KeyCode.SPACE:
        player.step(1);
        break;
    }
  });
  
  player.setPlaying(true);
}
