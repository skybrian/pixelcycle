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
  async.Stream<Rect> onChange;
  async.EventSink<Rect> onChangeSink;
  
  GridModel(this.palette, int width, int height, int startColor) : 
    pixels = new List<int>(width * height),
    this.width = width,
    this.height = height,
    all = new Rect(0, 0, width, height) {
    
    for (int i = 0; i < pixels.length; i++) {
      pixels[i] = startColor;
    }
    
    var controller = new async.StreamController<Rect>();
    onChange = controller.stream.asBroadcastStream();
    onChangeSink = controller.sink;
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
    fireChanged(new Rect(x, y, 1, 1));
  }

  String getColor(num x, num y) {
    return palette.getColor(get(x, y));    
  }
  
  void fireChanged(Rect rect) {
    onChangeSink.add(rect);
  }
  
  void render(CanvasRenderingContext2D c, int pixelsize, Rect clip) {
    c.beginPath();
    for (int y = clip.top; y < clip.bottom; y++) {
      for (int x = clip.left; x < clip.right; x++) {
        c.fillStyle = getColor(x,y);
        c.fillRect(x * pixelsize, y * pixelsize, pixelsize, pixelsize);        
      }
    }
    c.stroke();
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
    elt.width = m.width * pixelsize;
    elt.height = m.height * pixelsize;
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


void main() {
  PaletteModel pm = new PaletteModel.standard();
  query("#palette").append(new PaletteView(pm, pm.colors.length~/4).elt);
  
  final frames = new List<GridModel>();
  for (int i = 0; i < 8; i++) {
    var f = new GridModel(pm, 60, 36, 0);
    frames.add(f);
    var v = new GridView(f, 1);
    v.elt.classes.add("frame");
    v.elt.dataset["id"] = i.toString();
    query("#frames").append(v.elt);
  }
  
  GridView big = new GridView(frames[0], 14);
  big.enablePainting(pm);

  query("#frames").onClick.listen((e) {
    Element elt = e.target;
    var id = elt.dataset["id"];
    if (id != null) {
      big.setModel(frames[int.parse(id)]);       
    }
  });
  
  query("#grid").append(big.elt);

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
    big.setModel(frames[0]);

    var tickAsync;
    tickAsync = () {
      int fps = int.parse(fpsSlider.value);
      Duration tick = new Duration(milliseconds: (1000/fps).toInt());
      playing = new async.Timer(tick, () {
        i++;
        if (i >= frames.length) {
          i = 0;
        }
        big.setModel(frames[i]);
        tickAsync();
      });    
    };    
    play.text = "Stop";
    tickAsync();
  });
}
