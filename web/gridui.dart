part of pixelcycle;

class FrameListView {
  final PlayerModel player;
  final Element elt = new DivElement();
  final views = new List<GridView>();
  
  FrameListView(MovieModel movie, this.player) {
    var grids = movie.grids;
    for (int i = 0; i < grids.length; i++) {
      var v = new GridView(grids[i], 1);
      v.elt.classes.add("frame");
      v.elt.dataset["id"] = i.toString();
      elt.append(v.elt);
      views.add(v);
    }
    
    elt.onClick.listen((e) {
      Element elt = e.target;
      var id = elt.dataset["id"];
      if (id != null) {
        player.playing = false;
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

class GridView {
  StrokeGrid grid;
  final int pixelsize;
  final CanvasElement elt;
  Rect damage = null;
  var _cancelOnChange = () {};
  
  GridView(StrokeGrid g, this.pixelsize) : elt = new CanvasElement() {       
    elt.onMouseDown.listen((MouseEvent e) {
      e.preventDefault(); // don't allow selection
    });
    setModel(g);
  }
  
  factory GridView.big(MovieModel movie) {
    return new GridView(movie.grids[0], 14);
  }
  
  void setModel(StrokeGrid newG) {
    if (grid == newG) {
      return;
    }
    _cancelOnChange();
    grid = newG;
    var newWidth = grid.width * pixelsize;
    if (elt.width != newWidth) {
      elt.width = newWidth;
    }
    var newHeight = grid.height * pixelsize;
    if (elt.height != newHeight) {
      elt.height = newHeight;
    }
    var sub = grid.onChange.listen((Rect damage) {
      renderAsync(damage);  
    });
    _cancelOnChange = sub.cancel;
    renderAsync(grid.all);
  }
  
  void renderAsync(Rect clip) {
    if (damage != null) {
      damage = damage.union(clip);
      return;
    }
    damage = clip;
    window.requestAnimationFrame((t) {
      grid.render(elt.context2D, pixelsize, damage);
      damage = null;
    });
  }
  
  void enablePainting(Editor editor, PaletteModel palette) {
    
    void _paint(MouseEvent e, int colorIndex) {
      int x = (e.offset.x / pixelsize).toInt();
      int y = (e.offset.y / pixelsize).toInt();
      editor.paint(grid, x, y, colorIndex);
    }

    elt.onTouchStart.listen((TouchEvent e) {
      e.preventDefault();
    });
    
    elt.onTouchMove.listen((TouchEvent e) {
      e.preventDefault();
      for (Touch t in e.targetTouches) {
        int canvasX = t.page.x - elt.offsetLeft;
        int canvasY = t.page.y - elt.offsetTop;
        int x = (canvasX / pixelsize).toInt();
        int y = (canvasY / pixelsize).toInt();
        print("TouchMove: ${x}, ${y}");
        editor.paint(grid, x, y, palette.selected);
      }
    });
    
    var stopPainting = () {};
    elt.onMouseDown.listen((MouseEvent e) {
      if (e.button == 0) {
        e.preventDefault(); // don't change the cursor
        _paint(e, palette.selected);
        var sub = elt.onMouseMove.listen((MouseEvent e) {
          _paint(e, palette.selected);
        });
        stopPainting = () {
          editor.endPaint();
          sub.cancel();
        };
      }
    });
    
    query("body").onMouseUp.listen((MouseEvent e) {
      stopPainting();
    });
    
    elt.onMouseOut.listen((MouseEvent e) {
      stopPainting();      
    });    
  }
}

class Editor {
  final MovieModel movie;
  final actions = new List<StrokeSet>();
  StrokeSet top;
  final redos = new List<StrokeSet>();
  async.Stream<bool> onCanUndo;
  async.EventSink<bool> onCanUndoSink;
  async.Stream<bool> onCanRedo;
  async.EventSink<bool> onCanRedoSink;

  Editor(this.movie) {
    var control = new async.StreamController<bool>();
    onCanUndo = control.stream.asBroadcastStream();
    onCanUndoSink = control.sink;
    var control2 = new async.StreamController<bool>();
    onCanRedo = control2.stream.asBroadcastStream();
    onCanRedoSink = control2.sink;
  }
  
  void paint(StrokeGrid g, int x, int y, int colorIndex) {
    var couldUndo = canUndo();
    var couldRedo = canRedo();
    if (top == null) {
      top = new StrokeSet(colorIndex);
      redos.clear();
    }
    top.paint(g, x, y);
    if (!couldUndo) {
      onCanUndoSink.add(true);
    }
    if (couldRedo) {
      onCanRedoSink.add(false);
    }
    movie.doc.touchLater();
    // postcondition: top not null, redo is empty
  }
  
  void endPaint() {
    if (top != null) {
      top.endPaint();
      actions.add(top);
      top = null;
    }    
  }
  
  bool canUndo() {
    return top != null || !actions.isEmpty;
  }
  
  void undo() {
    bool couldRedo = canRedo();
    if (top != null) {
      top.undo();
      redos.add(top);
      top = null;
    } else {
      var last = actions.removeLast();
      last.undo();
      redos.add(last);
    }
    if (!canUndo()) {
      onCanUndoSink.add(false);      
    }
    if (!couldRedo) {
      onCanRedoSink.add(true);
    }
    movie.doc.touchLater();
    // postcondition: top is null, redo not empty
  }
  
  bool canRedo() {
    return !redos.isEmpty;
  }
  
  void redo() {
    bool couldUndo = canUndo();
    StrokeSet action = redos.removeLast();
    action.redo();
    actions.add(action);
    if (!canRedo()) {
      onCanRedoSink.add(false);
    }
    if (!couldUndo) {
      onCanUndoSink.add(true);
    }
    movie.doc.touchLater();
  }  
}

class StrokeSet {
  final int colorIndex;
  final strokes = new Map<StrokeGrid, Stroke>();

  StrokeSet(this.colorIndex);
  
  void paint(StrokeGrid g, int x, int y) {
    Stroke s = g.paint(x, y, colorIndex);
    if (s != null) {
      strokes[g] = s;
    }
  }
  
  void endPaint() {
    for (var g in strokes.keys) {
      g.endPaint();
    }    
  }
  
  bool canUndo() {
    return !strokes.isEmpty;
  }
  
  void undo() {
    for (var g in strokes.keys) {
      g.undo(strokes[g]);
    }
  }
  
  void redo() {
    for (var g in strokes.keys) {
      g.redo(strokes[g]);
    }
  }
}
