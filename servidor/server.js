// Servidor de encontro do Sinuca/Truco GoScripts.
// Faz só três coisas: fila para achar oponente, lista de amigos (quem está online) e
// repassar as mensagens da partida entre os dois celulares. As regras rodam no celular.
// Sem dependências: WebSocket implementado direto sobre o módulo http do Node.
"use strict";
const http = require("http");
const crypto = require("crypto");

const PORT = process.env.PORT || 10000;
const clients = new Map(); // code -> client
const queues = { sinuca: [], truco: [], sinuca4: [], truco4: [] };
const GAMES = ["sinuca", "truco", "sinuca4", "truco4"];
const FILL_AFTER = 40000; // 2x2: depois de 40 s completa a mesa com a IA
let nextRoom = 1;
let nextParty = 1;
// mensagens de amizade para quem está offline (em memória; os celulares também reenviam ao conectar)
const mailbox = new Map(); // code -> [{kind, from, name}]
// cadastro de todos os jogadores que já entraram (para achar pelo nome mesmo offline)
const fs = require("fs");
const DATA_FILE = process.env.DATA_FILE || __dirname + "/dados.json";
const players = new Map(); // code -> {name, seen}
try {
  const d = JSON.parse(fs.readFileSync(DATA_FILE, "utf8"));
  for (const [k, v] of d.players || []) players.set(k, v);
  for (const [k, v] of d.mailbox || []) mailbox.set(k, v);
  console.log("cadastro carregado: " + players.size + " jogadores");
} catch (e) {}
let saveTimer = null;
function saveSoon() {
  if (saveTimer) return;
  saveTimer = setTimeout(() => {
    saveTimer = null;
    const d = JSON.stringify({ players: [...players], mailbox: [...mailbox] });
    fs.writeFile(DATA_FILE + ".tmp", d, (err) => { if (!err) fs.rename(DATA_FILE + ".tmp", DATA_FILE, () => {}); });
  }, 3000);
}
function remember(c) {
  if (!c.code) return;
  players.set(c.code, { name: c.name, seen: Date.now() });
  if (players.size > 100000) { // limpa os mais antigos
    const old = [...players].sort((a, b) => a[1].seen - b[1].seen).slice(0, 10000);
    for (const [k] of old) players.delete(k);
  }
  saveSoon();
}

// ------------------------------------------------------------ WebSocket mínimo
function accept(req, socket) {
  const key = req.headers["sec-websocket-key"];
  if (!key) return socket.destroy();
  const acc = crypto.createHash("sha1").update(key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").digest("base64");
  socket.write("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: " + acc + "\r\n\r\n");
  socket.setNoDelay(true);
  const c = { socket, buf: Buffer.alloc(0), code: null, name: "", status: "online", room: null, peer: 0, alive: true, frag: null, fragOp: 0 };
  socket.on("data", (d) => onData(c, d));
  socket.on("close", () => drop(c));
  socket.on("error", () => drop(c));
}

function frame(op, payload) {
  const len = payload.length;
  let head;
  if (len < 126) { head = Buffer.alloc(2); head[1] = len; }
  else if (len < 65536) { head = Buffer.alloc(4); head[1] = 126; head.writeUInt16BE(len, 2); }
  else { head = Buffer.alloc(10); head[1] = 127; head.writeBigUInt64BE(BigInt(len), 2); }
  head[0] = 0x80 | op;
  return Buffer.concat([head, payload]);
}

function sendRaw(c, op, payload) {
  if (!c.socket.destroyed) c.socket.write(frame(op, payload));
}
function sendJ(c, obj) { sendRaw(c, 1, Buffer.from(JSON.stringify(obj))); }

function onData(c, d) {
  c.buf = Buffer.concat([c.buf, d]);
  while (c.buf.length >= 2) {
    const b0 = c.buf[0], b1 = c.buf[1];
    const fin = (b0 & 0x80) !== 0, op = b0 & 0x0f, masked = (b1 & 0x80) !== 0;
    let len = b1 & 0x7f, off = 2;
    if (len === 126) { if (c.buf.length < 4) return; len = c.buf.readUInt16BE(2); off = 4; }
    else if (len === 127) { if (c.buf.length < 10) return; len = Number(c.buf.readBigUInt64BE(2)); off = 10; }
    if (len > 1 << 20) return c.socket.destroy();
    const need = off + (masked ? 4 : 0) + len;
    if (c.buf.length < need) return;
    let payload = c.buf.subarray(off + (masked ? 4 : 0), need);
    if (masked) {
      const m = c.buf.subarray(off, off + 4);
      payload = Buffer.from(payload);
      for (let i = 0; i < payload.length; i++) payload[i] ^= m[i & 3];
    }
    c.buf = c.buf.subarray(need);
    c.alive = true;
    if (op === 8) { sendRaw(c, 8, Buffer.alloc(0)); c.socket.end(); return; }
    if (op === 9) { sendRaw(c, 10, payload); continue; }
    if (op === 10) continue;
    if (op === 0) { // continuação
      if (!c.frag) continue;
      c.frag = Buffer.concat([c.frag, payload]);
      if (fin) { const f = c.frag, fo = c.fragOp; c.frag = null; onMsg(c, fo, f); }
      continue;
    }
    if (!fin) { c.frag = Buffer.from(payload); c.fragOp = op; continue; }
    onMsg(c, op, payload);
  }
}

// ------------------------------------------------------------ lógica
function onMsg(c, op, payload) {
  if (op === 2) return relay(c, payload);
  let m;
  try { m = JSON.parse(payload.toString("utf8")); } catch (e) { return; }
  switch (m.t) {
    case "hello": {
      const code = String(m.code || "").toUpperCase().slice(0, 8);
      if (!/^[A-Z0-9]{4,8}$/.test(code)) return sendJ(c, { t: "error", msg: "código inválido" });
      const old = clients.get(code);
      if (old && old !== c) drop(old);
      c.code = code;
      c.name = String(m.name || "Jogador").slice(0, 15);
      clients.set(code, c);
      remember(c);
      sendJ(c, { t: "welcome", code, online: clients.size });
      const box = mailbox.get(code);
      if (box) {
        mailbox.delete(code);
        saveSoon();
        for (const x of box) sendJ(c, { t: "fmsg", kind: x.kind, from: x.from, name: x.name });
      }
      break;
    }
    case "queue": {
      if (!c.code || c.room) return;
      const g = GAMES.includes(m.game) ? m.game : "sinuca";
      const p = c.party;
      if (p && p.leader !== c) return; // no lobby só o líder procura
      unqueue(c);
      if (p) {
        p.game = g.replace("4", "");
        p.four = g.endsWith("4");
        if (!p.four) {
          // 1x1 com a dupla do lobby: joga um contra o outro
          if (p.members.length === 2) { const ms = p.members.slice(); endParty(p); matchN(ms, g); return; }
          sendLobby(p, "No 1 contra 1 o lobby precisa ter só 2 jogadores.");
          return;
        }
      }
      setStatus(c, "procurando");
      c.qsince = Date.now();
      queues[g] = queues[g].filter((o) => !o.room && clients.get(o.code) === o);
      queues[g].push(c);
      if (p) sendLobby(p);
      if (g.endsWith("4")) tryTable(g, false);
      else if (queues[g].length >= 2) matchN(queues[g].splice(0, 2), g);
      break;
    }
    case "unqueue": {
      if (c.party && c.party.leader !== c) break;
      unqueue(c); setStatus(c, "online");
      if (c.party) sendLobby(c.party);
      break;
    }
    case "lleave": leaveParty(c); break;
    case "lcreate": { // cria um lobby de amigos (sem procurar partida ainda)
      if (!c.code || c.room) return;
      unqueue(c); setStatus(c, "online");
      const game = m.game === "truco" ? "truco" : "sinuca";
      if (c.party && c.party.leader === c) {
        if (!m.four && c.party.members.length > 2) return sendLobby(c.party, "1 contra 1 é só com 2 no lobby.");
        c.party.game = game; c.party.four = !!m.four;
        return sendLobby(c.party);
      }
      leaveParty(c);
      const p = { id: nextParty++, leader: c, members: [c], game, four: !!m.four };
      c.party = p;
      sendLobby(p, "Lobby criado! Chame seus amigos.");
      break;
    }
    case "lstart": { // líder começa já: só com quem está no lobby, a IA completa os lugares vazios
      const p = c.party;
      if (!p || p.leader !== c || c.room) break;
      unqueue(c);
      if (!p.four) {
        if (p.members.length !== 2) return sendLobby(p, "Para o 1 contra 1 precisa ter 2 no lobby.");
        const ms = p.members.slice();
        matchN(ms, p.game);
        break;
      }
      if (p.members.length < 2) return sendLobby(p, "Chame pelo menos 1 amigo para jogar junto.");
      matchSeats(seatUnits([c]), p.game + "4");
      break;
    }
    case "lset": { // líder trocou jogo/mesa no lobby (sem procurar ainda)
      const p = c.party;
      if (!p || p.leader !== c) break;
      unqueue(c); setStatus(c, "online");
      p.game = m.game === "truco" ? "truco" : "sinuca";
      p.four = !!m.four;
      sendLobby(p);
      break;
    }
    case "friends": {
      const list = (m.codes || []).slice(0, 100).map((code) => {
        const f = clients.get(String(code).toUpperCase());
        return f ? { code: f.code, name: f.name, online: true, status: f.room ? "jogando" : f.status } : { code: String(code).toUpperCase(), online: false };
      });
      sendJ(c, { t: "presence", list });
      break;
    }
    case "search": {
      const q = norm(String(m.q || "")).slice(0, 16);
      if (q.length < 2) return sendJ(c, { t: "search", q: m.q, list: [] });
      const list = [];
      for (const f of clients.values()) {
        if (f === c) continue;
        if (norm(f.name).includes(q)) list.push({ code: f.code, name: f.name, online: true, status: f.room ? "jogando" : f.status });
        if (list.length >= 20) break;
      }
      // quem está offline também aparece (do cadastro), os vistos há menos tempo primeiro
      if (list.length < 20) {
        const off = [];
        for (const [code, p] of players) {
          if (code === c.code || clients.has(code)) continue;
          if (norm(p.name).includes(q)) off.push({ code, name: p.name, online: false, status: "offline", seen: p.seen });
        }
        off.sort((a, b) => b.seen - a.seen);
        for (const o of off.slice(0, 20 - list.length)) list.push(o);
      }
      sendJ(c, { t: "search", q: m.q, list });
      break;
    }
    case "fsend": {
      // pedidos de amizade: req (pedido), acc (aceitou), dec (recusou), rem (desfez)
      const kind = String(m.kind || "");
      if (!["req", "acc", "dec", "rem"].includes(kind) || !c.code) return;
      const f = clients.get(String(m.to || "").toUpperCase());
      const to = String(m.to || "").toUpperCase();
      if (f && f !== c) sendJ(f, { t: "fmsg", kind, from: c.code, name: c.name });
      else if (/^[A-Z0-9]{4,8}$/.test(to) && to !== c.code) {
        const box = (mailbox.get(to) || []).filter((x) => x.from !== c.code);
        box.push({ kind, from: c.code, name: c.name });
        if (box.length > 50) box.shift();
        saveSoon();
        mailbox.set(to, box);
      }
      sendJ(c, { t: "fsent", kind, to: String(m.to || "").toUpperCase(), delivered: !!(f && f !== c) });
      break;
    }
    case "invite": {
      const f = clients.get(String(m.code || "").toUpperCase());
      if (!f || f === c) return sendJ(c, { t: "invite_fail", msg: "Amigo offline" });
      if (f.room) return sendJ(c, { t: "invite_fail", msg: "Amigo está jogando" });
      if (m.lobby && c.party && c.party.members.length >= (c.party.four ? 4 : 2)) return sendJ(c, { t: "invite_fail", msg: "O lobby já está cheio" });
      sendJ(f, { t: "invited", from: c.code, name: c.name, game: m.game === "truco" ? "truco" : "sinuca", lobby: !!m.lobby });
      sendJ(c, { t: "invite_ok", name: f.name, lobby: !!m.lobby });
      break;
    }
    case "accept": {
      const f = clients.get(String(m.from || "").toUpperCase());
      if (!f || f.room || c.room) return sendJ(c, { t: "invite_fail", msg: "Convite expirou" });
      if (m.lobby) {
        // entra no lobby de quem convidou (cria se ainda não existe)
        if (c.party && c.party === f.party) return sendLobby(c.party);
        leaveParty(c);
        unqueue(c); setStatus(c, "online");
        let p = f.party;
        if (!p) {
          p = { id: nextParty++, leader: f, members: [f], game: m.game === "truco" ? "truco" : "sinuca", four: true };
          f.party = p;
        }
        if (p.members.length >= (p.four ? 4 : 2)) return sendJ(c, { t: "invite_fail", msg: "O lobby já está cheio" });
        p.members.push(c);
        c.party = p;
        // se o líder estava numa fila 1x1, para a busca (o lobby é para 2x2)
        const lq = queueOf(p.leader);
        if (lq && !lq.endsWith("4")) { unqueue(p.leader); setStatus(p.leader, "online"); }
        // a contagem da IA começa quando o 2º jogador real chega (aqui, o amigo)
        if (lq && lq.endsWith("4")) p.leader.qsince = Date.now();
        sendLobby(p, c.name + " entrou no lobby!");
        if (lq && lq.endsWith("4")) tryTable(lq, false);
        break;
      }
      leaveParty(f); leaveParty(c);
      unqueue(f); unqueue(c);
      matchN([f, c], m.game === "truco" ? "truco" : "sinuca");
      break;
    }
    case "decline": {
      const f = clients.get(String(m.from || "").toUpperCase());
      if (f) sendJ(f, { t: "invite_fail", msg: c.name + " recusou o convite" });
      break;
    }
    case "leave": leaveRoom(c); break;
    case "ping": sendJ(c, { t: "pong" }); break;
  }
}

function norm(t) {
  return t.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "").trim();
}

// sala com 2 a 4 jogadores; o primeiro é o anfitrião (peer 1), os outros são 2, 3, 4
function matchN(list, game) { matchSeats(list, game); }

// seats[i] = jogador no lugar i (ou null = IA). Lugar i usa peer i+1; times: 0 e 2 contra 1 e 3
function matchSeats(seats, game) {
  const list = seats.filter((p) => p);
  if (seats[0] == null) { // o lugar 0 (anfitrião) precisa ser gente
    const i = seats.findIndex((p) => p);
    [seats[0], seats[i]] = [seats[i], seats[0]];
  }
  for (const p of list) { unqueue(p); if (p.party) endParty(p.party); }
  const room = { id: nextRoom++, members: list.slice(), game, seats: game.endsWith("4") ? 4 : 2 };
  const players = [];
  seats.forEach((p, i) => { if (p) { p.room = room; p.peer = i + 1; p.status = "jogando"; players.push({ peer: i + 1, name: p.name, code: p.code }); } });
  for (const p of list) {
    const opp = list.find((o) => o !== p) || p;
    sendJ(p, { t: "match", role: p.peer === 1 ? "host" : "guest", peer: p.peer, game, seats: room.seats, players, opp: { name: opp.name, code: opp.code } });
  }
}

// ------------------------------------------------------------ lobby (grupo de amigos)
function unitSize(u) { return u.party ? u.party.members.length : 1; }
function unitMembers(u) { return u.party ? u.party.members.slice() : [u]; }

function setStatus(c, st) {
  for (const o of unitMembers(c)) if (!o.room) o.status = st;
}

function queueOf(c) {
  for (const g of Object.keys(queues)) if (queues[g].includes(c)) return g;
  return null;
}

function sendLobby(p, msg) {
  const q = queueOf(p.leader);
  const d = {
    t: "lobby", leader: p.leader.code, game: p.game, four: p.four, searching: !!q,
    members: p.members.map((o) => ({ code: o.code, name: o.name })), msg: msg || "",
  };
  for (const o of p.members) sendJ(o, d);
}

function endParty(p) {
  for (const o of p.members) if (o.party === p) o.party = null;
  p.members = [];
}

function leaveParty(c) {
  const p = c.party;
  if (!p) return;
  const wasLeader = p.leader === c;
  const q = queueOf(p.leader);
  p.members = p.members.filter((o) => o !== c);
  c.party = null;
  if (!c.dropped) sendJ(c, { t: "lobby", members: [], leader: "", msg: "" });
  if (wasLeader && q) unqueue(c);
  if (wasLeader) {
    // o dono saiu: o lobby acaba para todos e cada um fica livre para procurar sozinho
    const rest = p.members.slice();
    endParty(p);
    for (const o of rest) {
      if (!o.room) o.status = "online";
      sendJ(o, { t: "lobby", members: [], leader: "", msg: "O dono do lobby (" + c.name + ") saiu. O lobby foi fechado." });
    }
    return;
  }
  // um convidado saiu: o lobby continua (mesmo que fique só o dono)
  sendLobby(p, c.name + " saiu do lobby.");
}

// monta a primeira mesa possível com a fila (grupos do lobby ficam juntos e no mesmo time)
function candidate(g) {
  const out = [];
  let total = 0, start = -1;
  for (const u of queues[g]) {
    const n = unitSize(u);
    if (total + n > 4) continue;
    out.push(u);
    total += n;
    if (start < 0 && total >= 2) start = u.qsince;
    if (total === 4) break;
  }
  return { units: out, total, start };
}

function seatUnits(units) {
  const seats = [null, null, null, null];
  const sorted = units.slice().sort((a, b) => unitSize(b) - unitSize(a));
  for (const u of sorted) {
    const ms = unitMembers(u);
    if (ms.length >= 3) { // líder e o 1º amigo juntos; o resto do outro lado
      [0, 2, 1, 3].forEach((s, i) => { if (ms[i]) seats[s] = ms[i]; });
    } else if (ms.length === 2) {
      const pair = seats[0] == null && seats[2] == null ? [0, 2] : [1, 3];
      seats[pair[0]] = ms[0]; seats[pair[1]] = ms[1];
    } else {
      const s = [0, 1, 2, 3].find((k) => seats[k] == null);
      seats[s] = ms[0];
    }
  }
  return seats;
}

function tryTable(g, timed) {
  queues[g] = queues[g].filter((o) => !o.room && clients.get(o.code) === o);
  const cand = candidate(g);
  const ready = cand.total === 4 || (timed && cand.total >= 2 && Date.now() - cand.start >= FILL_AFTER);
  if (ready) {
    queues[g] = queues[g].filter((u) => !cand.units.includes(u));
    matchSeats(seatUnits(cand.units), g);
    return tryTable(g, timed);
  }
  sendWaiting(g);
}

// pacote da partida: [1 byte destino][dados]; destino 0 = todos. O servidor troca o destino pela origem
function relay(c, payload) {
  const r = c.room;
  if (!r || payload.length < 1) return;
  const dest = payload[0];
  const out = Buffer.from(payload);
  out[0] = c.peer;
  for (const p of r.members) {
    if (p !== c && (dest === 0 || p.peer === dest)) sendRaw(p, 2, out);
  }
}

function leaveRoom(c) {
  const r = c.room;
  if (!r) return;
  const wasHost = c.peer === 1;
  r.members = r.members.filter((p) => p !== c);
  const left = c.peer;
  c.room = null; c.peer = 0; c.status = "online";
  if (wasHost || r.members.length < 2 && r.seats === 2 || r.members.length < 1) {
    // sem anfitrião (ou 1x1 sem adversário): a partida acaba para todos
    for (const p of r.members) {
      p.room = null; p.peer = 0; p.status = "online";
      if (!p.socket.destroyed) sendJ(p, { t: "peer_left", peer: left, end: true });
    }
    r.members = [];
    return;
  }
  // 2x2: os outros continuam (o anfitrião coloca a IA no lugar)
  for (const p of r.members) if (!p.socket.destroyed) sendJ(p, { t: "peer_left", peer: left, end: false });
}

function sendWaiting(g) {
  const q = queues[g];
  if (!q.length) return;
  const cand = candidate(g);
  const left = cand.total >= 2 ? Math.max(0, FILL_AFTER - (Date.now() - cand.start)) : -1;
  for (const u of q) {
    const inC = cand.units.includes(u);
    for (const o of unitMembers(u)) sendJ(o, { t: "waiting", have: inC ? cand.total : unitSize(u), need: 4, left: inC ? left : -1 });
  }
}

// 2x2 com pouca gente: depois de um tempo, completa a mesa com a IA
setInterval(() => {
  for (const g of ["sinuca4", "truco4"]) {
    tryTable(g, true);
  }
}, 2000);

function unqueue(c) {
  for (const g of Object.keys(queues)) queues[g] = queues[g].filter((o) => o !== c);
}

function drop(c) {
  if (c.dropped) return;
  c.dropped = true;
  unqueue(c);
  leaveParty(c);
  leaveRoom(c);
  if (c.code && clients.get(c.code) === c) remember(c);
  if (c.code && clients.get(c.code) === c) clients.delete(c.code);
  try { c.socket.destroy(); } catch (e) {}
}

// derruba conexões mortas
setInterval(() => {
  for (const c of clients.values()) {
    if (!c.alive) { drop(c); continue; }
    c.alive = false;
    sendRaw(c, 9, Buffer.alloc(0));
  }
}, 30000);

const server = http.createServer((req, res) => {
  res.writeHead(200, { "Content-Type": "text/plain; charset=utf-8" });
  res.end("Servidor Sinuca/Truco GoScripts no ar. Jogadores online: " + clients.size + "\n");
});
server.on("upgrade", (req, socket) => accept(req, socket));
server.listen(PORT, () => console.log("ouvindo na porta " + PORT));
