import 'dart:html';
import 'dart:async' as async;

class PixelRect {
  int width;
  int height;
  int pixelsize;
  List<String> pixels;
  bool willRender = false;
  
  PixelRect(this.width, this.height, this.pixelsize, String color) {
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
  
  void onMouseDraw(MouseEvent e, String color, CanvasRenderingContext2D c) {
    int x = (e.offsetX / pixelsize).toInt();
    int y = (e.offsetY / pixelsize).toInt();
    if (!set(x, y, color)) {
      return;
    }
    if (!willRender) {
      window.requestAnimationFrame((t) {
        render(c);
        willRender = false;
      });
      willRender = true;
    }
  }  
}

typedef void cancelFunc();

cancelFunc startDrawing(PixelRect p, CanvasElement elt) {
  var sub = elt.onMouseMove.listen((MouseEvent e) {
    p.onMouseDraw(e, "#0F0", elt.context2D);
  });
  return sub.cancel;
}

void main() {
  
  PixelRect p = new PixelRect(32, 32, 10, "#000");
  
  CanvasElement elt = new CanvasElement();
  elt.width = p.renderWidth();
  elt.height = p.renderWidth();
  query("#canvas").append(elt);
  
  CanvasRenderingContext2D c = elt.context2D;
  p.render(c);
  
  cancelFunc stopDrawing = () {};
  elt.onMouseDown.listen((MouseEvent e) {
    if (e.button == 0) {
      stopDrawing = startDrawing(p, elt);
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
