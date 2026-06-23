const https = require('https');

const apikey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o';
const options = {
  headers: {
    'apikey': apikey,
    'Authorization': `Bearer ${apikey}`
  }
};

function getJson(url) {
  return new Promise((resolve, reject) => {
    https.get(url, options, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          reject(e);
        }
      });
    }).on('error', reject);
  });
}

async function main() {
  try {
    const solicitudes = await getJson('https://suwcqdlxnmfcvmlnzizl.supabase.co/rest/v1/solicitudes?select=*');
    console.log('--- ALL SOLICITUDES (Count: ' + solicitudes.length + ') ---');
    // Filter to ones that contain Walter, Carlos Salceda, Mariano, Vidal, Olavarria, or America
    const filtered = solicitudes.filter(s => {
      const code = s.solicitud_codigo || '';
      return code.includes('REM') || s.estado === 'Terminada';
    });
    console.log(JSON.stringify(filtered, null, 2));
  } catch (e) {
    console.error('Error:', e);
  }
}

main();
