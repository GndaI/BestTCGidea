const http = require("http");

const port = Number(process.env.PORT || 24833);
let stored = null;

const server = http.createServer((req, res) => {
  res.setHeader("Content-Type", "application/json; charset=utf-8");
  if (req.headers.authorization !== "Bearer test-token") {
    res.writeHead(401).end(JSON.stringify({ message: "unauthorized" }));
    return;
  }
  if (req.method === "GET" && req.url === "/api/decks") {
    res.writeHead(200).end(JSON.stringify({ exists: stored !== null, decks: stored || [] }));
    return;
  }
  if (req.method === "PUT" && req.url === "/api/decks") {
    let body = "";
    req.on("data", (chunk) => { body += chunk; });
    req.on("end", () => {
      stored = JSON.parse(body).decks;
      res.writeHead(200).end(JSON.stringify({ ok: true, decks: stored }));
    });
    return;
  }
  res.writeHead(404).end(JSON.stringify({ message: "not found" }));
});

server.listen(port, "127.0.0.1", () => console.log(`FAKE CLOUD DECK SERVER: ${port}`));
