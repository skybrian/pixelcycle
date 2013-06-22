part of pixelcycle;

async.Future<String> showPrompt(String prompt, String defaultText) {
  var c = new async.Completer();

  Element backdrop = query("#backdrop");
  Element dialog = query("#promptDialog");
  TextInputElement textBox = query("#promptTextBox");

  List subs = new List();
  void finish(String retValue) {
    for (var sub in subs) {
      sub.cancel();
    }
    backdrop.classes.add("hidden");
    dialog.parent.classes.add("hidden");
    c.complete(retValue);    
  }
  
  query("#promptMessage").text = prompt;
  textBox.value = defaultText;

  subs.add(textBox.onChange.listen((e) => finish(textBox.value.trim())));
  subs.add(query("#promptOk").onClick.listen((e) => finish(textBox.value.trim())));
  subs.add(query("#promptCancel").onClick.listen((e) => finish(defaultText)));
  subs.add(backdrop.onClick.listen((e) => finish(defaultText)));
  
  backdrop.classes.remove("hidden");
  dialog.parent.classes.remove("hidden");
  textBox.focus();
  return c.future;  
}

async.Future<Object> showDownloadPrompt(String imageUrl, String downloadName) {
  var c = new async.Completer();

  Element backdrop = query("#backdrop");
  Element dialog = query("#downloadDialog");  
  AnchorElement anchor = query("#downloadAnchor"); 
  ImageElement image = query("#downloadImage");

  anchor.href = imageUrl;
  anchor.download = downloadName;
  image.src = imageUrl;

  List subs = new List();
  void close() {
    for (var sub in subs) {
      sub.cancel();
    }
    backdrop.classes.add("hidden");
    dialog.parent.classes.add("hidden");
    c.complete(null);
  }
  
  subs.add(query("#downloadOk").onClick.listen((e) => close()));
  subs.add(backdrop.onClick.listen((e) => close()));

  backdrop.classes.remove("hidden");
  dialog.parent.classes.remove("hidden");
  
  return c.future;
}
