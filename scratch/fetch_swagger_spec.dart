import 'dart:convert';
import 'dart:io';

void main() async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse('https://suwcqdlxnmfcvmlnzizl.supabase.co/rest/v1/'));
    request.headers.add('apikey', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o');
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    
    final Map<String, dynamic> spec = jsonDecode(responseBody);
    final paths = spec['paths'] as Map<String, dynamic>? ?? {};
    final definitions = spec['definitions'] as Map<String, dynamic>? ?? {};

    print('--- Endpoints / Tables Exponentiados ---');
    for (var key in paths.keys) {
      if (key != '/') {
        print('Path: $key');
      }
    }
    
    print('\n--- Definitions / Schemas ---');
    for (var key in definitions.keys) {
      print('Definition: $key');
    }
  } catch (e) {
    print('Error: $e');
  } finally {
    client.close();
  }
}
