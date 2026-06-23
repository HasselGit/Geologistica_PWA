import 'dart:io';

void main() async {
  final content = await File(r'c:\Users\Usuario\Desktop\Geologistica\scratch\results.txt').readAsString();
  final lines = content.split('\n');

  final knownAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o';
  
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.contains('eyJ') && !line.contains(knownAnonKey)) {
      print('Line $i has a different JWT:');
      print(line);
      print('---');
    }
    if (line.toLowerCase().contains('pass') || line.toLowerCase().contains('key') || line.toLowerCase().contains('url') || line.toLowerCase().contains('role')) {
      // Let's print lines that look like a setting or configuration
      if (line.contains('db') || line.contains('postgres') || line.contains('service') || line.contains('secret')) {
        print('Line $i has interesting keywords:');
        print(line);
        print('---');
      }
    }
  }
}
