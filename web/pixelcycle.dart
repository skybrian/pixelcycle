import 'dart:html';
import 'dart:async' as async;

class Swatch {
  String color;
  Swatch(this.color);
}

class PaletteModel {
  final swatches;
  int selected = 1;
  async.Stream<PaletteModel> onChange;
  async.EventSink<PaletteModel> onChangeSink;
  PaletteModel(List<String> colors) : swatches = new List<Swatch>(colors.length) {
    for (int i = 0; i < colors.length; i++) {
      swatches[i] = new Swatch(colors[i]);
    }
    
    var controller = new async.StreamController<PaletteModel>();
    onChange = controller.stream;
    onChangeSink = controller.sink;
  }
  
  void select(int id) {
    this.selected = id;
    onChangeSink.add(this);
  }
  
  Swatch getSwatch() {
    return swatches[selected];
  }
}

class PaletteView {
  final PaletteModel m;
  final elt = new TableElement();
  final cells;
  PaletteView(PaletteModel model, int width) :
    m = model,
    cells = new List<TableCellElement>(model.swatches.length) {
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
    for (int i = 0; i < m.swatches.length; i++) {
      if (row.children.length == width) {
        elt.append(row);
        row = new TableRowElement();
      }
      var td = new TableCellElement();
      td.classes.add("paletteCell");
      td.dataset["id"] = i.toString();
      td.style.backgroundColor = m.swatches[i].color;
      td.style.outlineColor = m.swatches[i].color;
      cells[i] = td;
      row.append(td);
      renderCell(i);
    }
    elt.append(row); 
  }
  
  void render() {
    for (int i = 0; i < m.swatches.length; i++) {
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
  final int width;
  final int height;
  final Rect all;
  final List<Swatch> pixels;
  async.Stream<Rect> onChange;
  async.EventSink<Rect> onChangeSink;
  
  GridModel(int width, int height, Swatch color) : 
    this.width = width,
    this.height = height,
    all = new Rect(0, 0, width, height),
    pixels = new List<Swatch>(width * height) {
    
    for (int i = 0; i < pixels.length; i++) {
      pixels[i] = color;
    }
    
    var controller = new async.StreamController<Rect>();
    onChange = controller.stream.asBroadcastStream();
    onChangeSink = controller.sink;
  }

  bool inRange(int x, int y) {
    return x >=0 && x < width && y >= 0 && y < height;
  }
  
  Swatch get(num x, num y) {
    return pixels[x + y*width];    
  }
  
  void set(int x, int y, Swatch color) {
    if (!inRange(x, y)) {
      return;
    }
    num i = x + y*width;
    if (color == pixels[i]) {
      return;
    }
    pixels[i] = color;
    fireChanged(new Rect(x, y, 1, 1));
  }
  
  void fireChanged(Rect rect) {
    onChangeSink.add(rect);
  }
  
  void render(CanvasRenderingContext2D c, int pixelsize, Rect clip) {
    c.beginPath();
    for (int y = clip.top; y < clip.bottom; y++) {
      for (int x = clip.left; x < clip.right; x++) {
        c.fillStyle = get(x,y).color;
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
        var sub = elt.onMouseMove.listen((MouseEvent e) {
          paint(e, palette.getSwatch());
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
  
  void paint(MouseEvent e, Swatch color) {
    int x = (e.offsetX / pixelsize).toInt();
    int y = (e.offsetY / pixelsize).toInt();
    m.set(x, y, color);
  }
}

class Color {
  final int r;
  final int g;
  final int b;
  Color(this.r, this.g, this.b);
}

/// Returns fully saturated colors along red-yellow-green-blue-purple-red
List<String> makeColors() {
  var rotate = (List l) {
    List r = [];
    r.addAll(l.sublist(12));
    r.addAll(l.sublist(0, 12));
    return r;
  };
  
  var reds = [0xff, 0xff, 0xff,
              0xff, 0x98, 0x55,
              0x00, 0x00, 0x00,
              0x00, 0x00, 0x00,
              0x00, 0x55, 0x98,
              0xff, 0xff, 0xff];  
  var greens = rotate(reds);
  var blues = rotate(greens);
  
  var result = ["#000000", "#333333", "#666666"];
  
  
  var addColor = (int r, int g, int b) {
    if (r < 0 || r > 255) {
      throw new Exception("out of range");
    }
    result.add("rgb(${r},${g},${b})");    
  };
  
  var lighten = (v) => (v/2+0x80).floor();
  for (var i = 0; i < 18; i++) {
    addColor(lighten(reds[i]), lighten(greens[i]), lighten(blues[i]));
  }

  result.addAll(["#999999", "#cccccc", "#ffffff"]);
  
  for (var i = 0; i < 18; i++) {
    addColor(reds[i], greens[i], blues[i]);
  }

  result.addAll(["#330000", "#333300", "#003300"]);

  var darken = (v,m) => (v*m).floor();
  for (var i = 0; i < 18; i++) {
    addColor(darken(reds[i], 0.75), darken(greens[i], 0.75), darken(blues[i], 0.75));
  }

  result.addAll(["#003333", "#000033", "#330033"]);

  for (var i = 0; i < 18; i++) {
    addColor(darken(reds[i], 0.5), darken(greens[i], 0.5), darken(blues[i], 0.5));
  }
  return result;
}

void main() {
  PaletteModel pm = new PaletteModel(makeColors());
  query("#palette").append(new PaletteView(pm, 21).elt);
  
  final frames = new List<GridModel>();
  for (int i = 0; i < 8; i++) {
    var f = new GridModel(60, 36, pm.swatches[0]);
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
