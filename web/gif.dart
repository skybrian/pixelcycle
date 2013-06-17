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
  final List<int> colorTable = new List<int>();
  int colorBits;
  final List<int> pixels;

  /**
   * Builds an indexed image from per-pixel rgba data, ignoring the alpha channel.
   * Throws an exception if the the image has too many colors.
   * (The input format is the same used by the ImageData class, which can be created
   * from a canvas element.)
   */
  IndexedImage(int width, int height, List<int> rgba) :
    this.width = width,
    this.height = height,
    pixels = new List<int>(width * height) {  
      
    assert(pixels.length == rgba.length / 4);

    // Add color entries to the colorTable and indexes to pixels.
    var colorToIndex = new Map<int, int>();
    for (int i = 0; i < rgba.length; i += 4) {
      int color = rgba[i] << 16 | rgba[i+1] << 8 | rgba[i+2];
      int index = colorToIndex[color];
      if (index == null) {
        if (colorToIndex.length == maxColors) {
          throw new Exception("image has more than ${maxColors} colors");
        }
        index = colorTable.length ~/ 3;
        colorToIndex[color] = index;
        colorTable..add(rgba[i])..add(rgba[i+1])..add(rgba[i+2]);
      }
      pixels[i>>2] = index;
    }
    
    // Pad remaining colorTable entries with zero up to the nearest power of 2.
    for (int bits = 1;; bits++) {
      int colors = 1 << bits;
      if (colors * 3 >= colorTable.length) {
        while (colorTable.length < colors * 3) {
          colorTable..add(0);
        }
        colorBits = bits;
        break;
      }
    }
  }
  
  int get numColors {
    return colorTable.length ~/ 3;
  }
      
  /**
   * Converts the image into an uncompressed GIF, represented as a list of bytes.
   * Throws an exception if the image has more than 128 colors.
   */
  Uint8List encodeUncompressedGif() {
    return new Uint8List.fromList(
        _header(width, height, colorBits)
        ..addAll(colorTable)
        ..addAll(_startImage(0, 0, width, height))
        ..addAll(_sevenBitPixels(pixels))
        ..addAll(_trailer()));
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


