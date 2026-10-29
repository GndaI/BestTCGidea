const http = require("http");
const fs = require("fs");
const path = require("path");
const { WebSocketServer, WebSocket } = require("ws");

const PORT = Number(process.env.PORT || 8000);
const WEB_ROOT = path.resolve(__dirname, "..", "build", "web");
const ROOM_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const rooms = new Map();

const Message = {
  JOIN: 0,
  ID: 1,
  PEER_CONNECT: 2,
  PEER_DISCONNECT: 3,
  OFFER: 4,
  ANSWER: 5,
  CANDIDATE: 6,
  SEAL: 7,
  RELAY: 8,
};

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".wasm": "application/wasm",
  ".pck": "application/octet-stream",
  ".png": "image/png",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
};

function send(ws, type, id = 0, data = "") {
  if (ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify({ type, id, data }));
  }
}

function roomCode() {
  do {
    let code = "";
    for (let i = 0; i < 6; i += 1) {
      code += ROOM_CHARS[Math.floor(Math.random() * ROOM_CHARS.length)];
    }
    if (!rooms.has(code)) return code;
  } while (true);
}

function publicRoomList() {
  return Array.from(rooms.entries())
    .filter(([, room]) => room.isPublic)
    .sort((a, b) => a[1].createdAt - b[1].createdAt)
    .map(([code, room]) => ({
      code,
      name: room.name,
      players: room.peers.size,
      capacity: 2,
      status: room.sealed || room.peers.size >= 2 ? "playing" : "waiting",
    }));
}

function leave(ws) {
  if (!ws.roomCode) return;
  const room = rooms.get(ws.roomCode);
  if (!room) return;
  room.peers.delete(ws.peerId);
  for (const [id, peer] of room.peers) {
    send(peer, Message.PEER_DISCONNECT, ws.peerId);
    if (ws.peerId === 1) {
      peer.close(4001, "방장이 나가 방이 닫혔습니다.");
    }
  }
  if (ws.peerId === 1 || room.peers.size === 0) rooms.delete(ws.roomCode);
  ws.roomCode = "";
}

function join(ws, requested) {
  if (ws.roomCode) return;
  const options = requested && typeof requested === "object" ? requested : { code: requested };
  const code = String(options.code || "").trim().toUpperCase();
  if (!code) {
    const created = roomCode();
    const cleanName = String(options.name || "").trim().slice(0, 20);
    rooms.set(created, {
      peers: new Map([[1, ws]]),
      isPublic: Boolean(options.public),
      name: cleanName || "이름 없는 방",
      sealed: false,
      createdAt: Date.now(),
    });
    ws.roomCode = created;
    ws.peerId = 1;
    send(ws, Message.ID, 1);
    send(ws, Message.JOIN, 0, created);
    console.log(`[방 생성] ${created}`);
    return;
  }
  const room = rooms.get(code);
  if (!room) {
    ws.close(4004, "방 코드를 찾을 수 없습니다.");
    return;
  }
  if (room.sealed || room.peers.size >= 2) {
    ws.close(4009, "이미 두 명이 들어간 방입니다.");
    return;
  }
  ws.roomCode = code;
  ws.peerId = 2;
  send(ws, Message.ID, 2);
  room.peers.set(2, ws);
  for (const [id, peer] of room.peers) {
    if (id === 2) continue;
    send(peer, Message.PEER_CONNECT, 2);
    send(ws, Message.PEER_CONNECT, id);
  }
  send(ws, Message.JOIN, 0, code);
  console.log(`[방 참가] ${code}`);
}

const server = http.createServer((req, res) => {
  const rawPath = new URL(req.url, `http://${req.headers.host || "localhost"}`).pathname;
  if (req.method === "GET" && rawPath === "/health") {
    res.writeHead(200, {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
    });
    res.end(JSON.stringify({ ok: true, service: "TWELVE room server" }));
    return;
  }
  if (req.method === "GET" && rawPath === "/rooms") {
    res.writeHead(200, {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
    });
    res.end(JSON.stringify({ rooms: publicRoomList(), refreshedAt: Date.now() }));
    return;
  }
  const relative = rawPath === "/" ? "index.html" : decodeURIComponent(rawPath.slice(1));
  const filePath = path.resolve(WEB_ROOT, relative);
  if (!filePath.startsWith(WEB_ROOT + path.sep) && filePath !== path.join(WEB_ROOT, "index.html")) {
    res.writeHead(403).end("Forbidden");
    return;
  }
  fs.stat(filePath, (statError, stat) => {
    if (statError || !stat.isFile()) {
      res.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" }).end("Not found");
      return;
    }
    res.writeHead(200, {
      "Content-Type": MIME[path.extname(filePath).toLowerCase()] || "application/octet-stream",
      "Cache-Control": "no-store",
    });
    fs.createReadStream(filePath).pipe(res);
  });
});

const wss = new WebSocketServer({ noServer: true, maxPayload: 2 * 1024 * 1024 });
server.on("upgrade", (req, socket, head) => {
  if (new URL(req.url, "http://localhost").pathname !== "/signal") {
    socket.destroy();
    return;
  }
  wss.handleUpgrade(req, socket, head, (ws) => wss.emit("connection", ws));
});

wss.on("connection", (ws) => {
  ws.roomCode = "";
  ws.peerId = 0;
  ws.on("message", (buffer, isBinary) => {
    if (isBinary) return;
    let message;
    try {
      message = JSON.parse(buffer.toString("utf8"));
    } catch {
      return;
    }
    const type = Number(message.type);
    if (type === Message.JOIN) {
      join(ws, message.data);
      return;
    }
    const room = rooms.get(ws.roomCode);
    if (type === Message.SEAL && room && ws.peerId === 1) {
      room.sealed = true;
      return;
    }
    const target = room && room.peers.get(Number(message.id));
    if (target && type === Message.RELAY && message.data && typeof message.data === "object") {
      send(target, Message.RELAY, ws.peerId, message.data);
      return;
    }
    if (target && [Message.OFFER, Message.ANSWER, Message.CANDIDATE].includes(type)) {
      send(target, type, ws.peerId, message.data);
    }
  });
  ws.on("close", () => leave(ws));
  ws.on("error", () => leave(ws));
});

server.listen(PORT, "0.0.0.0", () => {
  console.log(`게임 주소: http://127.0.0.1:${PORT}`);
  console.log("친구가 같은 와이파이라면 127.0.0.1 대신 이 컴퓨터의 IPv4 주소를 사용하세요.");
});
