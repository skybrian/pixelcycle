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

class StateToken {
  final String action;
  final List<String> ids;
  final String parentId;
  
  StateToken(this.action, this.ids, this.parentId);
  
  factory StateToken.deserialize(String data) {
    var map = json.parse(data);
    return new StateToken(map["action"], map["ids"], map["parentId"]);
  }
  
  factory StateToken.load(Location loc) {
    if (loc.search == "") {
      return new StateToken("create", [], null);
    }
    Uri url = new Uri(query: loc.search.substring(1));
    var state = url.queryParameters["state"];
    if (state == null) {
      return new StateToken("create", [], null);
    }
    return new StateToken.deserialize(state);
  }
  
  String serialize() {
    if (parentId == null) {
      return json.stringify({"action": action, "ids": ids});      
    } else {
      return json.stringify({"action": action, "ids": ids, "parentId": parentId});
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

void main() {
  var loc = window.location;
  startDrive().then((Drive drive) {
    var state = new StateToken.load(loc);
    if (state.action == "create") {
      drive.createDoc("PixelCycle Test").then((id) {
        print("reloading page");
        state = new StateToken("open", [id], null);
        var newUrl = state.toUrl(loc);
        loc.replace(newUrl);
      });
    } else if (state.action == "open") {
      var meta = drive.loadFileMeta(state.ids[0]);
      var doc = drive.loadDoc(state.ids[0]);
      async.Future.wait([meta, doc]).then((both) => setTitle(both[0]));
      doc.then(startApp);      
    } else {
      window.alert("unknown action: ${state.action}");
    }
  });
}

String makeUrl(Location loc, String fileId) {
  var old = Uri.parse(loc.toString());
  return new Uri(
      scheme: old.scheme,
      host: old.host,
      port: old.port,
      path: old.path,
      queryParameters: {"id": fileId}).toString();
}

void setTitle(FileMeta meta) {
  query("title").text = meta.title;
  query("#title").text = meta.title;
}

void startApp(Doc doc) {
  PaletteModel pm = new PaletteModel.standard();
  pm.select(51);
  
  MovieModel movie = new MovieModel(pm, 60, 36, doc);
  Editor ed = new Editor(movie);
  
  GridView big = new GridView(movie.grids[0], ed, 14);
  big.enablePainting(pm);
  
  PlayerModel player = new PlayerModel(movie);  
  player.onFrameChange.listen((int frame) {
    big.setModel(movie.grids[frame]);
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
