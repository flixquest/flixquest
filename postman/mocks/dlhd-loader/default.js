// Catalog shape: openapi.json. Token flow and wrappers: the observed
// dembed.st/premiumtv/daddy.php?id=110 LiveLoader (2026-10-21).
// Synthetic TS packets test transport adaptation, not audiovisual decoding.
const http = require('http');
const zlib = require('zlib');
const origin = process.env.DLHD_SIM_ORIGIN || 'http://127.0.0.1:4931';
const ts = Buffer.alloc(188 * 3, 1);
for (let offset = 0; offset < ts.length; offset += 188) ts[offset] = 0x47;
http.createServer((req, res) => {
  const url = new URL(req.url, origin);
  const send = (status, body, type = 'application/json') => {
    const data = Buffer.isBuffer(body) ? body
      : Buffer.from(typeof body === 'string' ? body : JSON.stringify(body));
    res.writeHead(status, {'Content-Type': type, 'Content-Length': data.length, 'Cache-Control': 'no-store'});
    res.end(data);
  };
  if (url.pathname === '/api/v2/dlhd/channels') {
    return send(200, {success: true, source: 'dlhd', count: 1,
      channels: [{id: '110', name: 'DLHD loader fixture', watchUrl: origin + '/watch.php?id=110'}]});
  }
  if (url.pathname === '/watch.php') {
    return send(200, `<button class="player-btn" title="PLAYER 1" data-url="${origin}/embed"></button>
<button class="player-btn" title="PLAYER 2" data-url="${origin}/backup-2"></button>
<button class="player-btn" title="PLAYER 3" data-url="${origin}/backup-3"></button>`, 'text/html');
  }
  if (url.pathname === '/backup-2' || url.pathname === '/backup-3') {
    const reply = () => send(200, `const source = "${origin}/backup-media/index.m3u8";`, 'text/html');
    if (url.pathname === '/backup-2') return setTimeout(reply, 400);
    return reply();
  }
  if (url.pathname === '/backup-media/index.m3u8') {
    return send(200, '#EXTM3U\n#EXTINF:6,\nsegment.ts\n', 'application/vnd.apple.mpegurl');
  }
  if (url.pathname === '/backup-media/segment.ts') return send(200, ts, 'video/mp2t');
  if (url.pathname === '/embed') {
    return send(200, `const SRC = "${origin}/premium110/index.m3u8";
const EDGE = "${origin}";
const CHANNEL = "premium110";
function fetchPlaylistToken() { fetch(EDGE + '/api/playlist-token?slug=' + CHANNEL); }
class LiveLoader {}`, 'text/html');
  }
  if (url.pathname === '/api/playlist-token') {
    if (url.searchParams.get('slug') !== 'premium110') return send(400, {error: 'Invalid slug'});
    return send(200, {token: 'fixture-viewer-token', ttl: 120});
  }
  if (url.pathname === '/premium110/index.m3u8') {
    if (url.searchParams.get('t') !== 'fixture-viewer-token') return send(403, {error: 'Missing viewer token'});
    return send(200, '#EXTM3U\n#EXT-X-TARGETDURATION:6\n#EXT-X-MEDIA-SEQUENCE:0\n'
      + '#EXTINF:6,\none.png\n#EXTINF:6,\ntwo.png\n#EXTINF:6,\nthree.png\n', 'application/vnd.apple.mpegurl');
  }
  if (/^\/premium110\/(one|two|three)\.png$/.test(url.pathname)) {
    return send(200, Buffer.concat([Buffer.from('TIKTIKTSGZ'), zlib.gzipSync(ts)]), 'image/png');
  }
  return send(501, {error: 'Endpoint not modeled'});
}).listen(process.env.PORT);
