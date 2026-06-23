import 'dart:convert';
import 'dart:io';

void main() async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse('https://suwcqdlxnmfcvmlnzizl.supabase.co/rest/v1/'));
    request.headers.add('apikey', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o');
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    
    // Save to a scratch file so we can read it easily
    final file = File('scratch/swagger_raw.json');
    await file.writeAsString(responseBody);
    print('Raw swagger spec length: ${responseBody.length} saved to scratch/swagger_raw.json');
  } catch (e) {
    print('Error: $e');
  } finally {
    client.close();
  }
}
