import 'dart:io';

void main() {
  final file = File('assets/images/logo_Geologistica_Verde.png');
  final bytes = file.readAsBytesSync();
  print('Read ${bytes.length} bytes.');
  
  // PNG signature
  if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
    print('Valid PNG');
    int offset = 8;
    while (offset < bytes.length) {
      int length = (bytes[offset] << 24) | (bytes[offset + 1] << 16) | (bytes[offset + 2] << 8) | bytes[offset + 3];
      String type = String.fromCharCodes(bytes.sublist(offset + 4, offset + 8));
      if (type == 'bKGD') {
        print('Found background chunk: bKGD');
        print(bytes.sublist(offset + 8, offset + 8 + length));
      }
      offset += 12 + length;
    }
  } else {
    print('Not a valid PNG');
  }
}
