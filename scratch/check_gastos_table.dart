import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  print('--- Checking gastos table metadata and content ---');
  try {
    final res = await client.from('gastos').select().limit(1);
    print('Query succeeded! Found ${res.length} rows.');
    if (res.isNotEmpty) {
      print('Row keys: ${res.first.keys}');
      print('Row data: ${res.first}');
    } else {
      print('gastos table is empty.');
    }
  } catch (e) {
    print('Error querying gastos table: $e');
  }

  // Let's also check if we can query the 'gastos' storage bucket or inspect it
  try {
    print('\n--- Listing storage buckets ---');
    final buckets = await client.storage.listBuckets();
    for (var b in buckets) {
      print('Bucket: ${b.id}, Public: ${b.public}');
    }
  } catch (e) {
    print('Error listing storage buckets: $e');
  }
}
