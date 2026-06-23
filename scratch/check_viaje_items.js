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
    const viajes = await getJson('https://suwcqdlxnmfcvmlnzizl.supabase.co/rest/v1/viajes?viaje_codigo=eq.V-1105-925');
    console.log('Viajes found:', viajes);
    if (!viajes || viajes.length === 0) return;
    const viajeId = viajes[0].id;
    console.log('Viaje ID:', viajeId);

    const paradas = await getJson(`https://suwcqdlxnmfcvmlnzizl.supabase.co/rest/v1/paradas?viaje_id=eq.${viajeId}&select=*,parada_items(*),remitos(*)`);
    console.log('--- PARADAS & ITEMS & REMITOS ---');
    console.log(JSON.stringify(paradas, null, 2));
  } catch (e) {
    console.error('Error:', e);
  }
}

main();
