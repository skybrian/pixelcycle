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
  const startData2 = const [0x02]; // two bit pixels, indexes are 0-3.
  const clear2 = "100"; // clear code for two bit data
  const end2 = "101"; // end code for two bit data
  const trailer = const[0x3b];
  
  bits(String s) => int.parse(s, radix: 2);
  
  test('one black pixel', () {
    var image = new gif.IndexedImage(1, 1, [0, 0, 0, 0]);
    List<int> bytes = image.encodeUncompressedGif();
    
    var expected = []
      ..addAll(headerBlock)
      ..addAll(oneByOneTwoColor)
      ..addAll(blackBlack)
      ..addAll(startOneByOneImage)
      ..addAll(startData2)
      ..addAll([2, bits("01" + "000" + clear2), bits("1"), 0x00])
      ..addAll(trailer);
      
    expect(bytes, expected);
  });

  const oneByTwoTwoColor = const [0x1, 0, 0x2, 0, 0xF0, 0, 0]; // 1x2, 128 colors, background index 0 
  const startOneByTwoImage = const [0x2c, 0, 0, 0, 0, 1, 0, 2, 0, 0];

  test('two black pixels', () {
    var image = new gif.IndexedImage(1, 2, [0, 0, 0, 0, 0, 0, 0, 0]);
    List<int> bytes = image.encodeUncompressedGif();
    
    var expected = []
      ..addAll(headerBlock)
      ..addAll(oneByTwoTwoColor)
      ..addAll(blackBlack)
      ..addAll(startOneByTwoImage)
      ..addAll(startData2)
      ..addAll([2, bits("00" + "000" + clear2), bits(end2 + clear2 + "0"), 0x00])
      ..addAll(trailer);
      
    expect(bytes, expected);
  });

  const threeByOneFourColor = const [0x3, 0, 0x1, 0, 0xF1, 0, 0]; // 1x2, 128 colors, background index 0 
  const startThreeByOneImage = const [0x2c, 0, 0, 0, 0, 3, 0, 1, 0, 0];
  const redGreenBlueBlack = const [0xff, 0, 0, 0, 0xff, 0, 0, 0, 0xff, 0, 0, 0]; // 3 bytes per color

  test('rgb', () {
    var image = new gif.IndexedImage(3, 1, [0xff, 0, 0, 0, 0, 0xff, 0, 0, 0, 0, 0xff, 0]);
    List<int> bytes = image.encodeUncompressedGif();
 
    var expected = []
      ..addAll(headerBlock)
      ..addAll(threeByOneFourColor)
      ..addAll(redGreenBlueBlack)
      ..addAll(startThreeByOneImage)
      ..addAll(startData2)
      ..addAll([3, bits("01" + "000" + clear2), bits("1" + "010" + clear2 +"0"), bits("10"), 0x00])
      ..addAll(trailer);
        
    expect(bytes, expected);
  });

}
