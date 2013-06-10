library pixelcycle;
import 'dart:html';
import 'dart:async' as async;
import 'dart:json' as json;
import 'package:js/js.dart' as js;

part 'palette.dart';
part 'player.dart';
part 'grid.dart';
part 'drive.dart';
part 'doc.dart';
part 'gridui.dart';
part 'ui.dart';

void main() {
  var jsLoaded = js.context["jsApiLoaded"];
  if (jsLoaded) {
    start();
  } else {
    js.context["startDart"] = once(start);
  }
}

void start() {
  var loc = window.location;
  startDrive().then((Drive drive) {
    var state = new StateToken.load(loc);
    if (state.action == "create") {
      createDoc(drive, "Untitled animation", state.folderId);
    } else if (state.action == "open") {
      openDoc(drive, state.ids[0]);
    } else {
      setTitle("PixelCycle");
      Element button = query("#create");
      button.onClick.listen((e) {
        createDoc(drive, "Test", null);
      });
      button.classes.remove("hidden");
    }
  });  
}

class StateToken {
  final String action;
  final List<String> ids;
  final String folderId;
  
  StateToken(this.action, this.ids, this.folderId);
  
  factory StateToken.deserialize(String data) {
    var map = json.parse(data);
    return new StateToken(map["action"], map["ids"], map["folderId"]);
  }
  
  factory StateToken.load(Location loc) {
    if (loc.search == "") {
      return new StateToken("none", [], null);
    }
    Uri url = new Uri(query: loc.search.substring(1));
    var state = url.queryParameters["state"];
    if (state == null) {
      return new StateToken("none", [], null);
    }
    return new StateToken.deserialize(state);
  }
  
  String serialize() {
    if (folderId == null) {
      return json.stringify({"action": action, "ids": ids});      
    } else {
      return json.stringify({"action": action, "ids": ids, "folderId": folderId});
    }
  }
  
  String toUrl(Location loc) {
    var old = Uri.parse(loc.toString());
    return new Uri(
        scheme: old.scheme,
        host: old.host,
        port: old.port,
        path: old.path,
        queryParameters: {"state": serialize()}).toString();    
  }
}

void createDoc(Drive drive, String name, String folderId) {
  drive.createDoc(name, folderId).then((id) {
    print("reloading page");
    var state = new StateToken("open", [id], null);
    var newUrl = state.toUrl(window.location);
    window.location.replace(newUrl);
  });  
}

void openDoc(Drive drive, String fileId) {
  async.Future.wait([
    drive.loadFileMeta(fileId),
    drive.loadDoc(fileId)
  ]).then((futures) {
    FileMeta meta = futures[0];
    Doc doc = futures[1];
    setTitle(meta.title);
    if (meta.editable) {
      startEditor(doc);      
    } else {
      startViewer(doc);
    }
  });
}

void setTitle(String title) {
  query("title").text = title;
  query("#title").text = title;
}

void startViewer(Doc doc) {
  MovieModel movie = new MovieModel.standard(doc);
  GridView big = new GridView.big(movie);
  startPlayer(movie, big);
}

void startEditor(Doc doc) {
  MovieModel movie = new MovieModel.standard(doc);
  GridView big = new GridView.big(movie);

  query("#title")
    ..classes.add("clickable")
    ..onClick.listen((e) {
    doc.loadFileMeta().then((FileMeta meta) {
      showPrompt("Enter a new title for this animation:", meta.title).then((String newTitle) {
        if (newTitle != meta.title) {
          doc.setTitle(newTitle).then((FileMeta meta) {
            setTitle(meta.title);
          });
        }
      });
    });
  });
  
  PaletteModel pm = movie.palette;
  pm.select(51);
  Editor ed = new Editor(movie);
  big.enablePainting(ed, pm);
  
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

  query("#palette").append(new PaletteView(pm, pm.colors.length~/4).elt);
  query("#undo")..append(undo)..append(redo);  
  
  startPlayer(movie, big);
}

void startPlayer(MovieModel movie, GridView big) {
  PlayerModel player = new PlayerModel(movie);  
  player.onFrameChange.listen((int frame) {
    big.setModel(movie.grids[frame]);
  });
  
  query("#frames").append(new FrameListView(movie, player).elt);
  query("#player").append(new PlayerView(player).elt);
  query("#grid").append(big.elt);
  
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
