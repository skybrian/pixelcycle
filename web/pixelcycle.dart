library pixelcycle;
import 'dart:html';
import 'dart:async' as async;
import 'dart:uri' as uri;
import 'package:js/js.dart' as js;

part 'palette.dart';
part 'player.dart';
part 'grid.dart';
part 'drive.dart';

class GridView {
  StrokeGrid grid;
  Editor editor;
  final int pixelsize;
  final CanvasElement elt;
  Rect damage = null;
  var _cancelOnChange = () {};
  
  GridView(StrokeGrid g, this.editor, this.pixelsize) : elt = new CanvasElement() {       
    elt.onMouseDown.listen((MouseEvent e) {
      e.preventDefault(); // don't allow selection
    });
    setModel(g);
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
  
  void enablePainting(PaletteModel palette) {
    var stopPainting = () {};
    elt.onMouseDown.listen((MouseEvent e) {
      if (e.button == 0) {
        _paint(e, palette.selected);
        var sub = elt.onMouseMove.listen((MouseEvent e) {
          _paint(e, palette.selected);
        });
        stopPainting = () {
          editor.endPaint();
          sub.cancel();
        };
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
  
  void _paint(MouseEvent e, int colorIndex) {
    int x = (e.offsetX / pixelsize).toInt();
    int y = (e.offsetY / pixelsize).toInt();
    editor.paint(grid, x, y, colorIndex);
  }
}

class MovieModel {
  final frames = new List<StrokeGrid>();
  MovieModel(PaletteModel palette, int width, int height, int frameCount) {
    for (int i = 0; i < frameCount; i++) {
      var cg = new ColorGrid(palette, width, height, 0);
      var sg = new StrokeGrid(cg);
      frames.add(sg);
    }   
  }
}

class FrameListView {
  final PlayerModel player;
  final Element elt = new DivElement();
  final views = new List<GridView>();
  
  FrameListView(MovieModel movie, Editor ed, this.player) {
    var frames = movie.frames;
    for (int i = 0; i < frames.length; i++) {
      var v = new GridView(frames[i], ed, 1);
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

void main() {
  var loc = window.location;
  startDrive().then((Drive drive) {
    var fileId = getFileId(loc);
    if (fileId == null) {
      drive.createDoc("PixelCycle Test").then((id) {
        loc.replace(makeUrl(loc, id));
      });
    } else {
      drive.loadDoc(fileId).then(startApp);      
    }
  });
}

// Returns null if not present.
String getFileId(Location loc) {
  if (loc.search == "") {
    return null;
  }
  return loc.search.substring(1);
}

String makeUrl(Location loc, String fileId) {
  var url = uri.Uri.parse(loc.toString());
  url = new uri.Uri.fromComponents(
      scheme: url.scheme,
      domain: url.domain,
      port: url.port,
      path: url.path,
      query: fileId);
  return url.toString();
}

void startApp(Doc doc) {
  PaletteModel pm = new PaletteModel.standard();
  pm.select(51);
  
  MovieModel movie = new MovieModel(pm, 60, 36, 8);
  Editor ed = new Editor();
  
  GridView big = new GridView(movie.frames[0], ed, 14);
  big.enablePainting(pm);
  
  PlayerModel player = new PlayerModel(movie);  
  player.onFrameChange.listen((int frame) {
    big.setModel(movie.frames[frame]);
  });

  ButtonElement undo = new ButtonElement();
  undo.text = "Undo";
  undo.disabled = true;
  undo.onClick.listen((e) => ed.undo());
  ed.onCanUndo.listen((bool v) {
    undo.disabled = !v;
  });

  ButtonElement redo = new ButtonElement();
  redo.text = "Redo";
  redo.disabled = true;
  redo.onClick.listen((e) => ed.redo());
  ed.onCanRedo.listen((bool v) {
    redo.disabled = !v;
  });
  
  query("#frames").append(new FrameListView(movie, ed, player).elt);
  query("#player").append(new PlayerView(player).elt);
  query("#grid").append(big.elt);
  query("#palette").append(new PaletteView(pm, pm.colors.length~/4).elt);
  query("#undo")..append(undo)..append(redo);  
  
  bool spaceDown = false;
  int spaceDownFrame = -1;
  document.onKeyDown.listen((KeyboardEvent e) {
    switch (e.keyCode) {
      case KeyCode.RIGHT:
        player.step(1);
        break;
      case KeyCode.SPACE:
        if (!spaceDown) {
          spaceDown = true;
          spaceDownFrame = player.frame;
          player.reverse = true;
          player.tick();
          player.scheduleTick();
        }
        break;
      case KeyCode.LEFT:
        player.step(-1);
        break;    
    }
  });
  
  document.onKeyUp.listen((KeyboardEvent e) {
    switch (e.keyCode) {
      case KeyCode.SPACE:
        player.reverse = false;
        player.tick();
        if (player.frame != spaceDownFrame) {
          player.scheduleTick();
        }
        spaceDown = false;
        break;
    }
  });
  
  player.playing = true;
}
