import 'dart:html';
import 'dart:async' as async;

class GridModel {
  int width;
  int height;
  List<String> pixels;
  async.Stream<GridModel> onChange;
  async.EventSink<GridModel> onChangeSink;
  
  GridModel(this.width, this.height, String color) {
    pixels = new List<String>(width * height);
    for (num i = 0; i < pixels.length; i++) {
      pixels[i] = color;
    }
    
    var controller = new async.StreamController<GridModel>();
    onChange = controller.stream.asBroadcastStream();
    onChangeSink = controller.sink;
  }

  bool inRange(int x, int y) {
    return x >=0 && x < width && y >= 0 && y < height;
  }
  
  String get(num x, num y) {
    return pixels[x + y*width];    
  }
  
  void set(int x, int y, String color) {
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
        c.fillStyle = get(x,y);
        c.fillRect(x * pixelsize, y * pixelsize, pixelsize, pixelsize);        
      }
    }
  }
}

typedef void cancelFunc();

class GridView {
  GridModel m;
  int pixelsize;
  CanvasElement elt;
  bool willRender = false;
  cancelFunc stopDrawing = () {};
  
  GridView(this.m, this.pixelsize) {
    elt = new CanvasElement();
    elt.width = m.width * pixelsize;
    elt.height = m.height * pixelsize;
    
    m.onChange.listen((GridModel) {
      renderAsync();  
    });

    elt.onMouseDown.listen((MouseEvent e) {
      if (e.button == 0) {
        var sub = elt.onMouseMove.listen((MouseEvent e) {
          paint(e, "#0F0");
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
  
  void paint(MouseEvent e, String color) {
    int x = (e.offsetX / pixelsize).toInt();
    int y = (e.offsetY / pixelsize).toInt();
    m.set(x, y, color);
  }
}

void main() {
  
  GridModel m = new GridModel(100, 60, "#000");

  GridView big = new GridView(m, 10);
  query("#big").append(big.elt);
  big.renderAsync();  

  GridView small = new GridView(m, 1);
  query("#small").append(small.elt);
  small.renderAsync();
}
