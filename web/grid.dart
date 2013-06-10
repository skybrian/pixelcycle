part of pixelcycle;

class MovieModel {
  final PaletteModel palette;
  final grids = new List<StrokeGrid>();
  final Doc doc;
  MovieModel(this.palette, int width, int height, this.doc) {
    for (var f in doc.getFrames()) {
      var cg = new ColorGrid(palette, width, height, 0);
      var sg = new StrokeGrid(f, cg);
      grids.add(sg);
    }
  }
  factory MovieModel.standard(Doc doc) {
    return new MovieModel(new PaletteModel.standard(), 60, 36, doc);
  }
}

class StrokeGrid {
  final Frame frame;
  final ColorGrid grid;
  final List<List<Stroke>> pixelStacks;
  final List<Stroke> strokes = new List<Stroke>();
  Stroke top;
  
  StrokeGrid(this.frame, ColorGrid grid) : 
    this.grid = grid, pixelStacks = new List<List<Stroke>>(grid.width * grid.height) {
    for (int i = 0; i < pixelStacks.length; i++) {
      pixelStacks[i] = new List<Stroke>();
    }
    for (var s in frame.strokesFrom(0)) {
      _redo(s);
      strokes.add(s);
    }
    frame.onChange.listen((FrameChange c) {
      if (top != null) {
        _undo(top);
      }
      while (strokes.length > c.startIndex) {
        Stroke s = strokes.removeLast();
        _undo(s);
      }
      for (var s in frame.strokesFrom(c.startIndex)) {
        _redo(s);
        strokes.add(s);
      }
      if (top != null) {
        _redo(top);       
      }
    });
  }
  
  int get width {
    return grid.width; 
  }
  
  int get height {
    return grid.height;
  }
  
  async.Stream<Rect> get onChange {
    return grid.onChange;
  }
  
  Rect get all {
    return grid.all;
  }
  
  void render(CanvasRenderingContext2D c, int pixelsize, Rect clip) {
    return grid.render(c, pixelsize, clip);
  }
  
  Stroke paint(int x, int y, int colorIndex) {
    if (getColor(x, y) == colorIndex) {
      return null;
    }
    if (top != null && top.colorIndex != colorIndex) {
      endPaint();
    }
    if (top == null) {
      top = frame.createStroke(colorIndex);
    }
    top.xs.add(x);
    top.ys.add(y);        
    _paint(top, x, y);
    return top;
  }
  
  void endPaint() {
    if (top == null) {
      return;
    }
    var s = top;
    undo(s);
    frame.push(s);
  }
  
  void undo(Stroke s) {
    _undo(s);    
    if (s == top) {
      top = null;
    }
    if (strokes.remove(s)) {
      frame.remove(s);
    }
  }
  
  void redo(Stroke s) {
    if (top != null) {
      throw new Exception("can't redo while painting");
    }
    _redo(s);
    strokes.add(s);
    frame.push(s);
  }
  
  void _undo(Stroke s) {
    for (int i = 0; i < s.length; i++) {
      var x = s.xs[i];
      var y = s.ys[i];
      var stack = getStack(x, y);
      stack.remove(s);
      if (stack.isEmpty) {
        grid.setColor(x, y, grid.bgColor);
      } else {
        grid.setColor(x, y, stack.last.colorIndex);
      }      
    }        
  }
  
  void _redo(Stroke s) {
    for (int i = 0; i < s.length; i++) {
      var x = s.xs[i];
      var y = s.ys[i];
      _paint(s, x, y);
    }    
  }
  
  void _paint(Stroke s, int x, int y) {
    getStack(x, y).add(s);    
    grid.setColor(x, y, s.colorIndex);    
  }
  
  int getColor(int x, int y) {
    var stack = getStack(x, y);
    if (stack.isEmpty) {
      grid.bgColor;
    } else {
      return stack.last.colorIndex;
    }          
  }
  
  List<Stroke> getStack(int x, int y) {
    if (x < 0 || y < 0 || x >= grid.width || y >= grid.height) {
      throw new Exception("invalid point: x=${x}, y=${y}");
    }
    return pixelStacks[x + y * grid.width];
  }
}

class ColorGrid {
  final PaletteModel palette;
  final int width;
  final int height;
  final int bgColor;
  final Rect all;
  final CanvasElement buf = new CanvasElement();
  async.Stream<Rect> onChange;
  async.EventSink<Rect> onChangeSink;
  
  ColorGrid(this.palette, int width, int height, this.bgColor) :
    this.width = width, this.height = height, all = new Rect(0, 0, width, height) {   
    
    buf.width = width;
    buf.height = height;
    var c = buf.context2D;
    c.fillStyle = palette.colors[bgColor];
    c.fillRect(0, 0, width, height);

    var controller = new async.StreamController<Rect>();
    onChange = controller.stream.asBroadcastStream();
    onChangeSink = controller.sink;
  }
  
  void setColor(int x, int y, int colorIndex) {
    var c = buf.context2D;
    c.fillStyle = palette.getColor(colorIndex);
    c.fillRect(x, y, 1, 1);
    onChangeSink.add(new Rect(x, y, 1, 1));
  }
  
  void render(CanvasRenderingContext2D c, int pixelsize, Rect clip) {
    c.imageSmoothingEnabled = false;
    c.drawImageScaledFromSource(buf,
        clip.left, clip.top, clip.width, clip.height,
        clip.left * pixelsize, clip.top * pixelsize, clip.width * pixelsize, clip.height * pixelsize);
  }
}
