const { spawn } = require("child_process");
const http = require("http");
const path = require("path");
const { WebSocket } = require(path.resolve(__dirname, "..", "server", "node_modules", "ws"));

const port = 24831;
const serverPath = path.resolve(__dirname, "..", "server", "room_server.js");
const server = spawn(process.execPath, [serverPath], {
  env: { ...process.env, PORT: String(port) },
  stdio: ["ignore", "pipe", "pipe"],
});

const Message = { JOIN: 0, ID: 1, PEER_CONNECT: 2, SEAL: 7, RELAY: 8 };
const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

function openClient() {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(`ws://127.0.0.1:${port}/signal`);
    ws.once("open", () => resolve(ws));
    ws.once("error", reject);
  });
}

function nextMessage(ws, predicate) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      ws.off("message", onMessage);
      reject(new Error("message timeout"));
    }, 3000);
    function onMessage(buffer) {
      const message = JSON.parse(buffer.toString("utf8"));
      if (!predicate(message)) return;
      clearTimeout(timer);
      ws.off("message", onMessage);
      resolve(message);
    }
    ws.on("message", onMessage);
  });
}

function getRooms() {
  return new Promise((resolve, reject) => {
    http.get(`http://127.0.0.1:${port}/rooms`, (response) => {
      let body = "";
      response.setEncoding("utf8");
      response.on("data", (chunk) => { body += chunk; });
      response.on("end", () => resolve(JSON.parse(body).rooms));
    }).on("error", reject);
  });
}

async function run() {
  await wait(250);
  const host = await openClient();
  host.send(JSON.stringify({ type: Message.JOIN, id: 0, data: { code: "", public: true, name: "중계 시험방" } }));
  const hostId = await nextMessage(host, (message) => message.type === Message.ID);
  const hostJoin = await nextMessage(host, (message) => message.type === Message.JOIN);
  if (hostId.id !== 1 || !hostJoin.data) throw new Error("host room creation failed");

  const guest = await openClient();
  const hostPeerPromise = nextMessage(host, (message) => message.type === Message.PEER_CONNECT);
  guest.send(JSON.stringify({ type: Message.JOIN, id: 0, data: hostJoin.data }));
  const guestId = await nextMessage(guest, (message) => message.type === Message.ID);
  const guestPeer = await nextMessage(guest, (message) => message.type === Message.PEER_CONNECT);
  const hostPeer = await hostPeerPromise;
  if (guestId.id !== 2 || guestPeer.id !== 1 || hostPeer.id !== 2) throw new Error("peer assignment failed");

  const toGuest = nextMessage(guest, (message) => message.type === Message.RELAY);
  host.send(JSON.stringify({ type: Message.RELAY, id: 2, data: { kind: "state", payload: { turn: 3 } } }));
  const guestRelay = await toGuest;
  if (guestRelay.id !== 1 || guestRelay.data.payload.turn !== 3) throw new Error("host relay failed");

  const toHost = nextMessage(host, (message) => message.type === Message.RELAY);
  guest.send(JSON.stringify({ type: Message.RELAY, id: 1, data: { kind: "intent", payload: { type: "pass" } } }));
  const hostRelay = await toHost;
  if (hostRelay.id !== 2 || hostRelay.data.payload.type !== "pass") throw new Error("guest relay failed");

  host.send(JSON.stringify({ type: Message.SEAL, id: 0, data: "" }));
  await wait(50);
  const rooms = await getRooms();
  if (rooms.length !== 1 || rooms[0].status !== "playing" || rooms[0].players !== 2) throw new Error("room status failed");

  host.close();
  guest.close();
  console.log("ROOM RELAY CHECKS: create, join, list, seal, two-way relay | FAILURES: 0");
}

run().then(() => {
  server.kill();
}).catch((error) => {
  server.kill();
  console.error(error.stack || error);
  process.exitCode = 1;
});
