const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 3000;
const ROOT = __dirname;

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js':   'application/javascript; charset=utf-8',
  '.css':  'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png':  'image/png',
  '.jpg':  'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.webp': 'image/webp',
  '.gif':  'image/gif',
  '.svg':  'image/svg+xml',
  '.mp3':  'audio/mpeg',
  '.wav':  'audio/wav',
  '.ico':  'image/x-icon',
  '.woff': 'font/woff',
  '.woff2':'font/woff2',
  '.ttf':  'font/ttf',
  '.map':  'application/json',
  '.atlas':'text/plain; charset=utf-8'
};

const server = http.createServer((req, res) => {
  let urlPath = decodeURIComponent(req.url.split('?')[0]);

  // Main page
  if (urlPath === '/') {
    urlPath = '/index.html';
  }

  // RailOps2026: redirect directory to entry html
  if (urlPath === '/RailOps2026' || urlPath === '/RailOps2026/') {
    res.writeHead(302, { Location: '/RailOps2026/game/RailOps2026.html' });
    res.end();
    return;
  }

  // RhythmGame2026: redirect directory to entry html
  if (urlPath === '/RhythmGame2026' || urlPath === '/RhythmGame2026/') {
    res.writeHead(302, { Location: '/RhythmGame2026/game/RhythmGame2026.html' });
    res.end();
    return;
  }

  // MidAutumn2026: redirect directory to entry html
  if (urlPath === '/MidAutumn2026' || urlPath === '/MidAutumn2026/') {
    res.writeHead(302, { Location: '/MidAutumn2026/game/MidAutumn2026.html' });
    res.end();
    return;
  }

  // Anniversary2025: redirect directory to entry html
  if (urlPath === '/Anniversary2025' || urlPath === '/Anniversary2025/') {
    res.writeHead(302, { Location: '/Anniversary2025/game/Anniversary2025.html' });
    res.end();
    return;
  }

  let filePath;

  if (urlPath.startsWith('/RailOps2026/')) {
    let subPath = urlPath.substring('/RailOps2026/'.length);
    subPath = subPath.replace(/\/assets\/assets\//g, '/assets/');
    filePath = path.join(ROOT, 'RailOps2026', subPath);
  } else if (urlPath.startsWith('/RhythmGame2026/')) {
    const subPath = urlPath.substring('/RhythmGame2026/'.length);
    filePath = path.join(ROOT, 'RhythmGame2026', subPath);
  } else if (urlPath.startsWith('/Anniversary2025/')) {
    const subPath = urlPath.substring('/Anniversary2025/'.length);
    filePath = path.join(ROOT, 'Anniversary2025', subPath);
  } else if (urlPath.startsWith('/MidAutumn2026/')) {
    const subPath = urlPath.substring('/MidAutumn2026/'.length);
    filePath = path.join(ROOT, 'MidAutumn2026', subPath);
  } else {
    filePath = path.join(ROOT, urlPath);
  }

  const ext = path.extname(filePath).toLowerCase();
  const mime = MIME[ext] || 'application/octet-stream';

  const resolved = path.resolve(filePath);
  if (!resolved.startsWith(path.resolve(ROOT))) {
    res.writeHead(403); res.end('Forbidden'); return;
  }

  fs.readFile(filePath, (err, data) => {
    if (err) {
      res.writeHead(404);
      res.end('Not Found: ' + urlPath);
      console.log('404:', urlPath);
      return;
    }
    res.writeHead(200, {
      'Content-Type': mime,
      'Access-Control-Allow-Origin': '*',
      'Cache-Control': 'no-store, must-revalidate'
    });
    res.end(data);
    if (['.webp', '.png', '.mp3', '.jpg', '.jpeg', '.ttf'].indexOf(ext) === -1) {
      console.log('200:', urlPath, '(' + mime + ')');
    }
  });
});

server.listen(PORT, () => {
  console.log('================================');
  console.log('Blue Archive Web Games server started!');
  console.log('URL: http://localhost:' + PORT + '/');
  console.log('  RailOps2026:    http://localhost:' + PORT + '/RailOps2026/');
  console.log('  RhythmGame2026: http://localhost:' + PORT + '/RhythmGame2026/');
  console.log('  Anniversary2025: http://localhost:' + PORT + '/Anniversary2025/');
  console.log('  MidAutumn2026:  http://localhost:' + PORT + '/MidAutumn2026/');
  console.log('Root:', ROOT);
  console.log('Press Ctrl+C to stop');
  console.log('================================');
});
