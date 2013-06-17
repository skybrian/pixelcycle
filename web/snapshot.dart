part of pixelcycle;

/// Returns a data URL
async.Future<String> snapshot(CanvasElement elt) {

  var data = elt.context2D.getImageData(0, 0, elt.width, elt.height);
  var gifBytes = new gif.IndexedImage(data.width, data.height, data.data).encodeUncompressedGif();

  var c = new async.Completer();
  var f = new FileReader(); 
  f.onLoad.listen((e) {
    String url = f.result;
    c.complete(url.replaceFirst("data:;", "data:image/gif;"));
  });
  f.readAsDataUrl(new Blob([gifBytes]));
  return c.future;
}
