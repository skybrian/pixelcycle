library gif;

import "dart:typed_data";

// Spec: http://www.w3.org/Graphics/GIF/spec-gif89a.txt
// Explanation: http://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp
// Also see: http://en.wikipedia.org/wiki/File:Quilt_design_as_46x46_uncompressed_GIF.gif

const maxColorBits = 7;
const maxColors = 1<<maxColorBits;

/// An image with a restricted palette.
class IndexedImage {
  final int width;
  final int height;
  final colors = new ColorTable();
  List<int> pixels;

  /**
   * Builds an indexed image from per-pixel rgba data, ignoring the alpha channel.
   * Throws an exception if the the image has too many colors.
   * (The input format is the same used by the ImageData class, which can be created
   * from a canvas element.)
   */
  IndexedImage(this.width, this.height, List<int> rgba) {   
    pixels = colors.indexImage(width, height, rgba);    
    colors.finish();
  }
  
  /**
   * Converts the image into an uncompressed GIF, represented as a list of bytes.
   */
  Uint8List encodeUncompressedGif() {
    return new Uint8List.fromList(
        _header(width, height, colors.bits)
        ..addAll(colors.table)
        ..addAll(_startImage(0, 0, width, height))
        ..addAll(_sevenBitPixels(pixels))
        ..addAll(_trailer()));
  }
}

class IndexedAnimation {
  final int width;
  final int height;
  final colors = new ColorTable();
  final frames = new List<List<int>>();
  
  IndexedAnimation(this.width, this.height, List<List<int>> rgbaFrames) {
    for (var frame in rgbaFrames) {
      frames.add(colors.indexImage(width, height, frame));      
    }
    colors.finish();
  }

  /**
   * Converts the animation into an uncompressed GIF, represented as a list of bytes.
   */
  Uint8List encodeUncompressedGif(int fps) {
    int delay = 100 ~/ fps;
    if (delay < 6) {
      delay = 6; // http://nullsleep.tumblr.com/post/16524517190/animated-gif-minimum-frame-delay-browser-compatibility
    }
    
    List<int> bytes = _header(width, height, colors.bits);
    bytes.addAll(colors.table);
    bytes.addAll(_loop(0));
    
    for (int i = 0; i < frames.length; i++) {
      var frame = frames[i];
      bytes
        ..addAll(_delayNext(delay))
        ..addAll(_startImage(0, 0, width, height))
        ..addAll(_sevenBitPixels(frame));
    }
    bytes.addAll(_trailer());
    return new Uint8List.fromList(bytes);
  }
}

class ColorTable {
  final List<int> table = new List<int>();
  final colorToIndex = new Map<int, int>();
  int bits;
  
  /**
   *  Given rgba data, add each color to the color table.
   *  Returns the same pixels as color indexes.
   *  Throws an exception if we run out of colors.
   */
  List<int> indexImage(int width, int height, List<int> rgba) {
    var pixels = new List<int>(width * height);      
    assert(pixels.length == rgba.length / 4);
    for (int i = 0; i < rgba.length; i += 4) {
      int color = rgba[i] << 16 | rgba[i+1] << 8 | rgba[i+2];
      int index = colorToIndex[color];
      if (index == null) {
        if (colorToIndex.length == maxColors) {
          throw new Exception("image has more than ${maxColors} colors");
        }
        index = table.length ~/ 3;
        colorToIndex[color] = index;
        table..add(rgba[i])..add(rgba[i+1])..add(rgba[i+2]);
      }
      pixels[i>>2] = index;
    }  
    return pixels;
  }
  
  /**
   * Pads the color table with zeros to the next power of 2 and sets bits.
   */
  void finish() {
    for (int bits = 1;; bits++) {
      int colors = 1 << bits;
      if (colors * 3 >= table.length) {
        while (table.length < colors * 3) {
          table..add(0);
        }
        this.bits = bits;
        return;
      }
    }
  }
  
  int get numColors {
    return table.length ~/ 3;
  }
}

List<int> _header(int width, int height, int colorBits) {
  const _headerBlock = const [0x47, 0x49, 0x46, 0x38, 0x39, 0x61]; // GIF 89a
  
  List<int> bytes = [];
  bytes.addAll(_headerBlock);
  _addShort(bytes, width);
  _addShort(bytes, height);
  bytes..add(0xF0 | colorBits - 1)..add(0)..add(0);
  return bytes;
}

// See: http://odur.let.rug.nl/~kleiweg/gif/netscape.html
List<int> _loop(int reps) {
  List<int> bytes = [0x21, 0xff, 0x0B];
  bytes.addAll("NETSCAPE2.0".codeUnits);
  bytes.addAll([3, 1]);
  _addShort(bytes, reps);
  bytes.add(0);
  return bytes;
}

List<int> _delayNext(int centiseconds) {
  var bytes = [0x21, 0xF9, 4, 0];
  _addShort(bytes, centiseconds);
  bytes..add(0)..add(0);
  return bytes;
}

List<int> _startImage(int left, int top, int width, int height) {
  List<int> bytes = [0x2C];
  _addShort(bytes, left);
  _addShort(bytes, top);
  _addShort(bytes, width);
  _addShort(bytes, height);
  bytes.add(0); 
  return bytes;
}

List<int> _sevenBitPixels(List<int> pixels) {
  const clear = 128;
  const end = 129;
  const chunkSize = 120;

  List<int> bytes = [7];
  List<int> chunk = [];
  for (int px in pixels) {
    chunk.add(px&0x7F);
    if (chunk.length == chunkSize) {
      bytes..add(chunk.length + 1)..add(clear)..addAll(chunk);
      chunk = [];
    }
  }
  bytes..add(chunk.length + 2)..add(clear)..addAll(chunk)..add(end)..add(0);  
  return bytes;
}

List<int> _trailer() {
  return [0x3b];
}

void _addShort(List<int> dest, int n) {
  if (n < 0 || n > 0xFFFF) {
    throw new Exception("out of range for short: ${n}");
  }
  dest..add(n & 0xff)..add(n >> 8);
}

const startOneByOneImage = const [0x2c, 0, 0, 0, 0, 1, 0, 1, 0, 0];
const startData7 = const [0x07]; // seven bit data, indexes are 0-127.
const clear7 = 0x80; // clear code for seven bit data
const end7 = 0x81; // end code for seven bit data
const zeroPixel7 = const [2, clear7, 0x00];
const endData7 = const [1, end7];
const trailer = const[0x3b];


