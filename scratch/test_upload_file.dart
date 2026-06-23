import 'dart:convert';
import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  print('=== TESTING UPLOAD TO GASTOS BUCKET ===');
  try {
    final bytes = utf8.encode('Hello World Gasto Test');
    final fileName = 'test_upload_${DateTime.now().millisecondsSinceEpoch}.txt';
    print('Uploading test file: $fileName to "gastos"...');
    await client.storage.from('gastos').uploadBinary(
      fileName,
      bytes,
      fileOptions: const FileOptions(contentType: 'text/plain'),
    );
    print('✅ Upload to "gastos" bucket SUCCEEDED!');
    
    // Cleanup
    print('Deleting test file...');
    await client.storage.from('gastos').remove([fileName]);
    print('✅ Cleanup SUCCEEDED!');
  } catch (e) {
    print('❌ Failed upload to "gastos": $e');
  }

  print('\n=== TESTING UPLOAD TO REMITOS BUCKET ===');
  try {
    final bytes = utf8.encode('Hello World Remito Test');
    final fileName = 'test_upload_${DateTime.now().millisecondsSinceEpoch}.txt';
    print('Uploading test file: $fileName to "remitos"...');
    await client.storage.from('remitos').uploadBinary(
      fileName,
      bytes,
      fileOptions: const FileOptions(contentType: 'text/plain'),
    );
    print('✅ Upload to "remitos" bucket SUCCEEDED!');
    
    // Cleanup
    print('Deleting test file...');
    await client.storage.from('remitos').remove([fileName]);
    print('✅ Cleanup SUCCEEDED!');
  } catch (e) {
    print('❌ Failed upload to "remitos": $e');
  }
}
