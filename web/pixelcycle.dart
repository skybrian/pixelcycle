import 'dart:html';
import 'dart:async' as async;

class GridModel {
  int width;
  int height;
  int pixelsize;
  List<String> pixels;
  
  GridModel(this.width, this.height, this.pixelsize, String color) {
    pixels = new List<String>(width * height);
    for (num i = 0; i < pixels.length; i++) {
      pixels[i] = color;
    }
  }

  bool inRange(int x, int y) {
    return x >=0 && x < width && y >= 0 && y < height;
  }
  
  String get(num x, num y) {
    return pixels[x + y*width];    
  }
  
  bool set(int x, int y, String color) {
    if (!inRange(x, y)) {
      return false;
    }
    num i = x + y*width;
    if (color == pixels[i]) {
      return false;
    }
    pixels[i] = color;
    return true;
  }
  
  int renderWidth() {
    return width * pixelsize;
  }
  
  int renderHeight() {
    return height * pixelsize;
  }
  
  void render(CanvasRenderingContext2D c) {
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
  CanvasElement elt;
  bool willRender = false;
  cancelFunc stopDrawing = () {};
  
  GridView(this.m) {
    elt = new CanvasElement();
    elt.width = m.renderWidth();
    elt.height = m.renderWidth();
    
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
      m.render(elt.context2D);
      willRender = false;
    });
    willRender = true;   
  }
  
  void paint(MouseEvent e, String color) {
    int x = (e.offsetX / m.pixelsize).toInt();
    int y = (e.offsetY / m.pixelsize).toInt();
    if (m.set(x, y, color)) {
      renderAsync();
    }
  }
}

void main() {
  
  GridModel p = new GridModel(32, 32, 10, "#000");
  GridView v = new GridView(p);
  query("#canvas").append(v.elt);
  v.renderAsync();  
}
