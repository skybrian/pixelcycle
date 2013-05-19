library pixelcycle;
import 'dart:html';
import 'dart:async' as async;

part 'palette.dart';

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

class EditorModel {
  int selected = 0;
  async.Stream<EditorModel> onChange;
  async.EventSink<EditorModel> onChangeSink;
  
  EditorModel() {
    var controller = new async.StreamController<EditorModel>();
    onChange = controller.stream.asBroadcastStream();
    onChangeSink = controller.sink;    
  }
  
  void setSelected(int frameIndex) {
    this.selected = frameIndex;
    onChangeSink.add(this);
  }
}

class FrameListView {
  final Element elt = new DivElement();
  
  FrameListView(MovieModel movie, EditorModel editor) {
    var frames = movie.frames;
    for (int i = 0; i < frames.length; i++) {
      var v = new GridView(frames[i], 1);
      v.elt.classes.add("frame");
      v.elt.dataset["id"] = i.toString();
      elt.append(v.elt);
    }
    
    elt.onClick.listen((e) {
      Element elt = e.target;
      var id = elt.dataset["id"];
      if (id != null) {
        editor.setSelected(int.parse(id));
      }
    });    
  }
}

void main() {
  PaletteModel pm = new PaletteModel.standard();
  query("#palette").append(new PaletteView(pm, pm.colors.length~/4).elt);
  
  MovieModel movie = new MovieModel(pm, 60, 36, 8, 0);
  EditorModel editor = new EditorModel();
  query("#frames").append(new FrameListView(movie, editor).elt);
  
  GridView big = new GridView(movie.frames[0], 14);
  big.enablePainting(pm);
  query("#grid").append(big.elt);
  editor.onChange.listen((EditorModel e) {
    big.setModel(movie.frames[e.selected]);  
  });

  InputElement fpsSlider = query("#fps");
  ButtonElement play = query("#play");
  async.Timer playing;
  play.onClick.listen((e) {
    if (playing != null) {
      playing.cancel();
      playing = null;
      play.text = "Play";
      return;
    }    
    
    var i = 0;

    var tickAsync;
    tickAsync = () {
      int fps = int.parse(fpsSlider.value);
      Duration tick = new Duration(milliseconds: (1000/fps).toInt());
      playing = new async.Timer(tick, () {
        i++;
        if (i >= movie.frames.length) {
          i = 0;
        }
        big.setModel(movie.frames[i]);
        tickAsync();
      });    
    };    
    play.text = "Stop";
    tickAsync();
  });
}
