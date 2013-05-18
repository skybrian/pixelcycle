part of pixelcycle;

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
  
  factory PaletteModel.standard() {
    var colors = new List<String>();

    colors.addAll(["#000000", "#333333", "#666666"]);
    colors.addAll(spectrum(0.5, 0.8));
    
    colors.addAll(["#999999", "#cccccc", "#ffffff"]);
    colors.addAll(spectrum(1.0, 1.0));
    
    colors.addAll(["#330000", "#333300", "#003300"]);
    colors.addAll(spectrum(1.0, 0.75));

    colors.addAll(["#003333", "#000033", "#330033"]);
    colors.addAll(spectrum(1.0, 0.5));

    return new PaletteModel(colors);
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

/// Creates a list of colors in a spectrum with constant saturation and value.
List<String> spectrum(double s, double v) {
  final result = new List<String>();
  // Space out colors in a 360 degree color wheel so they look distinct. (Fewer greens.)
  var hues = [
       // red to yellow
       0, 15, 30, 45,
       // yellow to green
       60, 80,
       // green to cyan
       120, 160,
       // cyan to blue
       180, 200, 220,
       // blue to magenta
       240, 260, 280,
       // magenta to red
       300, 330
   ];  
  for (var h in hues) {
    result.add(new Color.hsv(h/360.0, s, v).toString());
  }
  return result;
}

class Color {
  final int r;
  final int g;
  final int b;
  
  /// Each argument has range 0 to 255.
  Color.rgb(this.r, this.g, this.b);
  
  /// Calculates an rgb color from hue, saturation, and value. Each argument has range 0 to 1.
  factory Color.hsv(double h, double s, double v) {
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
      case 0:
        // red to yellow
        return new Color.rgb(max, min + ramp, min);
      case 1:
        // yellow to green
        return new Color.rgb(max - ramp, max, min);
      case 2:
        // green to cyan
        return new Color.rgb(min, max, min + ramp);
      case 3:
        // cyan to blue
        return new Color.rgb(min, max - ramp, max);    
      case 4: // blue to magenta
        return new Color.rgb(min + ramp, min, max);         
      case 5: // magenta to red
        return new Color.rgb(max, min, max - ramp);
    }
    
    throw new Exception("shouldn't get here");
  }

  String toString() {
    return "rgb(${r},${g},${b})";
  }
}