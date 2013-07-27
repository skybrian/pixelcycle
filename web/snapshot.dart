part of pixelcycle;

/// Returns a data URL
async.Future<String> makeSnapshot(List<ImageData> frames, int fps) {
  print("makeSnapshot");
  assert(frames.length > 0);
  int width = frames[0].width;
  int height = frames[0].height;
  
  var buffer = new gif.GifBuffer(width, height);
  for (var frame in frames) {
    buffer.add(frame.data);
  }
  var gifBytes = buffer.build(fps);

  var c = new async.Completer();
  var f = new FileReader(); 
  f.onLoad.listen((e) {
    String url = f.result;
    c.complete(url.replaceFirst("data:;", "data:image/gif;"));
  });
  f.readAsDataUrl(new Blob([gifBytes]));
  return c.future;
}
