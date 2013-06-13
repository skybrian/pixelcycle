part of pixelcycle;

async.Future<String> showPrompt(String prompt, String defaultText) {
  var c = new async.Completer();

  Element backdrop = query("#backdrop");
  Element dialog = query("#promptDialog");
  TextInputElement textBox = query("#promptTextBox");

  void finish(String retValue) {
    backdrop.classes.add("hidden");
    dialog.classes.add("hidden");
    c.complete(retValue);    
  }
  
  query("#promptMessage").text = prompt;
  textBox.value = defaultText;
  
  query("#promptOk").onClick.take(1).listen((e) {
    finish(textBox.value.trim());
  });
  query("#promptCancel").onClick.take(1).listen((e) {
    finish(defaultText);
  });

  backdrop.classes.remove("hidden");
  dialog.classes.remove("hidden");
  return c.future;  
}