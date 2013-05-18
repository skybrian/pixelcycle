import 'dart:html';
import 'dart:async' as async;

class PaletteModel {
  final List<String> colors;
  int selected = 1;
  async.Stream<PaletteModel> onChange;
  async.EventSink<PaletteModel> onChangeSink;
  PaletteModel(this.colors) {    
    var controller = new async.StreamController<PaletteModel>();
    onChange = controller.stream;
    onChangeSink = controller.sink;
  }
  
  String getColor(int index) {
    return colors[index];
  }
  
  void select(int id) {
    this.selected = id;
    onChangeSink.add(this);
  }
  
  int getSelection() {
    return selected;
  }
}

class PaletteView {
  final PaletteModel m;
  final elt = new TableElement();
  final cells;
  PaletteView(PaletteModel model, int width) :
    m = model,
    cells = new List<TableCellElement>(model.colors.length) {
    elt.classes.add("palette");
    _initTable(width);
    
    elt.onClick.listen((MouseEvent e) {
      Element t = e.target;
      var id = t.dataset["id"];
      if (id != null) {
        m.select(int.parse(id));
      }
    });
    
    m.onChange.listen((m) {
      render();  
    });
  }
  
  _initTable(int width) {
    var row = new TableRowElement();
    for (int i = 0; i < m.colors.length; i++) {
      if (row.children.length == width) {
        elt.append(row);
        row = new TableRowElement();
      }
      var td = new TableCellElement();
      td.classes.add("paletteCell");
      td.dataset["id"] = i.toString();
      td.style.backgroundColor = m.colors[i];
      td.style.outlineColor = m.colors[i];
      cells[i] = td;
      row.append(td);
      renderCell(i);
    }
    elt.append(row); 
  }
  
  void render() {
    for (int i = 0; i < m.colors.length; i++) {
      renderCell(i);
    }
  }
  
  void renderCell(int i) {
    var td = cells[i];
    if (i == m.selected) {
      td.classes.add("paletteCellSelected");
    } else {
      td.classes.remove("paletteCellSelected");
    }
  }
}

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

class Color {
  int r;
  int g;
  int b;
  
  /// Each argument has range 0 to 255.
  Color.rgb(this.r, this.g, this.b);
  
  /// Each argument has range 0 to 1.
  Color.hsv(double h, double s, double v) {
    assert(h >= 0 && h <= 1);
    assert(s >= 0 && s <= 1);
    assert(v >= 0 && v <= 1);
    
    // Normalize hue to a number from 0 to 6 (exclusive).
    // This is so we can divide the circle into 6 60-degree pieces.
    h = (h - h.floor()) * 6.0;

    // The distance from the previous 60-degree axis on the hue's circle. (Range 0 to 1 exclusive.)
    num d = h - h.floor();
    
    // Chroma is the difference between the lowest and highest color component. (Range 0 to 1.)
    num c = v * s;
    
    // The two unchanging components in each piece. (Range 0 to 255.)
    int min = ((v - c) * 255.0).floor();
    int max = min + (c * 255.0).floor();
    
    // Distance from starting point for the changing component. (Range 0 to 254.)
    num ramp = (d * c * 255.0).floor();
    
    // Use a separate case for each piece.
    switch (h.floor()) {
      case 0: // red to yellow
        r = max;
        g = min + ramp;
        b = min;
        break;
      case 1: // yellow to green
        r = max - ramp;
        g = max;
        b = min;
        break;
      case 2: // green to cyan
        r = min;
        g = max;
        b = min + ramp;
        break;       
      case 3: // cyan to blue
        r = min;
        g = max - ramp;
        b = max;
        break;       
      case 4: // blue to magenta
        r = min + ramp;
        g = min;
        b = max;
        break;       
      case 5: // magenta to red
        r = max;
        g = min;
        b = max - ramp;
        break;
      default:
        assert(false);
    }  
    print("h=${h} s=${s} v=${v} c=${c} min=${min} max=${max} ramp=${ramp} r=${r} g=${g} b=${b}");
  }

  String toString() {
    return "rgb(${r},${g},${b})";
  }
}

/// Creates a list of colors in a spectrum with constant saturation and value.
List<String> spectrum(double s, double v) {
  final result = new List<String>();
  var hues =
      [0, 15, 30, 45,
       60, 80,
       120, 160,
       180, 200, 220,
       240, 260, 280,
       300, 330];  
  for (var h in hues) {
    result.add(new Color.hsv(h/360.0, s, v).toString());
  }
  return result;
}

List<String> makePaletteColors() { 
  var result = new List<String>();
  result.addAll(["#000000", "#333333", "#666666"]);
  result.addAll(spectrum(0.5, 0.8));
  
  result.addAll(["#999999", "#cccccc", "#ffffff"]);
  result.addAll(spectrum(1.0, 1.0));
  
  result.addAll(["#330000", "#333300", "#003300"]);
  result.addAll(spectrum(1.0, 0.75));

  result.addAll(["#003333", "#000033", "#330033"]);
  result.addAll(spectrum(1.0, 0.5));

  return result;
}

void main() {
  PaletteModel pm = new PaletteModel(makePaletteColors());
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
