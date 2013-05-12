import 'dart:html';
import 'dart:async' as async;

class Swatch {
  String color;
  Swatch(this.color);
}

class GridModel {
  final int width;
  final int height;
  final List<Swatch> pixels;
  async.Stream<GridModel> onChange;
  async.EventSink<GridModel> onChangeSink;
  
  GridModel(int width, int height, Swatch color) : this.width = width, this.height = height, pixels = new List<Swatch>(width * height) {
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
  
  GridView(this.m, this.pixelsize, Swatch brushColor) : elt = new CanvasElement() {
    elt.width = m.width * pixelsize;
    elt.height = m.height * pixelsize;
    
    m.onChange.listen((GridModel) {
      renderAsync();  
    });

    elt.onMouseDown.listen((MouseEvent e) {
      if (e.button == 0) {
        var sub = elt.onMouseMove.listen((MouseEvent e) {
          paint(e, brushColor);
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
  Swatch background = new Swatch("#000");
  
  GridModel m = new GridModel(100, 60, background);

  GridView big = new GridView(m, 10, new Swatch("#fff"));
  query("#big").append(big.elt);
  big.renderAsync();  

  GridView small = new GridView(m, 1, new Swatch("#00f"));
  query("#small").append(small.elt);
  small.renderAsync();
}
