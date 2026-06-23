import 'dart:io';
import 'package:image/image.dart';

void main() {
  final file = File('assets/images/logo_Geologistica_Verde.png');
  final original = decodeImage(file.readAsBytesSync())!;
  
  // Calculate new size (e.g. 1.6x the original size to give plenty of padding)
  int newWidth = (original.width * 1.5).round();
  int newHeight = (original.height * 1.5).round();
  
  // Create a new canvas filled with the background color (#F6F7F2 = 246, 247, 242)
  final canvas = Image(width: newWidth, height: newHeight);
  // Fill with color
  for (int y = 0; y < canvas.height; y++) {
    for (int x = 0; x < canvas.width; x++) {
      canvas.setPixelRgba(x, y, 246, 247, 242, 255);
    }
  }
  
  // Draw the original image in the center
  int dstX = (newWidth - original.width) ~/ 2;
  int dstY = (newHeight - original.height) ~/ 2;
  compositeImage(canvas, original, dstX: dstX, dstY: dstY);
  
  // Save the new image
  final outFile = File('assets/images/logo_padded.png');
  outFile.writeAsBytesSync(encodePng(canvas));
  print('Padded image saved to assets/images/logo_padded.png');
}
