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
  final List<Swatch> pixels;
  async.Stream<GridModel> onChange;
  async.EventSink<GridModel> onChangeSink;
  
  GridModel(int width, int height, Swatch color) : this.width = width, this.height = height, pixels = new List<Swatch>(width * height) {
    for (int i = 0; i < pixels.length; i++) {
      pixels[i] = color;
    }
    
    var controller = new async.StreamController<GridModel>();
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
    onChangeSink.add(this);
  }
  
  void render(CanvasRenderingContext2D c, int pixelsize) {
    for (num y = 0; y < height; y++) {
      for (num x = 0; x < width; x++) {
        c.fillStyle = get(x,y).color;
        c.fillRect(x * pixelsize, y * pixelsize, pixelsize, pixelsize);        
      }
    }
  }
}

typedef void cancelFunc();

class GridView {
  final GridModel m;
  final int pixelsize;
  final CanvasElement elt;
  bool willRender = false;
  cancelFunc stopDrawing = () {};
  
  GridView(this.m, PaletteModel palette, this.pixelsize) : elt = new CanvasElement() {
    elt.width = m.width * pixelsize;
    elt.height = m.height * pixelsize;
    
    m.onChange.listen((GridModel) {
      renderAsync();  
    });

    elt.onMouseDown.listen((MouseEvent e) {
      if (e.button == 0) {
        var sub = elt.onMouseMove.listen((MouseEvent e) {
          paint(e, palette.getSwatch());
        });
        stopDrawing = sub.cancel;
        e.preventDefault(); // don't change the cursor
      }
    });
    
    query("body").onMouseUp.listen((MouseEvent e) {
      stopDrawing();
    });
    
    elt.onMouseOut.listen((MouseEvent e) {
      stopDrawing();      
    });
  }

  void renderAsync() {
    if (willRender) {
      return;
    }
    window.requestAnimationFrame((t) {
      m.render(elt.context2D, pixelsize);
      willRender = false;
    });
    willRender = true;   
  }
  
  void paint(MouseEvent e, Swatch color) {
    int x = (e.offsetX / pixelsize).toInt();
    int y = (e.offsetY / pixelsize).toInt();
    m.set(x, y, color);
  }
}

void main() {
  PaletteModel pm = new PaletteModel(["#000", "#f00", "#0f0", "#00f", "#fff"]);
  PaletteView pv = new PaletteView(pm, 10);
  
  GridModel gm = new GridModel(100, 60, pm.swatches[0]);

  GridView small = new GridView(gm, pm, 1);
  GridView big = new GridView(gm, pm, 10);

  query("#frames").append(small.elt);
  query("#grid").append(big.elt);
  query("#palette").append(pv.elt);
  
  big.renderAsync();  
  small.renderAsync();
}
