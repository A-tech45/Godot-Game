const http = require("http");
const { WebSocketServer } = require("ws");

const PORT = process.env.PORT || 9090;
const rooms = new Map(); // roomCode -> Map<peerId, ws>

// Create HTTP server with health check endpoint (required by Render)
const httpServer = http.createServer((req, res) => {
  if (req.url === "/health" || req.url === "/") {
    const roomCount = rooms.size;
    let playerCount = 0;
    for (const room of rooms.values()) {
      playerCount += room.size;
    }
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({
      status: "ok",
      rooms: roomCount,
      players: playerCount,
      uptime: Math.floor(process.uptime())
    }));
  } else {
    res.writeHead(404);
    res.end("Not found");
  }
});

// Attach WebSocket server to the HTTP server
const wss = new WebSocketServer({ server: httpServer });

wss.on("connection", (ws, req) => {
  // Expect URL: /room/ABCDEF
  const match = req.url.match(/^\/room\/([A-Z0-9]{4,8})$/i);
  if (!match) {
    ws.close(4000, "Invalid URL. Use /room/CODE");
    return;
  }

  const roomCode = match[1].toUpperCase();

  // Get or create room
  if (!rooms.has(roomCode)) {
    rooms.set(roomCode, new Map());
  }
  const room = rooms.get(roomCode);

  // Assign peer ID: first peer = 1 (host), others get unique IDs
  let peerId;
  if (room.size === 0) {
    peerId = 1;
  } else {
    // Generate a unique ID that doesn't collide
    do {
      peerId = 2000 + Math.floor(Math.random() * 90000);
    } while (room.has(peerId));
  }

  room.set(peerId, ws);
  ws._peerId = peerId;
  ws._roomCode = roomCode;

  console.log(`[Room ${roomCode}] Peer ${peerId} joined (${room.size} total)`);

  // Send this peer its assigned ID and the current peer list
  const peerList = Array.from(room.keys());
  ws.send(JSON.stringify({
    type: "init",
    your_id: peerId,
    peers: peerList,
    is_host: peerId === 1
  }));

  // Notify existing peers that a new peer joined
  for (const [pid, sock] of room) {
    if (pid !== peerId && sock.readyState === 1) {
      sock.send(JSON.stringify({
        type: "peer_joined",
        peer_id: peerId
      }));
    }
  }

  // Forward messages to other peers in the same room
  ws.on("message", (data) => {
    const room = rooms.get(ws._roomCode);
    if (!room) return;

    for (const [pid, sock] of room) {
      if (pid !== ws._peerId && sock.readyState === 1) {
        sock.send(data);
      }
    }
  });

  ws.on("close", () => {
    const room = rooms.get(ws._roomCode);
    if (!room) return;

    room.delete(ws._peerId);
    console.log(`[Room ${ws._roomCode}] Peer ${ws._peerId} left (${room.size} remaining)`);

    // Notify remaining peers
    for (const [pid, sock] of room) {
      if (sock.readyState === 1) {
        sock.send(JSON.stringify({
          type: "peer_left",
          peer_id: ws._peerId
        }));
      }
    }

    // Clean up empty rooms
    if (room.size === 0) {
      rooms.delete(ws._roomCode);
      console.log(`[Room ${ws._roomCode}] Room closed (empty)`);
    }
  });

  ws.on("error", (err) => {
    console.error(`[Room ${ws._roomCode}] Peer ${ws._peerId} error:`, err.message);
  });
});

httpServer.listen(PORT, () => {
  console.log(`[Relay] Listening on port ${PORT}`);
});
