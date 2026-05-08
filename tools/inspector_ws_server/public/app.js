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
let logs = [];
let dragState = null;

const filters = {
  fill: true,
  labels: true,
  layers: true,
  categories: new Set(['any', 'button', 'input', 'tappable', 'card', 'listItem']),
};

function intersects(r1, r2) {
  // Verifica se r2 cobre significativamente r1
  const xOverlap = Math.max(0, Math.min(r1.left + r1.width, r2.left + r2.width) - Math.max(r1.left, r2.left));
  const yOverlap = Math.max(0, Math.min(r1.top + r1.height, r2.top + r2.height) - Math.max(r1.top, r2.top));
  const overlapArea = xOverlap * yOverlap;
  const r1Area = r1.width * r1.height;
  
  // Se r2 cobre mais de 30% de r1 ou r1 está dentro de r2, consideramos sobreposição
  return overlapArea > (r1Area * 0.3);
}

function canvasLogicalPos(event) {
  const r = canvas.getBoundingClientRect();
  return {
    x: (event.clientX - r.left) * (canvas.width  / r.width),
    y: (event.clientY - r.top)  * (canvas.height / r.height),
  };
}

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

function formatRect(rect, dpr) {
  if (dpr && dpr !== 1) {
    const l = (rect.left  / dpr).toFixed(1);
    const t = (rect.top   / dpr).toFixed(1);
    const w = (rect.width / dpr).toFixed(1);
    const h = (rect.height/ dpr).toFixed(1);
    return `${l}, ${t} · ${w} × ${h}px`;
  }
  return `${rect.left.toFixed(1)}, ${rect.top.toFixed(1)} · ${rect.width.toFixed(1)} x ${rect.height.toFixed(1)}`;
}

function drawSnapshot(snapshot, drag) {
  if (!snapshot) {
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    return;
  }

  const { screen, nodes, selectedId } = snapshot;
  const dpr = screen.pixelRatio || 1;
  canvas.width  = screen.width;
  canvas.height = screen.height;

  ctx.fillStyle = '#050608'; // Fundo mais escuro para contraste
  ctx.fillRect(0, 0, canvas.width, canvas.height);

  // Determinar quais nodes estão no "topo" absoluto
  // Um node é "background" apenas se algum node posterior (mais recente) E MAIOR o cobre.
  const nodeStatus = nodes.map((node, i) => {
    let isCovered = false;
    const r1 = node.rect;
    const r1Area = r1.width * r1.height;

    for (let j = i + 1; j < nodes.length; j++) {
      const r2 = nodes[j].rect;
      const r2Area = r2.width * r2.height;

      // Se o próximo componente for maior (ou quase do mesmo tamanho) e houver intersecção significativa
      if (r2Area >= r1Area * 0.8) { 
        const xOverlap = Math.max(0, Math.min(r1.left + r1.width, r2.left + r2.width) - Math.max(r1.left, r2.left));
        const yOverlap = Math.max(0, Math.min(r1.top + r1.height, r2.top + r2.height) - Math.max(r1.top, r2.top));
        if ((xOverlap * yOverlap) > (r1Area * 0.5)) {
          isCovered = true;
          break;
        }
      }
    }
    return { isCovered };
  });

  nodes.forEach((node, i) => {
    const cat = node.category || 'any';
    if (!filters.categories.has(cat)) return;

    const { isCovered } = nodeStatus[i];
    const raw = node.rect;
    const rect = {
      left:   raw.left   / dpr,
      top:    raw.top    / dpr,
      width:  raw.width  / dpr,
      height: raw.height / dpr,
    };

    const color = COLORS[cat] || COLORS.any;
    const isSelected = node.id === selectedId;
    
    // Lógica de Camadas:
    // Se "Layers" estiver ON, componentes cobertos ficam quase invisíveis
    let opacity = 1.0;
    let strokeAlpha = 1.0;
    let fillAlpha = 0.15;
    
    if (filters.layers) {
      if (isCovered) {
        opacity = 0.15; // "Apaga" o fundo
        strokeAlpha = 0.1;
        fillAlpha = 0.02;
      } else {
        opacity = 1.0; // Destaque total para o topo (Modal)
        strokeAlpha = 0.9;
        fillAlpha = 0.3;
      }
    }

    ctx.save();
    ctx.globalAlpha = opacity;
    
    const drawColor = isSelected ? '#ffffff' : (filters.layers && !isCovered ? '#bd93f9' : color);
    ctx.lineWidth = isSelected ? 3 : (filters.layers && !isCovered ? 2.5 : 1);
    ctx.strokeStyle = drawColor;

    if (filters.fill) {
      ctx.fillStyle = `${drawColor}${isSelected ? '66' : Math.floor(fillAlpha * 255).toString(16).padStart(2, '0')}`;
      ctx.fillRect(rect.left, rect.top, rect.width, rect.height);
    }
    
    ctx.strokeRect(rect.left, rect.top, rect.width, rect.height);

    // Labels apenas para o que não está coberto (evita poluição)
    if (filters.labels && (node.label || node.widgetType)) {
      if (!filters.layers || !isCovered || isSelected) {
        const label = node.label || node.widgetType;
        ctx.font = 'bold 10px ui-sans-serif, system-ui, sans-serif';
        const tw = ctx.measureText(label).width;
        
        // Melhoria no espaçamento: centralizar label se o box for largo
        const labelHeight = 16;
        const labelPadding = 6;
        let lx = rect.left;
        
        if (rect.width > tw + labelPadding * 2 + 20) {
          lx = rect.left + (rect.width - (tw + labelPadding * 2)) / 2;
        }
        
        // Garantir que a label não saia do topo da tela
        let ly = rect.top - labelHeight - 2;
        if (ly < 0) ly = rect.top + 2; 

        ctx.fillStyle = drawColor;
        
        // Desenhar fundo da label com cantos arredondados (simplificado com fillRect se preferir, ou Path)
        ctx.beginPath();
        const radius = 4;
        ctx.roundRect(lx, ly, tw + labelPadding * 2, labelHeight, radius);
        ctx.fill();
        
        ctx.fillStyle = '#000000';
        ctx.fillText(label, lx + labelPadding, ly + 11.5);
      }
    }
    ctx.restore();
  });

  // Drag overlay (seta de swipe)
  if (drag) {
    const { x1, y1, x2, y2 } = drag;
    const dx = x2 - x1;
    const dy = y2 - y1;
    const dist = Math.sqrt(dx * dx + dy * dy);
    
    if (dist > 10) {
      const angle = Math.atan2(dy, dx);
      const alen = 15;
      ctx.save();
      ctx.strokeStyle = '#ff79c6';
      ctx.lineWidth = 3;
      ctx.setLineDash([10, 5]);
      ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke();
      
      ctx.setLineDash([]);
      ctx.fillStyle = '#ff79c6';
      ctx.beginPath();
      ctx.moveTo(x2, y2);
      ctx.lineTo(x2 - alen * Math.cos(angle - Math.PI/6), y2 - alen * Math.sin(angle - Math.PI/6));
      ctx.lineTo(x2 - alen * Math.cos(angle + Math.PI/6), y2 - alen * Math.sin(angle + Math.PI/6));
      ctx.closePath(); ctx.fill();
      
      ctx.fillStyle = '#00f3ff';
      ctx.beginPath(); ctx.arc(x1, y1, 8, 0, Math.PI * 2); ctx.fill();
      ctx.restore();
    }
  }
}

function updateList(snapshot) {
  if (!snapshot || !nodeListEl) {
    if (nodeListEl) nodeListEl.innerHTML = '';
    if (searchCountEl) searchCountEl.textContent = '';
    return;
  }

  // Identificador de conteúdo estável (ignorando o timestamp que muda sempre)
  const query = (nodeSearchEl?.value || '').trim().toLowerCase();
  const contentSignature = snapshot.nodes.length > 0 ? 
    `${snapshot.nodes[0].id}_${snapshot.nodes[snapshot.nodes.length-1].id}` : 'empty';
  const renderKey = `sig_${contentSignature}_sel_${snapshot.selectedId}_q_${query}_count_${snapshot.nodes.length}`;
  
  if (window._lastRenderKey === renderKey) return;
  window._lastRenderKey = renderKey;
  
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

  const dpr = snapshot.screen?.pixelRatio || 1;
  nodeListEl.innerHTML = filtered
    .map((node) => {
      const rect = formatRect(node.rect, dpr);
      const color = COLORS[node.category] || COLORS.any;
      const isSelected = node.id === snapshot.selectedId;
      const label = node.label || node.widgetType || 'Component';
      
      return `
        <div class="node-card ${isSelected ? 'selected' : ''}" data-node-id="${node.id}" style="--node-color: ${color}">
          <div class="node-card-header">
            <span class="node-badge" style="background: ${color}">${node.category}</span>
            <span class="node-rect-text">${rect}</span>
          </div>
          <div class="node-card-body">
            <div class="node-main-label">${label}</div>
            ${node.text ? `<div class="node-text-content">"${node.text}"</div>` : ''}
            <div class="node-property"><span>class</span> ${node.widgetType || '-'}</div>
            <div class="node-property"><span>id</span> <small>${node.id}</small></div>
          </div>
          <div class="node-card-actions">
            <button class="btn-action" data-action="tap" data-node-id="${node.id}">Tap</button>
            <button class="btn-action" data-action="longpress" data-node-id="${node.id}">Long</button>
            <button class="btn-action secondary" data-action="select" data-node-id="${node.id}">Select</button>
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
  
  // Usar limites mais generosos. 
  // Em telas grandes, queremos que o canvas ocupe o máximo possível.
  // Em telas pequenas (ou com inspector aberto), ele deve caber.
  const maxWidth = window.innerWidth - 400; // Reservar espaço para os painéis laterais
  const maxHeight = window.innerHeight - 140; // Reduzi o offset vertical para dar mais espaço
  
  // Se a largura disponível for muito pequena (ex: mobile), usar quase toda a largura
  const finalMaxWidth = Math.max(maxWidth, 320);
  
  const scale = Math.min(finalMaxWidth / width, maxHeight / height, 1);

  const displayWidth = width * scale;
  const displayHeight = height * scale;

  canvas.style.width = `${displayWidth}px`;
  canvas.style.height = `${displayHeight}px`;
  
  if (canvasWrap) {
    // Adicionamos o padding do wrap (8px + 8px = 16px) e as bordas
    canvasWrap.style.width = `${displayWidth + 18}px`;
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

  if (!payload || !payload.type) return;

  switch (payload.type) {
    case 'snapshot':
      lastSnapshot = payload;
      drawSnapshot(payload);
      updateList(payload);
      updateMeta(payload);
      fitCanvas();
      showKeyboardIfInputSelected();
      break;

    case 'log':
      appendLog(payload);
      break;

    case 'logs_history':
      logs = payload.logs;
      renderLogs();
      break;

    case 'execution_status':
      updateExecutionStatus(payload);
      break;
  }
});

function appendLog(log) {
  logs.push(log);
  if (logs.length > 200) logs.shift();
  renderLogs();
}

function renderLogs() {
  const list = document.getElementById('logList');
  if (!list) return;

  if (logs.length === 0) {
    list.innerHTML = '<div class="log-empty">Nenhum log recebido ainda.</div>';
    return;
  }

  list.innerHTML = logs.map(l => `
    <div class="log-entry ${l.level}">
      <span class="time">${new Date(l.timestamp).toLocaleTimeString()}</span>
      <span class="msg">${l.message}</span>
    </div>
  `).join('');
  list.scrollTop = list.scrollHeight;
}

function updateExecutionStatus(data) {
  const routineEl = document.getElementById('executionRoutine');
  const badgeEl = document.getElementById('executionBadge');
  const progressText = document.getElementById('stepProgressText');
  const progressBar = document.getElementById('stepProgressBar');
  const execLogs = document.getElementById('executionLogs');

  if (routineEl) routineEl.textContent = data.routineName || 'Nenhuma rotina ativa';

  if (badgeEl) {
    badgeEl.className = `badge ${data.status}`;
    badgeEl.textContent = data.status.toUpperCase();
  }

  if (progressText) progressText.textContent = `Em andamento...`;
  if (progressBar) progressBar.style.width = '0%'; // Simples reset
}

// Tab Logic
document.querySelectorAll('.tab-btn').forEach(btn => {
  btn.addEventListener('click', () => {
    const tabId = btn.dataset.tab;
    document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
    document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));

    btn.classList.add('active');
    document.getElementById(`tab-${tabId}`).classList.add('active');

    if (tabId === 'home') fitCanvas();
  });
});

document.getElementById('clearLogsBtn')?.addEventListener('click', () => {
  logs = [];
  renderLogs();
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

canvas.addEventListener('mousedown', (e) => {
  if (!lastSnapshot) return;
  e.preventDefault();
  const pos = canvasLogicalPos(e);
  dragState = { x1: pos.x, y1: pos.y, x2: pos.x, y2: pos.y };
  canvas.style.cursor = 'crosshair';
});

canvas.addEventListener('mousemove', (e) => {
  if (!dragState || !lastSnapshot) return;
  const pos = canvasLogicalPos(e);
  dragState.x2 = pos.x;
  dragState.y2 = pos.y;
  drawSnapshot(lastSnapshot, dragState);
});

canvas.addEventListener('mouseup', (e) => {
  if (!dragState || !lastSnapshot) { dragState = null; return; }
  canvas.style.cursor = 'crosshair';
  const dpr = lastSnapshot.screen.pixelRatio || 1;
  const dx = dragState.x2 - dragState.x1;
  const dy = dragState.y2 - dragState.y1;
  const dist = Math.sqrt(dx * dx + dy * dy);
  if (dist < 8) {
    sendCommand({ type: 'command', action: 'tap',
      x: Math.round(dragState.x2 * dpr), y: Math.round(dragState.y2 * dpr), durationMs: 100 });
  } else {
    sendCommand({ type: 'command', action: 'swipe',
      x1: Math.round(dragState.x1 * dpr), y1: Math.round(dragState.y1 * dpr),
      x2: Math.round(dragState.x2 * dpr), y2: Math.round(dragState.y2 * dpr),
      durationMs: 350 });
  }
  dragState = null;
  drawSnapshot(lastSnapshot);
});

canvas.addEventListener('mouseleave', () => {
  if (dragState && lastSnapshot) drawSnapshot(lastSnapshot);
  dragState = null;
  canvas.style.cursor = '';
});

// Filter chip toggles
document.querySelectorAll('.filter-chip').forEach((chip) => {
  chip.addEventListener('click', () => {
    chip.classList.toggle('active');
    const type = chip.dataset.type;
    const cat  = chip.dataset.cat;
    if (type === 'fill')   filters.fill   = chip.classList.contains('active');
    if (type === 'labels') filters.labels = chip.classList.contains('active');
    if (type === 'layers') filters.layers = chip.classList.contains('active');
    if (cat) {
      if (chip.classList.contains('active')) filters.categories.add(cat);
      else filters.categories.delete(cat);
    }
    if (lastSnapshot) drawSnapshot(lastSnapshot);
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
  const card = event.target.closest('.node-card');
  const nodeId = button?.dataset.nodeId || card?.dataset.nodeId;
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
      const isAlreadySelected = (lastSnapshot && lastSnapshot.selectedId === nodeId);
      sendCommand({ type: 'command', action: 'selectNode', nodeId: isAlreadySelected ? null : nodeId });
    }
    return;
  }

  const isAlreadySelected = (lastSnapshot && lastSnapshot.selectedId === nodeId);
  sendCommand({ type: 'command', action: 'selectNode', nodeId: isAlreadySelected ? null : nodeId });
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
