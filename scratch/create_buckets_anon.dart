import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  print('=== CREATING BUCKETS VIA API ===');
  try {
    print('Creating bucket "gastos"...');
    await client.storage.createBucket('gastos', const BucketOptions(public: true));
    print('✅ Bucket "gastos" created!');
  } catch (e) {
    print('❌ Failed to create "gastos": $e');
  }

  try {
    print('Creating bucket "remitos"...');
    await client.storage.createBucket('remitos', const BucketOptions(public: true));
    print('✅ Bucket "remitos" created!');
  } catch (e) {
    print('❌ Failed to create "remitos": $e');
  }
}
