import 'dart:io';
import 'package:image/image.dart';

void main() {
  final file = File('assets/images/logo_Geologistica_Verde.png');
  final img = decodeImage(file.readAsBytesSync())!;
  
  // Resize to 40x40 to print as ascii
  final small = copyResize(img, width: 40, height: 40);
  
  for (int y = 0; y < small.height; y++) {
    String row = '';
    for (int x = 0; x < small.width; x++) {
      final p = small.getPixel(x, y);
      final r = p.r;
      final g = p.g;
      final b = p.b;
      
      // Classify color
      if (r > 240 && g > 240 && b > 240) {
        row += '.'; // Cream/White
      } else if (r < 50 && g < 50 && b < 50) {
        row += '#'; // Dark green / Black
      } else if (r > 150 && g > 100 && b < 100) {
        row += '*'; // Gold/Yellow
      } else {
        row += '?'; // Other
      }
    }
    print(row);
  }
}
