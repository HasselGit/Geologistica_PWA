const https = require('https');

const url = 'https://suwcqdlxnmfcvmlnzizl.supabase.co/rest/v1/solicitudes?select=id,apicultor_id,apicultores(nombre,localidad)&id=in.(7b0fb6cd-7e20-48a5-bcd8-c775e8278b6b,767e6fa6-13ae-4f1d-96bc-4698c3474f3e)';
const options = {
  headers: {
    'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
    'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o'
  }
};

https.get(url, options, (res) => {
  let data = '';
  res.on('data', (chunk) => { data += chunk; });
  res.on('end', () => {
    try {
      const rows = JSON.parse(data);
      console.log('--- BATCH SOLICITUDES SAMPLE ---');
      console.log(JSON.stringify(rows, null, 2));
    } catch (e) {
      console.log('Error parsing JSON:', e);
    }
  });
}).on('error', (err) => {
  console.log('HTTP Error:', err);
});
