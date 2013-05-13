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
  final elt = new DivElement();
  final cells;
  PaletteView(PaletteModel model, int width) : m = model, cells = new List<TableCellElement>(model.swatches.length) {
    elt.classes.add("palette");
    elt.append(_makeTable(width));
    
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
  
  TableElement _makeTable(int width) {
    var table = new TableElement();
    var row = new TableRowElement();
    for (int i = 0; i < m.swatches.length; i++) {
      if (row.children.length == width) {
        table.append(row);
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
    table.append(row);
    return table;  
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
    this.width = width, this.height = height,
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

void main() {
  PaletteModel pm = new PaletteModel(["#000", "#f00", "#0f0", "#00f", "#fff"]);
  query("#palette").append(new PaletteView(pm, 10).elt);
  
  final frames = new List<GridModel>();
  for (int i = 0; i < 8; i++) {
    var f = new GridModel(100, 60, pm.swatches[0]);
    frames.add(f);
    var v = new GridView(f, 1);
    v.elt.classes.add("frame");
    v.elt.dataset["id"] = i.toString();
    query("#frames").append(v.elt);
  }
  
  GridView big = new GridView(frames[0], 10);
  big.enablePainting(pm);

  query("#frames").onClick.listen((e) {
    Element elt = e.target;
    var id = elt.dataset["id"];
    if (id != null) {
      big.setModel(frames[int.parse(id)]);       
    }
  });
  
  query("#grid").append(big.elt);

//  for (var f in frames) {
//    f.fireChanged();
//  }
}
