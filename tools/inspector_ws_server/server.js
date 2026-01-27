const http = require('http');
const path = require('path');
const fs = require('fs');
const WebSocket = require('ws');

const HOST = process.env.HOST || '0.0.0.0';
const PORT = Number(process.env.PORT || 7071);
const PUBLIC_DIR = path.join(__dirname, 'public');

const server = http.createServer((req, res) => {
  const urlPath = req.url === '/' ? '/index.html' : req.url;
  const filePath = path.join(PUBLIC_DIR, urlPath);

  if (!filePath.startsWith(PUBLIC_DIR)) {
    res.writeHead(403);
    res.end('Forbidden');
    return;
  }

  fs.readFile(filePath, (err, data) => {
    if (err) {
      res.writeHead(404);
      res.end('Not found');
      return;
    }

    const ext = path.extname(filePath);
    const contentType = {
      '.html': 'text/html; charset=utf-8',
      '.js': 'text/javascript; charset=utf-8',
      '.css': 'text/css; charset=utf-8',
      '.svg': 'image/svg+xml',
      '.png': 'image/png',
    }[ext] || 'application/octet-stream';

    res.writeHead(200, { 'Content-Type': contentType });
    res.end(data);
  });
});

const wss = new WebSocket.Server({ server });
let lastSnapshot = null;

function broadcast(payload) {
  const data = JSON.stringify(payload);
  wss.clients.forEach((client) => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(data);
    }
  });
}

wss.on('connection', (socket) => {
  if (lastSnapshot) {
    socket.send(JSON.stringify(lastSnapshot));
  }

  socket.on('message', (raw) => {
    let message;
    try {
      message = JSON.parse(raw.toString());
    } catch (_) {
      return;
    }

    if (!message || typeof message.type !== 'string') {
      return;
    }

    if (message.type === 'snapshot') {
      lastSnapshot = message;
      broadcast(message);
      return;
    }

    if (message.type === 'command') {
      broadcast(message);
    }
  });
});

server.listen(PORT, HOST, () => {
  console.log(`Inspector WS server running at http://${HOST}:${PORT}`);
});
