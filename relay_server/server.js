const http = require("http");
const { WebSocketServer } = require("ws");

const PORT = process.env.PORT || 9090;
const rooms = new Map(); // roomCode -> Map<peerId, ws>

// Helper to broadcast JSON or Buffer to peers in a room
function broadcast(room, data, excludeId = null) {
  for (const [pid, sock] of room) {
    if (pid !== excludeId && sock.readyState === 1) {
      sock.send(data);
    }
  }
}

// HTTP Health Check Server (Render compatibility)
const httpServer = http.createServer((req, res) => {
  if (req.url === "/health" || req.url === "/") {
    let playerCount = 0;
    rooms.forEach(r => playerCount += r.size);
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ status: "ok", rooms: rooms.size, players: playerCount, uptime: Math.floor(process.uptime()) }));
  } else {
    res.writeHead(404);
    res.end("Not found");
  }
});

const wss = new WebSocketServer({ server: httpServer });

wss.on("connection", (ws, req) => {
  const match = req.url.match(/^\/room\/([A-Z0-9]{4,8})$/i);
  if (!match) return ws.close(4000, "Invalid URL. Use /room/CODE");

  const roomCode = match[1].toUpperCase();
  if (!rooms.has(roomCode)) rooms.set(roomCode, new Map());
  const room = rooms.get(roomCode);

  // Assign peer ID: 1 for host, 2000-99999 for clients
  let peerId = room.size === 0 ? 1 : 0;
  while (!peerId || room.has(peerId)) {
    peerId = 2000 + Math.floor(Math.random() * 90000);
  }

  room.set(peerId, ws);
  ws._peerId = peerId;
  ws._roomCode = roomCode;

  console.log(`[Room ${roomCode}] Peer ${peerId} joined (${room.size} total)`);

  // Send initial room setup to newly connected peer
  ws.send(JSON.stringify({
    type: "init",
    your_id: peerId,
    peers: Array.from(room.keys()),
    is_host: peerId === 1
  }));

  // Notify existing peers in the room
  broadcast(room, JSON.stringify({ type: "peer_joined", peer_id: peerId }), peerId);

  // Relay messages to room peers
  ws.on("message", data => broadcast(room, data, ws._peerId));

  ws.on("close", () => {
    const room = rooms.get(ws._roomCode);
    if (!room) return;

    room.delete(ws._peerId);
    console.log(`[Room ${ws._roomCode}] Peer ${ws._peerId} left (${room.size} remaining)`);

    broadcast(room, JSON.stringify({ type: "peer_left", peer_id: ws._peerId }));

    if (room.size === 0) {
      rooms.delete(ws._roomCode);
      console.log(`[Room ${ws._roomCode}] Room closed`);
    }
  });

  ws.on("error", err => console.error(`[Room ${ws._roomCode}] Peer ${ws._peerId} error:`, err.message));
});

httpServer.listen(PORT, () => console.log(`[Relay] Listening on port ${PORT}`));
