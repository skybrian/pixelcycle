part of pixelcycle;

/// Returns a list of bytes.
List<int> makeSnapshot(List<StrokeGrid> frames, int fps) {
  print("makeSnapshot");
  assert(frames.length > 0);
  int pixelsize = 6;
  int width = frames[0].width * pixelsize;
  int height = frames[0].height * pixelsize;
  
  CanvasElement elt = new CanvasElement(width: width, height: height);
  var buffer = new gif.GifBuffer(width, height);
  for (var frame in frames) {
    frame.render(elt.context2D, pixelsize, frame.all);
    buffer.add(elt.context2D.getImageData(0, 0, width, height).data);
  }
  return buffer.build(fps);
}

async.Future<String> createDataUrl(List<int> bytes) {
  var c = new async.Completer();
  var f = new FileReader();
  f.onLoadEnd.listen((ProgressEvent e) {
    if (f.readyState == FileReader.DONE) {
      String url = f.result;
      c.complete(url.replaceFirst("data:;", "data:image/gif;"));
    }    
  });
  f.readAsDataUrl(new Blob([bytes]));
  return c.future;
}
