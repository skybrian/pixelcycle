library gif_test;

import 'package:unittest/unittest.dart';
import '../web/gif.dart' as gif;

main() {
  // Based on: http://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp
  // Also see: http://en.wikipedia.org/wiki/File:Quilt_design_as_46x46_uncompressed_GIF.gif
  const headerBlock = const [0x47, 0x49, 0x46, 0x38, 0x39, 0x61]; // GIF 89a
  const oneByOneTwoColor = const [0x1, 0, 0x1, 0, 0xF0, 0, 0]; // 1x1, 128 colors, background index 0 
  const blackBlack = const [0, 0, 0, 0, 0, 0]; // 3 bytes per color
  const startOneByOneImage = const [0x2c, 0, 0, 0, 0, 1, 0, 1, 0, 0];
  const startData7 = const [0x07]; // seven bit data, indexes are 0-127.
  const clear7 = 0x80; // clear code for seven bit data
  const end7 = 0x81; // end code for seven bit data
  const zeroPixel7 = const [3, clear7, 0x00, end7, 0x00];
  const trailer = const[0x3b];
  
  test('one black pixel', () {
    var image = new gif.IndexedImage(1, 1, [0, 0, 0, 0]);
    List<int> bytes = image.encodeUncompressedGif();
    
    var expected = []
      ..addAll(headerBlock)
      ..addAll(oneByOneTwoColor)
      ..addAll(blackBlack)
      ..addAll(startOneByOneImage)
      ..addAll(startData7)
      ..addAll(zeroPixel7)
      ..addAll(trailer);
      
    expect(bytes, expected);
  });
}
