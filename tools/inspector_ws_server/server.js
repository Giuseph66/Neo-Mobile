const http = require('http');
const path = require('path');
const fs = require('fs');
const WebSocket = require('ws');
const os = require('os');
const https = require('https');

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
let logs = [];
let executionStatus = { status: 'idle', currentStep: -1, routineName: '' };

function broadcast(payload) {
  const data = JSON.stringify(payload);
  wss.clients.forEach((client) => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(data);
    }
  });
}

wss.on('connection', (ws, req) => {
  const ip = req.socket.remoteAddress;
  console.log(`[SERVER] Nova conexão recebida de: ${ip}`);

  if (lastSnapshot) {
    ws.send(JSON.stringify(lastSnapshot));
  }

  // Enviar estado atual ao conectar
  ws.send(JSON.stringify({ type: 'logs_history', logs }));
  ws.send(JSON.stringify({ type: 'execution_status', ...executionStatus }));

  ws.on('message', (raw) => {
    let message;
    try {
      message = JSON.parse(raw.toString());
      console.log(`[SERVER] Mensagem recebida tipo: ${message.type}`);
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

    if (message.type === 'log') {
      const logEntry = {
        timestamp: new Date().toISOString(),
        message: message.message,
        level: message.level || 'info'
      };
      logs.push(logEntry);
      if (logs.length > 200) logs.shift(); // Manter últimos 200 logs
      broadcast({ type: 'log', ...logEntry });
      return;
    }

    if (message.type === 'execution_status') {
      executionStatus = {
        status: message.status,
        currentStep: message.currentStep,
        routineName: message.routineName
      };
      broadcast(message);
      return;
    }

    if (message.type === 'command') {
      console.log(`[SERVER] Enviando comando: ${message.action}`);
      broadcast(message);
    }
  });

  ws.on('error', (err) => {
    console.error(`[SERVER] Erro na conexão com ${ip}:`, err.message);
  });

  ws.on('close', () => {
    console.log(`[SERVER] Conexão encerrada com ${ip}`);
  });
});

function getPrivateIP() {
  const interfaces = os.networkInterfaces();
  for (const devName in interfaces) {
    const iface = interfaces[devName];
    for (let i = 0; i < iface.length; i++) {
      const alias = iface[i];
      if (alias.family === 'IPv4' && alias.address !== '127.0.0.1' && !alias.internal) {
        return alias.address;
      }
    }
  }
  return '0.0.0.0';
}

function getPublicIP() {
  return new Promise((resolve) => {
    const options = {
      hostname: 'api.ipify.org',
      port: 443,
      path: '/?format=json',
      method: 'GET',
      timeout: 3000
    };
    const req = https.get(options, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(data).ip);
        } catch (e) {
          resolve('Não disponível');
        }
      });
    });
    req.on('error', () => resolve('Não disponível'));
    req.on('timeout', () => {
      req.destroy();
      resolve('Timeout');
    });
  });
}

server.listen(PORT, HOST, async () => {
  const privateIP = getPrivateIP();
  console.log(`\n[SERVER] Inspector WS server running:`);
  console.log(`  - Local:   http://localhost:${PORT}`);
  console.log(`  - Privado: http://${privateIP}:${PORT}`);
  
  const publicIP = await getPublicIP();
  console.log(`  - Público: http://${publicIP}:${PORT}\n`);
});
