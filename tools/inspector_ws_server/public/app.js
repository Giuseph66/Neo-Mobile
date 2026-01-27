const statusEl = document.getElementById('status');
const screenInfoEl = document.getElementById('screenInfo');
const metaInfoEl = document.getElementById('metaInfo');
const nodeListEl = document.getElementById('nodeList');
const nodeSearchEl = document.getElementById('nodeSearch');
const searchCountEl = document.getElementById('searchCount');
const canvas = document.getElementById('canvas');
const canvasWrap = document.querySelector('.canvas-wrap');
const fitBtn = document.getElementById('fitBtn');
const clearBtn = document.getElementById('clearBtn');
const ctx = canvas.getContext('2d');
const keyboardPanel = document.getElementById('keyboardPanel');
const keyboardInput = document.getElementById('keyboardInput');
const keyboardSend = document.getElementById('keyboardSend');

let lastSnapshot = null;
let lastFilteredNodes = [];
let keyboardVisible = false;

const COLORS = {
  any: '#60a5fa',
  button: '#22c55e',
  input: '#f97316',
  tappable: '#eab308',
  card: '#a855f7',
  listItem: '#38bdf8',
};

function setStatus(text, ok) {
  statusEl.textContent = text;
  statusEl.classList.toggle('ok', ok);
}

function formatRect(rect) {
  return `${rect.left.toFixed(1)}, ${rect.top.toFixed(1)} · ${rect.width.toFixed(1)} x ${rect.height.toFixed(1)}`;
}

function drawSnapshot(snapshot) {
  if (!snapshot) {
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    return;
  }

  const { screen, nodes, selectedId } = snapshot;
  canvas.width = screen.width;
  canvas.height = screen.height;

  ctx.clearRect(0, 0, canvas.width, canvas.height);

  nodes.forEach((node) => {
    const rect = node.rect;
    const color = COLORS[node.category] || COLORS.any;
    const isSelected = node.id === selectedId;

    ctx.lineWidth = isSelected ? 3 : 1.5;
    ctx.strokeStyle = color;
    ctx.fillStyle = `${color}22`;
    ctx.fillRect(rect.left, rect.top, rect.width, rect.height);
    ctx.strokeRect(rect.left, rect.top, rect.width, rect.height);

    if (node.label || node.widgetType) {
      const label = node.label || node.widgetType;
      ctx.font = '11px ui-sans-serif, system-ui, sans-serif';
      ctx.fillStyle = `${color}dd`;
      const textWidth = ctx.measureText(label).width;
      ctx.fillRect(rect.left, rect.top, textWidth + 6, 16);
      ctx.fillStyle = '#0b0d11';
      ctx.fillText(label, rect.left + 3, rect.top + 12);
    }
  });
}

function updateList(snapshot) {
  if (!snapshot) {
    nodeListEl.innerHTML = '';
    if (searchCountEl) {
      searchCountEl.textContent = '';
    }
    return;
  }

  const query = (nodeSearchEl?.value || '').trim().toLowerCase();
  const filtered = snapshot.nodes.filter((node) => {
    if (!query) return true;
    const haystack = [
      node.label,
      node.widgetType,
      node.id,
      node.packageName,
      node.viewIdResourceName,
      node.category,
    ]
      .filter(Boolean)
      .join(' ')
      .toLowerCase();
    return haystack.includes(query);
  });

  lastFilteredNodes = filtered;
  if (searchCountEl) {
    searchCountEl.textContent = `${filtered.length} / ${snapshot.nodes.length}`;
  }

  nodeListEl.innerHTML = filtered
    .map((node) => {
      const rect = formatRect(node.rect);
      const label = node.label || node.widgetType || node.id;
      return `
        <div class="node-item ${node.id === snapshot.selectedId ? 'selected' : ''}" data-node-id="${node.id}">
          <div class="node-title">${label}</div>
          <div class="node-meta">${node.category} · ${rect}</div>
          <div class="node-meta">class: ${node.widgetType || '-'}</div>
          <div class="node-meta">label: ${node.label || '-'}</div>
          <div class="node-meta">id: ${node.id}</div>
          <div class="node-meta">package: ${node.packageName || '-'}</div>
          <div class="node-meta">resource: ${node.viewIdResourceName || '-'}</div>
          <div class="node-actions">
            <button data-action="tap" data-node-id="${node.id}">Tap</button>
            <button data-action="longpress" data-node-id="${node.id}">Segurar</button>
            <button data-action="drag-left" data-node-id="${node.id}">Arrastar ◀</button>
            <button data-action="drag-right" data-node-id="${node.id}">Arrastar ▶</button>
            <button data-action="select" data-node-id="${node.id}">Selecionar</button>
          </div>
        </div>
      `;
    })
    .join('');
}

function updateMeta(snapshot) {
  if (!snapshot) {
    screenInfoEl.textContent = 'Aguardando snapshot...';
    metaInfoEl.textContent = 'Sem dados ainda.';
    return;
  }

  const screen = snapshot.screen;
  screenInfoEl.textContent = `Tela ${screen.width.toFixed(0)} x ${screen.height.toFixed(0)} (dpr ${screen.pixelRatio.toFixed(2)})`;
  metaInfoEl.textContent = `Nodes: ${snapshot.nodes.length} · Último update: ${new Date(snapshot.timestamp).toLocaleTimeString()}`;
}

function fitCanvas() {
  if (!lastSnapshot) {
    return;
  }
  const { width, height } = lastSnapshot.screen;
  const maxWidth = window.innerWidth - 80;
  const maxHeight = window.innerHeight - 240;
  const scale = Math.min(maxWidth / width, maxHeight / height, 1);

  canvas.style.width = `${width * scale}px`;
  canvas.style.height = `${height * scale}px`;
  if (canvasWrap) {
    canvasWrap.style.width = `${width * scale}px`;
  }
}

function clearSnapshot() {
  lastSnapshot = null;
  drawSnapshot(null);
  updateList(null);
  updateMeta(null);
}

fitBtn.addEventListener('click', fitCanvas);
clearBtn.addEventListener('click', clearSnapshot);
window.addEventListener('resize', fitCanvas);

const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
const socketUrl = `${protocol}//${window.location.host}`;
const socket = new WebSocket(socketUrl);

socket.addEventListener('open', () => setStatus('Conectado', true));
socket.addEventListener('close', () => setStatus('Desconectado', false));
socket.addEventListener('error', () => setStatus('Erro', false));

socket.addEventListener('message', (event) => {
  let payload;
  try {
    payload = JSON.parse(event.data);
  } catch (_) {
    return;
  }

  if (!payload || payload.type !== 'snapshot') {
    return;
  }

  lastSnapshot = payload;
  drawSnapshot(payload);
  updateList(payload);
  updateMeta(payload);
  fitCanvas();
  showKeyboardIfInputSelected();
});

function sendCommand(command) {
  if (socket.readyState !== WebSocket.OPEN) {
    return;
  }
  socket.send(JSON.stringify(command));
}

function setKeyboardVisible(visible) {
  keyboardVisible = visible;
  if (keyboardPanel) {
    keyboardPanel.classList.toggle('show', visible);
  }
}

function showKeyboardIfInputSelected() {
  if (!lastSnapshot) return;
  const selected = lastSnapshot.nodes.find((node) => node.id === lastSnapshot.selectedId);
  if (!selected) {
    setKeyboardVisible(false);
    return;
  }
  const isInput = selected.isTextField || selected.category === 'input';
  setKeyboardVisible(isInput);
}

canvas.addEventListener('click', (event) => {
  if (!lastSnapshot) {
    return;
  }
  const rect = canvas.getBoundingClientRect();
  const scaleX = canvas.width / rect.width;
  const scaleY = canvas.height / rect.height;
  const x = Math.round((event.clientX - rect.left) * scaleX);
  const y = Math.round((event.clientY - rect.top) * scaleY);

  sendCommand({
    type: 'command',
    action: 'tap',
    x,
    y,
    durationMs: 100,
  });
});

function getNodeById(nodeId) {
  if (!lastSnapshot) return null;
  return lastSnapshot.nodes.find((node) => node.id === nodeId) || null;
}

function nodeCenter(node) {
  return {
    x: Math.round(node.rect.left + node.rect.width / 2),
    y: Math.round(node.rect.top + node.rect.height / 2),
  };
}

nodeListEl.addEventListener('click', (event) => {
  const button = event.target.closest('button');
  const item = event.target.closest('.node-item');
  const nodeId = button?.dataset.nodeId || item?.dataset.nodeId;
  if (!nodeId) return;

  const node = getNodeById(nodeId);
  if (!node) return;

  if (button) {
    const action = button.dataset.action;
    const center = nodeCenter(node);
    if (action === 'tap') {
      sendCommand({ type: 'command', action: 'tap', x: center.x, y: center.y, durationMs: 100 });
    } else if (action === 'longpress') {
      sendCommand({ type: 'command', action: 'tap', x: center.x, y: center.y, durationMs: 600 });
    } else if (action === 'drag-left') {
      sendCommand({
        type: 'command',
        action: 'swipe',
        x1: center.x,
        y1: center.y,
        x2: Math.max(0, center.x - 180),
        y2: center.y,
        durationMs: 280,
      });
    } else if (action === 'drag-right') {
      sendCommand({
        type: 'command',
        action: 'swipe',
        x1: center.x,
        y1: center.y,
        x2: center.x + 180,
        y2: center.y,
        durationMs: 280,
      });
    } else if (action === 'select') {
      sendCommand({ type: 'command', action: 'selectNode', nodeId });
    }
    return;
  }

  sendCommand({ type: 'command', action: 'selectNode', nodeId });
});

document.addEventListener('click', (event) => {
  const nav = event.target.closest('.nav-btn');
  if (nav) {
    sendCommand({ type: 'command', action: nav.dataset.action });
    return;
  }

  const dpad = event.target.closest('.dpad-btn');
  if (!dpad || !lastSnapshot) return;

  if (dpad.dataset.action === 'centerTap') {
    const x = Math.round(lastSnapshot.screen.width / 2);
    const y = Math.round(lastSnapshot.screen.height / 2);
    sendCommand({ type: 'command', action: 'tap', x, y, durationMs: 120 });
    return;
  }

  const dir = dpad.dataset.dir;
  const cx = Math.round(lastSnapshot.screen.width / 2);
  const cy = Math.round(lastSnapshot.screen.height / 2);
  const dist = 140;
  let x2 = cx;
  let y2 = cy;
  if (dir === 'up') y2 = Math.max(0, cy - dist);
  if (dir === 'down') y2 = cy + dist;
  if (dir === 'left') x2 = Math.max(0, cx - dist);
  if (dir === 'right') x2 = cx + dist;

  sendCommand({
    type: 'command',
    action: 'swipe',
    x1: cx,
    y1: cy,
    x2,
    y2,
    durationMs: 260,
  });
});

if (nodeSearchEl) {
  nodeSearchEl.addEventListener('input', () => {
    updateList(lastSnapshot);
  });
}

if (keyboardSend && keyboardInput) {
  keyboardSend.addEventListener('click', () => {
    const text = keyboardInput.value.trim();
    if (!text) return;
    sendCommand({ type: 'command', action: 'inputText', text });
  });

  keyboardInput.addEventListener('keydown', (event) => {
    if (event.key === 'Enter') {
      event.preventDefault();
      keyboardSend.click();
    }
  });
}
