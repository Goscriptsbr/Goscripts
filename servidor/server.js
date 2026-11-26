// Servidor de encontro do Sinuca/Truco GoScripts.
// Faz só três coisas: fila para achar oponente, lista de amigos (quem está online) e
// repassar as mensagens da partida entre os dois celulares. As regras rodam no celular.
// Sem dependências: WebSocket implementado direto sobre o módulo http do Node.
"use strict";
const http = require("http");
const crypto = require("crypto");
const https = require("https");

const PORT = process.env.PORT || 10000;
const clients = new Map(); // code -> client
const queues = { sinuca: [], truco: [], sinuca4: [], truco4: [] };
const GAMES = ["sinuca", "truco", "sinuca4", "truco4"];
// apostas (moedas do jogo): cada fila é separada pelo valor, para só juntar quem apostou igual
const STAKES = [0, 50, 100, 500, 1000];
function stakeOf(v) { v = Number(v) || 0; return STAKES.includes(v) ? v : 0; }
function qkey(g, stake) { return stake ? g + "$" + stake : g; }
function gameOf(k) { return String(k).split("$")[0]; }
function stakeOfKey(k) { return Number(String(k).split("$")[1] || 0); }
function poor(list, stake) { return stake ? list.find((o) => (o.coins || 0) < stake) : null; }
const FILL_AFTER = 40000; // 2x2: depois de 40 s completa a mesa com a IA
let nextRoom = 1;
let nextParty = 1;
// mensagens de amizade para quem está offline (em memória; os celulares também reenviam ao conectar)
const mailbox = new Map(); // code -> [{kind, from, name}]
// cadastro de todos os jogadores que já entraram (para achar pelo nome mesmo offline)
const fs = require("fs");
const DATA_FILE = process.env.DATA_FILE || __dirname + "/dados.json";
const players = new Map(); // code -> {name, seen, wk, pts, prof}
const playersDir = players;
const saves = new Map(); // (modo arquivo) code -> {tok, pass, save, at, gsub, gmail}
const gIndex = new Map(); // conta Google (sub) -> código do jogador
let reports = []; // denúncias de jogadores (o dono vê dentro do jogo)
const OWNER_CODE = "LP34RB";
try {
  const d = JSON.parse(fs.readFileSync(DATA_FILE, "utf8"));
  for (const [k, v] of d.players || []) players.set(k, v);
  for (const [k, v] of d.mailbox || []) mailbox.set(k, v);
  for (const [k, v] of d.saves || []) { saves.set(k, v); if (v && v.gsub) gIndex.set(v.gsub, k); }
  if (Array.isArray(d.reports)) reports = d.reports;
  console.log("cadastro carregado: " + players.size + " jogadores");
} catch (e) {}

// ------------------------------------------------------------ Supabase (projeto SÓ do jogo)
// Com SUPABASE_URL e SUPABASE_KEY (chave service_role) no ambiente da Render, o cadastro, o ranking,
// os recados e os saves na nuvem ficam no banco e não somem mais quando o servidor reinicia.
// Sem essas variáveis, continua tudo no arquivo (como antes).
const SB_URL = (process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const SB_KEY = process.env.SUPABASE_KEY || "";
const SB = !!(SB_URL && SB_KEY);
let sbReady = !SB;
function sb(method, path, body, extra) {
  return new Promise((resolve) => {
    let u;
    try { u = new URL(SB_URL + "/rest/v1/" + path); } catch (e) { return resolve({ status: 0, json: null }); }
    const lib = u.protocol === "http:" ? http : https;
    const data = body == null ? null : Buffer.from(JSON.stringify(body));
    const headers = Object.assign({ apikey: SB_KEY, Authorization: "Bearer " + SB_KEY, "Content-Type": "application/json" }, extra || {});
    if (data) headers["Content-Length"] = data.length;
    const rq = lib.request(u, { method, headers, timeout: 15000 }, (r) => {
      let b = "";
      r.setEncoding("utf8");
      r.on("data", (x) => { b += x; });
      r.on("end", () => {
        let j = null;
        try { j = b ? JSON.parse(b) : null; } catch (e) {}
        if (r.statusCode >= 300) console.log("supabase " + method + " " + path.split("?")[0] + " -> " + r.statusCode + " " + b.slice(0, 200));
        resolve({ status: r.statusCode, json: j });
      });
    });
    rq.on("error", (e) => { console.log("supabase erro: " + e.message); resolve({ status: 0, json: null }); });
    rq.on("timeout", () => rq.destroy(new Error("timeout")));
    if (data) rq.write(data);
    rq.end();
  });
}
const lastPl = new Map(); // code -> json já gravado (para mandar só o que mudou)
const lastMb = new Set();
async function sbLoad() {
  let n = 0;
  for (let off = 0; off < 200000; off += 1000) {
    const r = await sb("GET", "sinucou_players?select=code,data&order=code&limit=1000&offset=" + off);
    if (r.status !== 200 || !Array.isArray(r.json)) { if (off === 0) { console.log("supabase: não consegui carregar (vou tentar de novo)"); return false; } break; }
    for (const row of r.json) {
      const cur = players.get(row.code);
      const v = row.data || {};
      // o que já chegou neste meio tempo (jogador conectou) vale mais que o do banco
      players.set(row.code, cur ? Object.assign({}, v, cur) : v);
      lastPl.set(row.code, JSON.stringify(v));
      n++;
    }
    if (r.json.length < 1000) break;
  }
  const mb = await sb("GET", "sinucou_mailbox?select=code,msgs&limit=10000");
  if (mb.status === 200 && Array.isArray(mb.json)) {
    for (const row of mb.json) {
      if (!mailbox.has(row.code)) mailbox.set(row.code, row.msgs || []);
      lastMb.add(row.code);
    }
  }
  console.log("supabase: " + n + " jogadores carregados");
  return true;
}
if (SB) {
  (async () => {
    for (let i = 0; i < 20 && !(await sbLoad()); i++) await new Promise((r) => setTimeout(r, 5000));
    sbReady = true;
    saveSoon();
  })();
}
let sbBusy = false;
async function sbFlush() {
  if (!sbReady || sbBusy) return;
  sbBusy = true;
  try {
    const rows = [];
    for (const [code, v] of players) {
      const j = JSON.stringify(v);
      if (lastPl.get(code) !== j) rows.push({ code, data: v, j });
    }
    for (let i = 0; i < rows.length; i += 500) {
      const part = rows.slice(i, i + 500);
      const r = await sb("POST", "sinucou_players?on_conflict=code", part.map((x) => ({ code: x.code, data: x.data, updated_at: new Date().toISOString() })), { Prefer: "resolution=merge-duplicates,return=minimal" });
      if (r.status >= 200 && r.status < 300) for (const x of part) lastPl.set(x.code, x.j);
    }
    const mrows = [...mailbox].map(([code, msgs]) => ({ code, msgs }));
    if (mrows.length) {
      const r = await sb("POST", "sinucou_mailbox?on_conflict=code", mrows, { Prefer: "resolution=merge-duplicates,return=minimal" });
      if (r.status >= 200 && r.status < 300) for (const x of mrows) lastMb.add(x.code);
    }
    const gone = [...lastMb].filter((k) => !mailbox.has(k));
    if (gone.length) {
      const r = await sb("DELETE", "sinucou_mailbox?code=in.(" + gone.map((k) => encodeURIComponent(k)).join(",") + ")", null, { Prefer: "return=minimal" });
      if (r.status >= 200 && r.status < 300) for (const k of gone) lastMb.delete(k);
    }
  } finally {
    sbBusy = false;
  }
}

// saves na nuvem: guarda moedas, itens e progresso de cada celular (protegido por um "token" do aparelho)
async function getSave(code) {
  if (!SB) return saves.get(code) || null;
  const r = await sb("GET", "sinucou_saves?select=code,tok,pass,save,eco&code=eq." + encodeURIComponent(code));
  if (r.status !== 200 || !Array.isArray(r.json)) return undefined; // undefined = erro (não sobrescrever)
  return r.json[0] || null;
}
async function putSave(code, row) {
  if (!SB) { saves.set(code, Object.assign({}, saves.get(code) || {}, row, { at: Date.now() })); saveSoon(); return true; }
  const rec = { code, updated_at: new Date().toISOString() };
  for (const k of ["tok", "pass", "save", "eco"]) if (row[k] !== undefined) rec[k] = row[k];
  const r = await sb("POST", "sinucou_saves?on_conflict=code", [rec], { Prefer: "resolution=merge-duplicates,return=minimal" });
  return r.status >= 200 && r.status < 300;
}
// ------------------------------------------------------------ MOEDAS NO SERVIDOR
// O saldo de verdade (moedas e grana) fica aqui. O celular manda cada ganho/gasto como uma
// "transação" com motivo; o servidor confere e devolve o saldo certo. Assim editar o save do
// celular não dá mais moedas. Na primeira vez (versão nova), o saldo do celular é trazido uma vez só.
const ECO_START = { coins: 150, grana: 0 };
const ECO_MIGRATE_MAX = { coins: 100000, grana: 1000 };   // teto da migração (contra save editado)
const ECO_DAY_MAX = { coins: 12000, grana: 120 };         // ganhos comuns por dia (missões, IA, roleta...)
const betOpen = new Map();   // code -> {room, stake, claimed, at}
const tourPrize = new Map(); // code -> prêmio de campeão a resgatar
const ecoLocks = new Map();
function dayBR() { return new Date(Date.now() - 3 * 3600 * 1000).toISOString().slice(0, 10); }
function withLock(code, fn) {
  const prev = ecoLocks.get(code) || Promise.resolve();
  const next = prev.then(fn, fn);
  ecoLocks.set(code, next.catch(() => {}));
  return next;
}
function ecoDay(eco) {
  if (eco.day !== dayBR()) { eco.day = dayBR(); eco.ec = 0; eco.eg = 0; eco.sc = 0; eco.sg = 0; }
}
// devoluções feitas à mão (quando um bug tirou moedas de alguém): código -> saldo mínimo, aplicado uma vez
const ECO_GRANTS = {
  LP34RB: { id: "g20261121", coins: 200000 }, // dono do jogo (devolução do bug das moedas de 21/11)
};
function ecoGrant(code, eco) {
  const g = ECO_GRANTS[code];
  if (!g || (eco.grants || []).includes(g.id)) return false;
  eco.grants = (eco.grants || []).concat([g.id]);
  if (g.coins && eco.coins < g.coins) eco.coins = g.coins;
  if (g.grana && eco.grana < g.grana) eco.grana = g.grana;
  return true;
}
function ecoApply(code, eco, tx) {
  const dc = Math.trunc(Number(tx.c) || 0), dg = Math.trunc(Number(tx.g) || 0);
  const why = String(tx.w || "");
  if (Math.abs(dc) > 1000000 || Math.abs(dg) > 100000) return false;
  // gastos: só se tiver saldo
  if (dc < 0 && eco.coins + dc < 0) return false;
  if (dg < 0 && eco.grana + dg < 0) return false;
  let gc = Math.max(0, dc), gg = Math.max(0, dg);
  if (gc > 0 || gg > 0) {
    if (why === "bet_win" || why === "bet_refund") {
      const b = betOpen.get(code);
      const lim = b ? (why === "bet_win" ? b.stake * 2 : b.stake) : 0;
      if (!b || b.claimed || gc > lim || gg > 0) return false;
      b.claimed = true;
      gc = 0; gg = 0; // não conta no limite do dia
    } else if (why === "tour") {
      const pz = tourPrize.get(code) || 0;
      if (gc > pz || gg > 0) return false;
      tourPrize.delete(code);
      gc = 0;
    } else {
      ecoDay(eco);
      // limite do dia é pelo LUCRO (ganhou - gastou): apostar contra a IA ou abrir pacotes gasta e
      // ganha de volta, e isso não pode estourar o limite de quem está jogando normalmente
      if ((eco.ec + gc) - (eco.sc || 0) > ECO_DAY_MAX.coins || (eco.eg + gg) - (eco.sg || 0) > ECO_DAY_MAX.grana) return false;
      eco.ec += gc;
      eco.eg += gg;
    }
  }
  if (dc < 0 || dg < 0) {
    ecoDay(eco);
    eco.sc = (eco.sc || 0) - Math.min(0, dc);
    eco.sg = (eco.sg || 0) - Math.min(0, dg);
  }
  eco.coins += dc;
  eco.grana += dg;
  return true;
}
function ecoMsg(c, m) {
  if (!c.code || typeof m.tok !== "string" || m.tok.length < 16) return;
  const code = c.code;
  withLock(code, async () => {
    const row = await getSave(code);
    if (row === undefined) return;
    if (row && row.tok && row.tok !== m.tok) return sendJ(c, { t: "eco_r", denied: true });
    let eco = row && row.eco;
    let migrated = false;
    if (!eco) {
      const ini = m.init && typeof m.init === "object" ? m.init : null;
      eco = { coins: ECO_START.coins, grana: ECO_START.grana, seq: 0, day: dayBR(), ec: 0, eg: 0 };
      if (ini) {
        eco.coins = Math.max(0, Math.min(ECO_MIGRATE_MAX.coins, Math.trunc(Number(ini.coins) || 0)));
        eco.grana = Math.max(0, Math.min(ECO_MIGRATE_MAX.grana, Math.trunc(Number(ini.grana) || 0)));
      }
      migrated = true;
    }
    const rej = [];
    for (const tx of Array.isArray(m.txs) ? m.txs.slice(0, 200) : []) {
      const sq = Math.trunc(Number(tx.s) || 0);
      if (sq <= (eco.seq || 0)) continue; // já processada
      if (!ecoApply(code, eco, tx)) rej.push(sq);
      eco.seq = sq;
    }
    const granted = ecoGrant(code, eco);
    await putSave(code, { tok: m.tok, eco });
    c.coins = eco.coins;
    if (granted) sendJ(c, { t: "toast", msg: "Suas moedas foram devolvidas!" });
    sendJ(c, { t: "eco_r", seq: eco.seq, coins: eco.coins, grana: eco.grana, rej, migrated });
  });
}

// ------------------------------------------------------------ NEGOCIAÇÃO entre jogadores
// Os dois montam a oferta (itens + moedas), marcam PRONTO e depois CONFIRMAR. As moedas passam de uma
// conta para a outra aqui no servidor (com a senha do aparelho de cada um); os itens o servidor manda
// cada celular tirar/colocar. Qualquer mudança na oferta desmarca o PRONTO dos dois.
const trades = new Map(); // id -> trade
let ITEM_VAL = {};
try { ITEM_VAL = JSON.parse(require("fs").readFileSync(require("path").join(__dirname, "itens.json"), "utf8")); } catch (e) { console.log("itens.json:", e.message); }
const TRADE_MIN = 0.25; // cada lado precisa receber pelo menos 25% do valor do que dá (item de 20k sai por no mínimo 5k)
function offerVal(o) { return o.coins + o.items.reduce((a, it) => a + (ITEM_VAL[it] || 0), 0); }
function tradeFair(t) {
  const va = offerVal(t.offer.a), vb = offerVal(t.offer.b);
  if (va === 0 && vb === 0) return "Coloque alguma coisa na troca.";
  if (vb < Math.ceil(va * TRADE_MIN) || va < Math.ceil(vb * TRADE_MIN)) return "Troca muito desigual: cada lado precisa receber pelo menos 25% do valor do que está dando.";
  return "";
}
let tradeSeq = 0;
function tradeOf(c) { return c.tradeId ? trades.get(c.tradeId) : null; }
function tradeSide(t, code) { return t.a === code ? "a" : t.b === code ? "b" : ""; }
function tradeSend(t, extra) {
  for (const sd of ["a", "b"]) {
    const me = sd === "a" ? t.a : t.b, ot = sd === "a" ? t.b : t.a;
    const cl = clients.get(me);
    if (!cl) continue;
    sendJ(cl, Object.assign({ t: "trade", id: t.id, with: ot, withName: (clients.get(ot) || {}).name || (players.get(ot) || {}).name || ot,
      mine: t.offer[sd], theirs: t.offer[sd === "a" ? "b" : "a"], ready: t.ready[sd], theirReady: t.ready[sd === "a" ? "b" : "a"],
      conf: t.conf[sd], theirConf: t.conf[sd === "a" ? "b" : "a"], stage: t.stage, theirHas: t.has[sd === "a" ? "b" : "a"] || [],
      withAv: ((players.get(ot) || {}).prof || {}).av || "b8", withFr: ((players.get(ot) || {}).prof || {}).fr || "simples" }, extra || {}));
  }
}
function tradeEnd(t, why) {
  trades.delete(t.id);
  for (const code of [t.a, t.b]) {
    const cl = clients.get(code);
    if (cl && cl.tradeId === t.id) { cl.tradeId = null; sendJ(cl, { t: "trade_end", id: t.id, why }); }
  }
}
function cleanOffer(o) {
  const items = Array.isArray(o && o.items) ? [...new Set(o.items.map((x) => String(x).slice(0, 24)))].filter((x) => ITEM_VAL[x] > 0).slice(0, 30) : [];
  const coins = Math.max(0, Math.min(10000000, Math.trunc(Number(o && o.coins) || 0)));
  return { items, coins };
}
async function tradeExec(t) {
  t.stage = "exec";
  tradeSend(t); // os dois celulares mostram "enviando itens..."
  const codes = [t.a, t.b].sort();
  await withLock(codes[0], () => withLock(codes[1], async () => {
    const ra = await getSave(t.a), rb = await getSave(t.b);
    const ok = (r, tok) => r && r.eco && r.tok === tok;
    if (!ok(ra, t.tok.a) || !ok(rb, t.tok.b)) return tradeEnd(t, "Não deu para conferir as contas (as duas precisam estar na versão nova).");
    const ca = t.offer.a.coins, cb = t.offer.b.coins;
    if (ra.eco.coins < ca || rb.eco.coins < cb) return tradeEnd(t, "Moedas insuficientes para a troca.");
    // itens: cada um precisa ter o que oferece (conferido pela lista que o próprio celular mandou ao confirmar)
    for (const [sd, owned] of [["a", t.owned.a], ["b", t.owned.b]]) {
      for (const it of t.offer[sd].items) if (!owned.includes(it)) return tradeEnd(t, "Um dos itens não está mais disponível.");
      for (const it of t.offer[sd === "a" ? "b" : "a"].items) if (owned.includes(it)) return tradeEnd(t, "Um dos jogadores já tem um dos itens.");
    }
    const unfair = tradeFair(t);
    if (unfair) return tradeEnd(t, unfair);
    ra.eco.coins += cb - ca;
    rb.eco.coins += ca - cb;
    await putSave(t.a, { tok: ra.tok, eco: ra.eco });
    await putSave(t.b, { tok: rb.tok, eco: rb.eco });
    trades.delete(t.id);
    for (const [code, mine, theirs, eco] of [[t.a, t.offer.a, t.offer.b, ra.eco], [t.b, t.offer.b, t.offer.a, rb.eco]]) {
      const cl = clients.get(code);
      if (!cl) continue;
      cl.tradeId = null;
      cl.coins = eco.coins;
      sendJ(cl, { t: "trade_done", give: mine.items, get: theirs.items, coins: eco.coins, grana: eco.grana, seq: eco.seq || 0 });
    }
    console.log("troca " + t.a + " <-> " + t.b + ": " + JSON.stringify(t.offer));
  }));
}
function tradeDrop(c) {
  for (const t of [...trades.values()]) {
    if ((t.a === c.code || t.b === c.code) && t.stage !== "exec" && clients.get(c.code) === c) tradeEnd(t, (c.name || "O outro jogador") + " saiu.");
  }
}
function tradeMsg(c, m) {
  if (!c.code) return;
  if (m.t === "trade_req") {
    const to = String(m.to || "").toUpperCase();
    const f = clients.get(to);
    if (!f || f === c || blockedBy(f, c.code)) return sendJ(c, { t: "trade_end", why: "Seu amigo não está online." });
    if (tradeOf(c) || tradeOf(f)) return sendJ(c, { t: "trade_end", why: "Alguém já está numa negociação." });
    if (c.room || f.room) return sendJ(c, { t: "trade_end", why: "Não dá para negociar durante uma partida." });
    const id = "T" + (++tradeSeq);
    const t = { id, a: c.code, b: to, offer: { a: { items: [], coins: 0 }, b: { items: [], coins: 0 } }, ready: { a: false, b: false }, conf: { a: false, b: false }, tok: {}, owned: {}, has: {}, stage: "invite", at: Date.now() };
    trades.set(id, t);
    c.tradeId = id;
    sendJ(f, { t: "trade_invite", id, from: c.code, name: c.name || c.code });
    sendJ(c, { t: "trade_wait", id, name: f.name || to });
    return;
  }
  const t = trades.get(String(m.id || ""));
  if (!t) return sendJ(c, { t: "trade_end", why: "Essa negociação já acabou." });
  const sd = tradeSide(t, c.code);
  if (!sd) return;
  const os = sd === "a" ? "b" : "a";
  switch (m.t) {
    case "trade_resp":
      if (sd !== "b" || t.stage !== "invite") return;
      if (!m.ok) return tradeEnd(t, (c.name || "O amigo") + " recusou a negociação.");
      c.tradeId = t.id;
      t.stage = "open";
      tradeSend(t);
      break;
    case "trade_set":
      if (t.stage !== "open") return;
      t.offer[sd] = cleanOffer(m);
      t.ready.a = t.ready.b = false;
      t.conf.a = t.conf.b = false;
      tradeSend(t);
      break;
    case "trade_ready":
      if (t.stage !== "open") return;
      if (m.v) { const why = tradeFair(t); if (why) return sendJ(c, { t: "toast", msg: why }); }
      t.ready[sd] = !!m.v;
      if (!t.ready[sd]) t.conf.a = t.conf.b = false;
      tradeSend(t);
      break;
    case "trade_confirm":
      if (t.stage !== "open" || !t.ready.a || !t.ready.b) return;
      if (typeof m.tok !== "string" || m.tok.length < 16) return;
      t.conf[sd] = true;
      t.tok[sd] = m.tok;
      t.owned[sd] = Array.isArray(m.owned) ? m.owned.map(String) : [];
      if (t.conf[os]) tradeExec(t); else tradeSend(t);
      break;
    case "trade_has":
      t.has[sd] = Array.isArray(m.owned) ? m.owned.map((x) => String(x).slice(0, 24)).filter((x) => ITEM_VAL[x] > 0).slice(0, 300) : [];
      tradeSend(t);
      break;
    case "trade_cancel":
      tradeEnd(t, (c.name || "O outro jogador") + " cancelou a negociação.");
      break;
  }
}

// ------------------------------------------------------------ CONTA GOOGLE
// O jogo abre goscripts.com.br/sinucou/login/?n=NONCE no navegador; a página faz o login oficial do
// Google e manda o token para POST /glink. O servidor confere o token com o Google e liga a conta
// (modo "link") ou devolve a conta já ligada (modo "login"). O celular fica perguntando "glink_poll".
const GCLIENT = process.env.GOOGLE_CLIENT_ID || "";
const gNonce = new Map(); // n -> {mode, code, st, msg, res, at}
function gMask(email) {
  const [u, d] = String(email || "").split("@");
  if (!d) return "";
  return (u.length <= 2 ? u[0] + "*" : u.slice(0, 2) + "***") + "@" + d;
}
setInterval(() => { const now = Date.now(); for (const [k, v] of gNonce) if (now - v.at > 15 * 60 * 1000) gNonce.delete(k); }, 60 * 1000);
function gVerify(cred) {
  return new Promise((resolve) => {
    if (!GCLIENT || typeof cred !== "string" || cred.length > 5000) return resolve(null);
    https.get("https://oauth2.googleapis.com/tokeninfo?id_token=" + encodeURIComponent(cred), (r) => {
      let b = "";
      r.on("data", (d) => { b += d; if (b.length > 20000) r.destroy(); });
      r.on("end", () => {
        try {
          const j = JSON.parse(b);
          const okIss = j.iss === "accounts.google.com" || j.iss === "https://accounts.google.com";
          if (r.statusCode === 200 && j.aud === GCLIENT && okIss && j.sub && Number(j.exp) * 1000 > Date.now()) return resolve(j);
        } catch (e) {}
        resolve(null);
      });
    }).on("error", () => resolve(null));
  });
}
async function gHandle(n, cred) {
  const g = gNonce.get(String(n || ""));
  if (!g || g.st !== "wait") return { ok: false, msg: "Esse link expirou. Volte ao jogo e toque no botão do Google de novo." };
  const j = await gVerify(cred);
  if (!j) return { ok: false, msg: "Não consegui confirmar sua conta Google. Tente de novo." };
  const sub = String(j.sub), mail = gMask(j.email);
  if (g.mode === "link") {
    const other = gIndex.get(sub);
    if (other && other !== g.code) { g.st = "fail"; g.msg = "Essa conta Google já está ligada a outro jogador (" + other + ")."; return { ok: false, msg: g.msg }; }
    const ok = await withLock(g.code, async () => {
      const row = await getSave(g.code);
      if (!row || row.tok !== g.tok) return false;
      if (row.gsub && row.gsub !== sub) gIndex.delete(row.gsub);
      await putSave(g.code, { gsub: sub, gmail: mail });
      gIndex.set(sub, g.code);
      return true;
    });
    if (!ok) { g.st = "fail"; g.msg = "Não deu para ligar a conta agora. Tente de novo."; return { ok: false, msg: g.msg }; }
    g.st = "linked"; g.msg = mail;
    console.log("google ligado: " + g.code);
    return { ok: true, msg: "Pronto! Sua conta do Sinucou agora está ligada ao Google " + mail + ". Pode voltar para o jogo." };
  }
  // login: achar a conta ligada a esse Google
  const code = gIndex.get(sub);
  if (!code) { g.st = "fail"; g.msg = "Nenhuma conta do Sinucou está ligada a esse Google ainda. No celular antigo, abra AJUSTES e toque em CONECTAR COM GOOGLE."; return { ok: false, msg: g.msg }; }
  const row = await getSave(code);
  if (!row) { g.st = "fail"; g.msg = "Não achei os dados dessa conta."; return { ok: false, msg: g.msg }; }
  g.st = "login"; g.msg = mail;
  g.res = { code, tok: row.tok, save: row.save, eco: row.eco || null, name: (players.get(code) || {}).name || "" };
  console.log("google login: " + code);
  return { ok: true, msg: "Achei sua conta! Volte para o jogo para entrar." };
}

// ------------------------------------------------------------ FILTRO DE PALAVRÕES (chat, mensagens e nomes)
const BAD = ["porra","caralho","carai","krl","crl","buceta","boceta","bct","xoxota","xereca","piroca","pica","cacete","foder","foda","fode","fodase","fudido","fdp","filhodaputa","puta","putinha","puto","viado","viadinho","veado","bicha","baitola","traveco","arrombado","arrombada","arombado","cu","cuzao","cuzão","bosta","merda","otario","otaria","babaca","corno","corna","vagabunda","vagabundo","vadia","safada","safado","punheta","punheteiro","siririca","boquete","chupa","xupa","piru","pinto","rapariga","quenga","escroto","escrota","desgracado","desgraçado","retardado","mongol","macaco","negrinho","nazista","hitler","estupro","estuprador","pedofilo","pedófilo","suicida","vtnc","vsf","pqp","tnc","fds"];
const BAD_SET = new Set(BAD.map((w) => w.normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/(.)\1+/g, "$1")));
function _fold(w) {
  return w.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "")
    .replace(/[4@]/g, "a").replace(/3/g, "e").replace(/[1!]/g, "i").replace(/0/g, "o").replace(/[5$]/g, "s").replace(/7/g, "t")
    .replace(/[^a-z]/g, "").replace(/(.)\1+/g, "$1");
}
function cleanText(t) {
  return String(t || "").replace(/[\p{L}\p{N}@$]+/gu, (w) => {
    const f = _fold(w);
    if (f.length >= 2 && (BAD_SET.has(f) || BAD_SET.has(f.replace(/s$/, "")) || BAD_SET.has(f.replace(/(inho|inha|ao|oes)$/, "")))) return "*".repeat(Math.min(6, w.length));
    return w;
  });
}
function blockedBy(target, fromCode) { return !!(target && target.blocks && target.blocks.has(fromCode)); }

// ------------------------------------------------------------ EXCLUIR CONTA
async function deleteAccount(code) {
  const row = await getSave(code);
  if (row && row.gsub) gIndex.delete(row.gsub);
  saves.delete(code);
  players.delete(code);
  mailbox.delete(code);
  lastPl.delete(code);
  betOpen.delete(code);
  tourPrize.delete(code);
  if (SB) {
    await sb("DELETE", "sinucou_saves?code=eq." + encodeURIComponent(code));
    await sb("DELETE", "sinucou_players?code=eq." + encodeURIComponent(code));
    await sb("DELETE", "sinucou_mailbox?code=eq." + encodeURIComponent(code));
  }
  saveSoon();
  console.log("conta excluída: " + code);
}

function passHash(code, pass, salt) {
  return salt + "$" + crypto.createHash("sha256").update(salt + ":" + code + ":" + pass).digest("hex");
}
function passOk(code, pass, stored) {
  if (!stored || stored.indexOf("$") < 0) return false;
  const salt = stored.split("$")[0];
  const a = Buffer.from(passHash(code, pass, salt));
  const b = Buffer.from(stored);
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

let saveTimer = null;
function saveSoon() {
  if (saveTimer) return;
  saveTimer = setTimeout(() => {
    saveTimer = null;
    if (SB) { sbFlush(); return; }
    const d = JSON.stringify({ players: [...players], mailbox: [...mailbox], saves: [...saves], reports });
    fs.writeFile(DATA_FILE + ".tmp", d, (err) => { if (!err) fs.rename(DATA_FILE + ".tmp", DATA_FILE, () => {}); });
  }, 3000);
}
function remember(c) {
  if (!c.code) return;
  const old = players.get(c.code) || {};
  players.set(c.code, Object.assign(old, { name: c.name, seen: Date.now() }));
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

// ------------------------------------------------------------ anti-trapaça
// SHA-1 dos certificados oficiais: chave de assinatura da Play (clássica e pós-quântica) e chave de upload
const PLAY_SIGS = new Set([
  "79:A6:11:E0:E0:E4:65:C5:09:2D:96:AA:24:54:B0:31:1D:A9:54:9E",
  "B1:F0:5C:60:35:E2:C7:D7:DB:EE:11:D1:77:19:82:82:8F:35:B2:E4", // chave de assinatura anterior (23/11)
  "D4:34:11:90:D1:74:F5:11:78:4A:4A:CD:2A:2A:75:CF:F3:BC:85:66",
  "3C:71:D2:E0:72:E6:E2:B9:4A:9F:7A:BD:19:6C:81:19:60:E9:24:17",
]);
const MODDED_BLOCK = new Set(["queue", "lcreate", "lstart", "tcreate", "invite", "accept", "rematch"]);
const cheatSeen = new Map(); // código+motivo -> último aviso (não encher a lista)
function cheatFlag(code, name, why) {
  const k = code + "|" + why.slice(0, 20);
  const now = Date.now();
  if (now - (cheatSeen.get(k) || 0) < 3600000) return;
  cheatSeen.set(k, now);
  reports.push({ at: now, from: "SISTEMA", fromName: "Anti-trapaça", code, name: String(name || "").slice(0, 20), reason: "Possível trapaça", note: why, ctx: [] });
  while (reports.length > 500) reports.shift();
  saveSoon();
  console.log("anti-trapaça: " + code + " — " + why);
}

// ------------------------------------------------------------ lógica
function onMsg(c, op, payload) {
  if (op === 2) return relay(c, payload);
  let m;
  try { m = JSON.parse(payload.toString("utf8")); } catch (e) { return; }
  // anti-trapaça: versão da Play com assinatura diferente = APK modificado e reassinado
  if (c.modded && MODDED_BLOCK.has(m.t)) {
    if (m.t === "queue" || m.t === "lstart" || m.t === "accept") sendJ(c, { t: "modded" });
    return;
  }
  switch (m.t) {
    case "hello": {
      const code = String(m.code || "").toUpperCase().slice(0, 8);
      if (!/^[A-Z0-9]{4,8}$/.test(code)) return sendJ(c, { t: "error", msg: "código inválido" });
      const old = clients.get(code);
      if (old && old !== c) drop(old);
      c.code = code;
      c.name = cleanText(String(m.name || "Jogador").slice(0, 15));
      c.blocks = new Set(Array.isArray(m.blk) ? m.blk.map((x) => String(x).toUpperCase().slice(0, 8)).slice(0, 300) : []);
      c.coins = Math.max(0, Number(m.coins) || 0);
      c.felt = String(m.felt || "").slice(0, 24);
      c.wfx = String(m.wfx || "").slice(0, 16);
      c.sig = String(m.sig || "").toUpperCase().slice(0, 80);
      c.rule = ruleOf(m.rule);
      c.modded = !!m.store && c.sig !== "" && !PLAY_SIGS.has(c.sig);
      if (c.modded) cheatFlag(code, c.name, "APK modificado (assinatura " + c.sig.slice(0, 14) + "...)");
      clients.set(code, c);
      remember(c);
      sendJ(c, { t: "welcome", code, online: clients.size, app: appVersion() });
      const box = mailbox.get(code);
      if (box) {
        mailbox.delete(code);
        saveSoon();
        for (const x of box) {
          if (x.kind === "pm") sendJ(c, { t: "pm", from: x.from, name: x.name, txt: x.txt, ts: x.ts });
          else sendJ(c, { t: "fmsg", kind: x.kind, from: x.from, name: x.name });
        }
      }
      break;
    }
    case "eco": ecoMsg(c, m); break;
    case "trade_req": case "trade_resp": case "trade_set": case "trade_ready": case "trade_confirm": case "trade_cancel": case "trade_has":
      tradeMsg(c, m);
      break;
    case "csave": { // backup do save do celular
      if (!c.code || typeof m.tok !== "string" || m.tok.length < 16 || !m.save || typeof m.save !== "object") return;
      const js = JSON.stringify(m.save);
      if (js.length > 200000) return;
      const code = c.code;
      (async () => {
        const row = await getSave(code);
        if (row === undefined) return;
        if (row && row.tok && row.tok !== m.tok) return sendJ(c, { t: "csave_fail", why: "outro aparelho" });
        const ok = await putSave(code, { tok: m.tok, pass: row ? row.pass : null, save: m.save });
        sendJ(c, { t: "csave_ok", ok, pass: !!(row && row.pass) });
      })();
      break;
    }
    case "setpass": { // cria/troca a senha da conta (para recuperar em outro celular)
      if (!c.code || typeof m.tok !== "string" || typeof m.pass !== "string" || m.pass.length < 4 || m.pass.length > 40) return;
      const code = c.code;
      (async () => {
        const row = await getSave(code);
        if (row === undefined) return sendJ(c, { t: "setpass_r", ok: false, msg: "Servidor sem acesso ao banco, tente de novo." });
        if (row && row.tok && row.tok !== m.tok) return sendJ(c, { t: "setpass_r", ok: false, msg: "Esta conta pertence a outro aparelho." });
        const salt = crypto.randomBytes(8).toString("hex");
        const ok = await putSave(code, { tok: m.tok, pass: passHash(code, m.pass, salt), save: m.save || (row ? row.save : {}) });
        sendJ(c, { t: "setpass_r", ok, msg: ok ? "Senha criada!" : "Não consegui salvar, tente de novo." });
      })();
      break;
    }
    case "glink_start": { // ligar (link) ou entrar (login) com a conta Google
      const mode = m.mode === "login" ? "login" : "link";
      if (!GCLIENT) return sendJ(c, { t: "glink_r", st: "fail", msg: "Login com Google ainda não está ativado no servidor." });
      if (mode === "link" && (!c.code || typeof m.tok !== "string" || m.tok.length < 16)) return;
      (async () => {
        if (mode === "link") {
          const row = await getSave(c.code);
          if (!row || row.tok !== m.tok) return sendJ(c, { t: "glink_r", st: "fail", msg: "Espere o jogo terminar de salvar sua conta e tente de novo." });
        }
        const n = crypto.randomBytes(18).toString("base64url");
        gNonce.set(n, { mode, code: c.code, tok: m.tok, st: "wait", at: Date.now() });
        sendJ(c, { t: "glink_url", n, mode, url: "https://goscripts.com.br/sinucou/login/?n=" + n + "&m=" + mode });
      })();
      break;
    }
    case "glink_token": { // login nativo do Android: o celular já manda o token do Google
      const mode = m.mode === "login" ? "login" : "link";
      if (!GCLIENT) return sendJ(c, { t: "glink_r", st: "fail", msg: "Login com Google ainda não está ativado no servidor." });
      if (mode === "link" && (!c.code || typeof m.tok !== "string" || m.tok.length < 16)) return;
      (async () => {
        if (mode === "link") {
          const row = await getSave(c.code);
          if (!row || row.tok !== m.tok) return sendJ(c, { t: "glink_r", st: "fail", msg: "Espere o jogo terminar de salvar sua conta e tente de novo." });
        }
        const n = crypto.randomBytes(18).toString("base64url");
        gNonce.set(n, { mode, code: c.code, tok: m.tok, st: "wait", at: Date.now() });
        await gHandle(n, String(m.cred || ""));
        const g = gNonce.get(n) || { st: "fail", msg: "Não deu certo, tente de novo." };
        gNonce.delete(n);
        if (g.st === "wait") return sendJ(c, { t: "glink_r", st: "fail", msg: "Não consegui confirmar sua conta Google. Tente de novo." });
        sendJ(c, Object.assign({ t: "glink_r", st: g.st, msg: g.msg }, g.res || {}));
      })();
      break;
    }
    case "glink_poll": {
      const g = gNonce.get(String(m.n || ""));
      if (!g) return sendJ(c, { t: "glink_r", n: m.n, st: "gone" });
      if (g.st === "wait") return sendJ(c, { t: "glink_r", n: m.n, st: "wait" });
      gNonce.delete(String(m.n));
      sendJ(c, Object.assign({ t: "glink_r", n: m.n, st: g.st, msg: g.msg }, g.res || {}));
      break;
    }
    case "glink_info": {
      if (!c.code) return;
      (async () => { const row = await getSave(c.code); sendJ(c, { t: "glink_info", mail: row && row.gsub ? row.gmail || "conectado" : "", on: !!GCLIENT, cid: GCLIENT }); })();
      break;
    }
    case "recover": { // entrar na conta em outro celular: código + senha
      const code = String(m.code || "").toUpperCase().slice(0, 8);
      c.recTries = (c.recTries || 0) + 1;
      if (c.recTries > 6) return sendJ(c, { t: "recover_r", ok: false, msg: "Muitas tentativas. Feche o jogo e tente mais tarde." });
      (async () => {
        await new Promise((r) => setTimeout(r, 600));
        const row = await getSave(code);
        if (row === undefined) return sendJ(c, { t: "recover_r", ok: false, msg: "Servidor sem acesso ao banco, tente de novo." });
        if (!row || !passOk(code, String(m.pass || ""), row.pass)) return sendJ(c, { t: "recover_r", ok: false, msg: "Código ou senha errados." });
        sendJ(c, { t: "recover_r", ok: true, code, tok: row.tok, save: row.save, eco: row.eco || null });
      })();
      break;
    }
    case "queue": {
      if (!c.code || c.room) return;
      const g = GAMES.includes(m.game) ? m.game : "sinuca";
      const p = c.party;
      if (p && p.leader !== c) return; // no lobby só o líder procura
      if (m.coins != null) c.coins = Math.max(0, Number(m.coins) || 0);
      const stake = p ? stakeOf(p.stake) : stakeOf(m.stake);
      const broke = poor(p ? p.members : [c], stake);
      if (broke) {
        const msg = (broke === c ? "Você não tem" : broke.name + " não tem") + " moedas para apostar " + stake + ".";
        return p ? sendLobby(p, msg) : sendJ(c, { t: "qfail", msg });
      }
      const qk = qkey(g, stake);
      if (p && p.members.some((o) => o.room)) return sendLobby(p, "Espere todos voltarem da partida.");
      unqueue(c);
      if (p) {
        p.game = g.replace("4", "");
        p.four = g.endsWith("4");
        if (!p.four) {
          // 1x1 com a dupla do lobby: joga um contra o outro
          if (p.members.length === 2) { const ms = p.members.slice(); matchN(ms, g, stake, p.leader && p.leader.rule); return; }
          sendLobby(p, "No 1 contra 1 o lobby precisa ter só 2 jogadores.");
          return;
        }
      }
      setStatus(c, "procurando");
      c.qsince = Date.now();
      queues[qk] = (queues[qk] || []).filter((o) => !o.room && clients.get(o.code) === o);
      queues[qk].push(c);
      if (p) sendLobby(p);
      if (g.endsWith("4")) tryTable(qk, false);
      else if (queues[qk].length >= 2) matchN(queues[qk].splice(0, 2), g, stake);
      break;
    }
    case "unqueue": {
      if (c.party && c.party.leader !== c) break;
      unqueue(c); setStatus(c, "online");
      if (c.party) sendLobby(c.party);
      break;
    }
    case "lleave": leaveParty(c); break;
    case "lteam": { // dono troca um amigo de time
      const p = c.party;
      if (!p || p.leader !== c || !p.four) break;
      const o = p.members.find((x) => x.code === m.code);
      if (!o || o === p.leader) break;
      const to = teamOf(p, o) === 0 ? 1 : 0;
      if (teamCount(p, to) >= 2) {
        // time cheio: troca de lugar com alguém de lá
        const other = p.members.find((x) => x !== p.leader && teamOf(p, x) === to);
        if (!other) return sendLobby(p, "Esse time já está cheio.");
        p.team.set(other.code, 1 - to);
      }
      p.team.set(o.code, to);
      if (queueOf(c)) { unqueue(c); setStatus(c, "online"); }
      sendLobby(p);
      break;
    }
    case "lcreate": { // cria um lobby de amigos (sem procurar partida ainda)
      if (!c.code || c.room) return;
      unqueue(c); setStatus(c, "online");
      const game = m.game === "truco" ? "truco" : "sinuca";
      if (c.party && c.party.leader === c) {
        if (!m.four && c.party.members.length > 2) return sendLobby(c.party, "1 contra 1 é só com 2 no lobby.");
        c.party.game = game; c.party.four = !!m.four; c.party.stake = stakeOf(m.stake);
        return sendLobby(c.party);
      }
      leaveParty(c);
      const p = { id: nextParty++, leader: c, members: [c], game, four: !!m.four, stake: stakeOf(m.stake) };
      c.party = p;
      sendLobby(p, "Lobby criado! Chame seus amigos.");
      break;
    }
    case "lstart": { // líder começa já: só com quem está no lobby, a IA completa os lugares vazios
      const p = c.party;
      if (!p || p.leader !== c || c.room) break;
      if (p.members.some((o) => o.room)) return sendLobby(p, "Espere todos voltarem da partida.");
      const lbroke = poor(p.members, stakeOf(p.stake));
      if (lbroke) return sendLobby(p, lbroke.name + " não tem moedas para " + (p.tour ? "a inscrição de " : "apostar ") + p.stake + ".");
      if (p.tour) {
        if (p.tourRun && !p.tourRun.done) return sendLobby(p, "O torneio já está acontecendo.");
        if (p.members.length < 3) return sendLobby(p, "O torneio precisa de pelo menos 3 jogadores.");
        startTour(p);
        break;
      }
      unqueue(c);
      if (!p.four) {
        if (p.members.length !== 2) return sendLobby(p, "Para o 1 contra 1 precisa ter 2 no lobby.");
        const ms = p.members.slice();
        matchN(ms, p.game, stakeOf(p.stake), p.leader && p.leader.rule);
        break;
      }
      if (p.members.length < 2) return sendLobby(p, "Chame pelo menos 1 amigo para jogar junto.");
      matchSeats(seatUnits([c]), p.game + "4", stakeOf(p.stake), null, p.leader && p.leader.rule);
      break;
    }
    case "lset": { // líder trocou jogo/mesa no lobby (sem procurar ainda)
      const p = c.party;
      if (!p || p.leader !== c) break;
      unqueue(c); setStatus(c, "online");
      if (p.tourRun && !p.tourRun.done) break;
      p.game = m.game === "truco" ? "truco" : "sinuca";
      p.four = p.tour ? false : !!m.four;
      if (m.stake != null) p.stake = stakeOf(m.stake);
      sendLobby(p);
      break;
    }
    case "coins":
      c.coins = Math.max(0, Number(m.n) || 0);
      if (typeof m.felt === "string") c.felt = m.felt.slice(0, 24);
      if (typeof m.wfx === "string") c.wfx = m.wfx.slice(0, 16);
      break;
    case "tcreate": { // cria um lobby de TORNEIO (3 a 8 amigos, mata-mata 1x1)
      if (!c.code || c.room) return;
      unqueue(c); setStatus(c, "online");
      leaveParty(c);
      const game = m.game === "truco" ? "truco" : "sinuca";
      const p = { id: nextParty++, leader: c, members: [c], game, four: false, stake: stakeOf(m.stake), tour: true };
      c.party = p;
      sendLobby(p, "Torneio criado! Chame de 3 a 8 amigos.");
      break;
    }
    case "mresult": { // o anfitrião avisa quem ganhou (usado no torneio)
      const r = c.room;
      if (!r || !r.tour || c.peer !== 1 || r.tour.done) break;
      const team = Number(m.team) === 1 ? 1 : 0;
      const w = r.members.find((x) => (x.peer - 1) % 2 === team);
      tourResult(r, w ? w.code : null);
      break;
    }
    case "tleave": { // sai do torneio (se tinha jogo marcado, o adversário passa)
      const T = c.party && c.party.tourRun;
      if (!T || T.done) break;
      T.out.add(c.code);
      tourWalkovers(T);
      sendTour(T);
      break;
    }
    case "score": { // liga semanal: o celular manda os pontos da semana
      if (!c.code) break;
      const e = players.get(c.code) || { name: c.name, seen: Date.now() };
      e.wk = Number(m.wk) || 0;
      e.pts = Math.max(0, Math.min(100000, Number(m.pts) || 0));
      players.set(c.code, e);
      saveSoon();
      break;
    }
    case "prof": { // perfil: guarda o meu resumo ou devolve o de alguém
      if (!c.code) break;
      if (m.data && typeof m.data === "object") {
        const d = m.data, e = players.get(c.code) || { name: c.name, seen: Date.now() };
        e.prof = { av: String(d.av || "b8").slice(0, 12), fr: String(d.fr || "").slice(0, 12), ti: String(d.ti || "").slice(0, 16),
          lvl: Number(d.lvl) || 1, wins: Number(d.wins) || 0, played: Number(d.played) || 0, best: Number(d.best) || 0,
          div: Number(d.div) || 0, pts: Number(d.pts) || 0, cue: String(d.cue || "").slice(0, 20), achs: Number(d.achs) || 0 };
        players.set(c.code, e);
        saveSoon();
      }
      if (m.code) {
        const code = String(m.code).toUpperCase();
        const e = players.get(code);
        sendJ(c, { t: "prof", code, name: e ? e.name : "?", data: e && e.prof ? e.prof : null, online: clients.has(code) });
      }
      break;
    }
    case "rank": { // ranking da semana: top 50 + meus amigos + minha posição
      const wk = Number(m.wk) || 0;
      const all = [];
      for (const [code, e] of players) if (e.wk === wk && e.pts > 0) all.push({ code, name: e.name, pts: e.pts, av: e.prof ? e.prof.av : "b8", fr: e.prof ? e.prof.fr : "" });
      all.sort((a, b) => b.pts - a.pts);
      const pos = all.findIndex((x) => x.code === c.code);
      const fr = new Set((m.codes || []).slice(0, 100).map((x) => String(x).toUpperCase()));
      fr.add(c.code);
      const friends = [];
      all.forEach((x, i) => { if (fr.has(x.code)) friends.push(Object.assign({ pos: i + 1 }, x)); });
      sendJ(c, { t: "rank", wk, total: all.length, me: pos + 1, top: all.slice(0, 50).map((x, i) => Object.assign({ pos: i + 1 }, x)), friends });
      break;
    }
    case "rematch": { // revanche 1x1: os dois pedem e a mesma dupla joga de novo, com a mesma aposta
      const r = c.room;
      if (!r || r.seats !== 2) break;
      if (m.coins != null) c.coins = Math.max(0, Number(m.coins) || 0);
      const o = r.members.find((x) => x !== c);
      if (!o) break;
      c.rem = r.id;
      if (o.rem !== r.id) { sendJ(o, { t: "rematch_req", name: c.name }); break; }
      const rb = poor([c, o], r.stake || 0);
      if (rb) {
        c.rem = 0; o.rem = 0;
        for (const x of [c, o]) sendJ(x, { t: "rematch_fail", msg: rb.name + " não tem moedas para a revanche." });
        break;
      }
      for (const x of r.members) { x.room = null; x.peer = 0; x.rem = 0; }
      r.members = [];
      // revanche: troca o anfitrião e a mesa passa para quem não era o dono da última
      const nseats = [c, o];
      const own = nseats.findIndex((x) => x.code !== r.ownerCode);
      matchSeats(nseats, gameOf(r.game), r.stake || 0, own < 0 ? null : own, r.rule);
      break;
    }
    case "friends": {
      const list = (m.codes || []).slice(0, 100).map((code) => {
        const f = clients.get(String(code).toUpperCase());
        const e = players.get(String(code).toUpperCase());
        const pa = e && e.prof ? { av: e.prof.av, fr: e.prof.fr } : {};
        return f ? Object.assign({ code: f.code, name: f.name, online: true, status: f.room ? "jogando" : f.status }, pa) : Object.assign({ code: String(code).toUpperCase(), online: false }, pa);
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
      if (blockedBy(f, c.code)) return sendJ(c, { t: "fsent", kind, to, delivered: true });
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
    case "pm": { // mensagem para um amigo (se estiver offline, fica guardada)
      const to = String(m.to || "").toUpperCase();
      const txt = cleanText(String(m.txt || "").replace(/[\u0000-\u001f]/g, " ").trim().slice(0, 120));
      if (!c.code || !txt || !/^[A-Z0-9]{4,8}$/.test(to) || to === c.code) return;
      const now = Date.now();
      if (c.pmT && now - c.pmT < 700) return; // sem flood
      c.pmT = now;
      const f = clients.get(to);
      const msg = { from: c.code, name: c.name, txt, ts: now };
      if (blockedBy(f, c.code)) return sendJ(c, { t: "pm_ok", to, delivered: true, ts: now });
      if (f) sendJ(f, { t: "pm", ...msg });
      else {
        const box = mailbox.get(to) || [];
        box.push({ kind: "pm", ...msg });
        while (box.length > 80) box.shift();
        mailbox.set(to, box);
        saveSoon();
      }
      sendJ(c, { t: "pm_ok", to, delivered: !!f, ts: now });
      break;
    }
    case "invite": {
      const f = clients.get(String(m.code || "").toUpperCase());
      if (!f || f === c || blockedBy(f, c.code)) return sendJ(c, { t: "invite_fail", msg: "Amigo offline" });
      if (f.room) return sendJ(c, { t: "invite_fail", msg: "Amigo está jogando" });
      if (m.lobby && c.party && c.party.members.length >= partyMax(c.party)) return sendJ(c, { t: "invite_fail", msg: "O lobby já está cheio" });
      const ist = m.lobby ? 0 : stakeOf(m.stake);
      if (ist && (c.coins || 0) < ist) return sendJ(c, { t: "invite_fail", msg: "Você não tem moedas para apostar " + ist + "." });
      sendJ(f, { t: "invited", from: c.code, name: c.name, game: m.lobby && c.party ? c.party.game : (m.game === "truco" ? "truco" : "sinuca"), lobby: !!m.lobby, stake: m.lobby && c.party ? stakeOf(c.party.stake) : ist, tour: !!(m.lobby && c.party && c.party.tour) });
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
        if (p.members.length >= partyMax(p)) return sendJ(c, { t: "invite_fail", msg: "O lobby já está cheio" });
        if (!p.team) p.team = new Map();
        p.team.set(c.code, teamCount(p, 0) < 2 ? 0 : 1);
        p.members.push(c);
        c.party = p;
        // se o líder estava numa fila 1x1, para a busca (o lobby é para 2x2)
        const lq = queueOf(p.leader);
        if (lq && !gameOf(lq).endsWith("4")) { unqueue(p.leader); setStatus(p.leader, "online"); }
        // a contagem da IA começa quando o 2º jogador real chega (aqui, o amigo)
        if (lq && gameOf(lq).endsWith("4")) p.leader.qsince = Date.now();
        sendLobby(p, c.name + " entrou no lobby!");
        if (lq && gameOf(lq).endsWith("4")) tryTable(lq, false);
        break;
      }
      const ast = stakeOf(m.stake);
      if (m.coins != null) c.coins = Math.max(0, Number(m.coins) || 0);
      const ab = poor([f, c], ast);
      if (ab) {
        sendJ(c, { t: "invite_fail", msg: (ab === c ? "Você não tem" : ab.name + " não tem") + " moedas para apostar " + ast + "." });
        if (ab === f) sendJ(f, { t: "invite_fail", msg: "Você não tem moedas para apostar " + ast + "." });
        break;
      }
      leaveParty(f); leaveParty(c);
      unqueue(f); unqueue(c);
      matchN([f, c], m.game === "truco" ? "truco" : "sinuca", ast, f.rule);
      break;
    }
    case "decline": {
      const f = clients.get(String(m.from || "").toUpperCase());
      if (f) sendJ(f, { t: "invite_fail", msg: c.name + " recusou o convite" });
      break;
    }
    case "leave": leaveRoom(c); break;
    case "ping": sendJ(c, { t: "pong" }); break;
    case "block": { // bloquear / desbloquear alguém
      if (!c.code) return;
      const who = String(m.code || "").toUpperCase().slice(0, 8);
      if (!/^[A-Z0-9]{4,8}$/.test(who) || who === c.code) return;
      if (!c.blocks) c.blocks = new Set();
      if (m.on) c.blocks.add(who); else c.blocks.delete(who);
      sendJ(c, { t: "block_ok", code: who, on: !!m.on });
      break;
    }
    case "report": { // denúncia: guarda para o dono do jogo ver
      if (!c.code) return;
      const who = String(m.code || "").toUpperCase().slice(0, 8);
      if (!/^[A-Z0-9]{4,8}$/.test(who) || who === c.code) return;
      const now = Date.now();
      if (c.repT && now - c.repT < 20000) return sendJ(c, { t: "report_ok", dup: true });
      c.repT = now;
      reports.push({ at: now, from: c.code, fromName: c.name, code: who, name: String(m.name || "").slice(0, 20), reason: String(m.reason || "").slice(0, 40), note: String(m.note || "").replace(/[\u0000-\u001f]/g, " ").slice(0, 200), ctx: Array.isArray(m.ctx) ? m.ctx.slice(-10).map((x) => String(x).slice(0, 140)) : [] });
      while (reports.length > 500) reports.shift();
      saveSoon();
      console.log("denúncia: " + c.code + " -> " + who + " (" + m.reason + ")");
      sendJ(c, { t: "report_ok" });
      break;
    }
    case "rule": { // regra de sinuca escolhida no aparelho
      c.rule = ruleOf(m.rule);
      break;
    }
    case "gdiag": { // erro do login rápido do Google no celular (diagnóstico para o dono)
      if (!c.code) return;
      const now = Date.now();
      if (c.gdiagT && now - c.gdiagT < 60000) return;
      c.gdiagT = now;
      const why = String(m.why || "").slice(0, 160);
      console.log("gdiag " + c.code + " v" + (m.v | 0) + ": " + why + " sig=" + (c.sig || "?"));
      reports.push({ at: now, from: "SISTEMA", fromName: "Login Google", code: c.code, name: String(c.name || "").slice(0, 20), reason: "Erro no login rápido", note: "v" + (m.v | 0) + " " + why + " | assinatura do app: " + (c.sig || "?"), ctx: [] });
      while (reports.length > 500) reports.shift();
      saveSoon();
      break;
    }
    case "cheat_flag": { // o celular do adversário pegou uma tacada fora do limite do taco
      if (!c.code) return;
      const who = String(m.code || "").toUpperCase().slice(0, 8);
      if (!/^[A-Z0-9]{4,8}$/.test(who) || who === c.code) return;
      const now = Date.now();
      if (c.cheatT && now - c.cheatT < 30000) return;
      c.cheatT = now;
      const o = clients.get(who);
      cheatFlag(who, o ? o.name : "", String(m.why || "").slice(0, 80) + " — detectado por " + c.code);
      break;
    }
    case "reports_get": { // só o dono do jogo
      if (c.code !== OWNER_CODE || typeof m.tok !== "string") return;
      (async () => {
        const row = await getSave(c.code);
        if (!row || row.tok !== m.tok) return sendJ(c, { t: "reports", list: [], err: "Senha do aparelho não confere." });
        if (m.clear) { reports = []; saveSoon(); }
        sendJ(c, { t: "reports", list: reports.slice(-100).reverse() });
      })();
      break;
    }
    case "delete_acc": { // excluir minha conta
      if (!c.code || typeof m.tok !== "string") return;
      (async () => {
        const row = await getSave(c.code);
        if (row && row.tok && row.tok !== m.tok) return sendJ(c, { t: "delete_r", ok: false, msg: "Não deu para confirmar que a conta é sua neste aparelho." });
        await deleteAccount(c.code);
        sendJ(c, { t: "delete_r", ok: true });
      })();
      break;
    }
  }
}

function norm(t) {
  return t.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "").trim();
}

// sala com 2 a 4 jogadores; o primeiro é o anfitrião (peer 1), os outros são 2, 3, 4
function matchN(list, game, stake, rule) { matchSeats(list, game, stake, null, rule); }
// regras de sinuca: oficial, de bar e bola cantada (fila e torneio usam sempre a oficial)
const RULES = ["classic", "bar", "cantada"];
function ruleOf(r) { return RULES.includes(r) ? r : "classic"; }

// seats[i] = jogador no lugar i (ou null = IA). Lugar i usa peer i+1; times: 0 e 2 contra 1 e 3
function matchSeats(seats, game, stake, ownerSeat, rule) {
  stake = stakeOf(stake);
  rule = game.startsWith("truco") ? "classic" : ruleOf(rule);
  const list = seats.filter((p) => p);
  if (seats[0] == null) { // o lugar 0 (anfitrião) precisa ser gente
    const i = seats.findIndex((p) => p);
    [seats[0], seats[i]] = [seats[i], seats[0]];
  }
  // o lobby continua existindo durante a partida: no fim todos voltam para ele
  for (const p of list) unqueue(p);
  const room = { id: nextRoom++, members: list.slice(), game, seats: game.endsWith("4") ? 4 : 2, stake, rule };
  // dono da mesa da partida (a mesa dele é a usada e ele quebra): no lobby vai revezando, senão sorteia
  const humans = [];
  seats.forEach((p, i) => { if (p) humans.push(i); });
  let owner = humans[Math.floor(Math.random() * humans.length)];
  const party = list[0] && list[0].party && list.every((p) => p.party === list[0].party) ? list[0].party : null;
  if (ownerSeat != null && seats[ownerSeat]) owner = ownerSeat;
  else if (party) { party.rot = ((party.rot ?? -1) + 1) % humans.length; owner = humans[party.rot]; }
  room.ownerCode = seats[owner] ? seats[owner].code : "";
  if (stake) for (const p of list) betOpen.set(p.code, { room: room.id, stake, claimed: false, at: Date.now() });
  const players = [];
  seats.forEach((p, i) => { if (p) { p.room = room; p.peer = i + 1; p.status = "jogando"; const e = playersDir.get(p.code); players.push({ peer: i + 1, name: p.name, code: p.code, felt: p.felt || "", wfx: p.wfx || "", av: e && e.prof ? e.prof.av : "b8", fr: e && e.prof ? e.prof.fr : "" }); } });
  for (const p of list) {
    const opp = list.find((o) => o !== p) || p;
    sendJ(p, { t: "match", role: p.peer === 1 ? "host" : "guest", peer: p.peer, game, seats: room.seats, players, opp: { name: opp.name, code: opp.code }, stake, owner, rule });
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
    t: "lobby", leader: p.leader.code, game: p.game, four: p.four, searching: !!q, stake: stakeOf(p.stake), tour: !!p.tour, touring: !!(p.tourRun && !p.tourRun.done),
    members: p.members.map((o) => ({ code: o.code, name: o.name, team: teamOf(p, o) })), msg: msg || "",
  };
  for (const o of p.members) sendJ(o, d);
}

// time de cada um no lobby 2x2: 0 = time do dono, 1 = adversários (o dono escolhe)
function teamOf(p, o) {
  if (o === p.leader) return 0;
  if (!p.team) p.team = new Map();
  return p.team.get(o.code) ?? 0;
}
function teamCount(p, t) { return p.members.filter((o) => teamOf(p, o) === t).length; }

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
  for (const u of queues[g] || []) {
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
    if (u.party) {
      // lobby: cada um no time que o dono escolheu
      const p = u.party;
      const mine = seats[0] == null && seats[2] == null ? [[0, 2], [1, 3]] : [[1, 3], [0, 2]];
      for (const o of ms) {
        const pref = mine[teamOf(p, o)].concat([0, 1, 2, 3]);
        const s = pref.find((k) => seats[k] == null);
        seats[s] = o;
      }
    } else if (ms.length >= 3) {
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
  queues[g] = (queues[g] || []).filter((o) => !o.room && clients.get(o.code) === o);
  const cand = candidate(g);
  const ready = cand.total === 4 || (timed && cand.total >= 2 && Date.now() - cand.start >= FILL_AFTER);
  if (ready) {
    queues[g] = queues[g].filter((u) => !cand.units.includes(u));
    matchSeats(seatUnits(cand.units), gameOf(g), stakeOfKey(g));
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
  if (r.tour && !r.tour.done) {
    // saiu no meio de uma partida do torneio: o outro passa de fase
    const o = r.members.find((x) => x !== c);
    tourResult(r, o ? o.code : null);
    return;
  }
  const wasHost = c.peer === 1;
  r.members = r.members.filter((p) => p !== c);
  const left = c.peer;
  c.room = null; c.peer = 0; c.status = "online";
  const parties = new Set();
  if (c.party) parties.add(c.party);
  if (wasHost || r.members.length < 2 && r.seats === 2 || r.members.length < 1) {
    // sem anfitrião (ou 1x1 sem adversário): a partida acaba para todos
    for (const p of r.members) {
      p.room = null; p.peer = 0; p.status = "online";
      if (p.party) parties.add(p.party);
      if (!p.socket.destroyed) sendJ(p, { t: "peer_left", peer: left, end: true, name: c.name || "", host: wasHost });
    }
    r.members = [];
  }
  // quem estava num lobby volta para ele
  for (const p of parties) if (p.members.length) sendLobby(p, "Partida encerrada. Vocês voltaram ao lobby!");
  if (!r.members.length) return;
  // 2x2: os outros continuam (o anfitrião coloca a IA no lugar)
  for (const p of r.members) if (!p.socket.destroyed) sendJ(p, { t: "peer_left", peer: left, end: false });
}

function sendWaiting(g) {
  const q = queues[g] || [];
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
  for (const g of Object.keys(queues)) {
    if (gameOf(g).endsWith("4")) tryTable(g, true);
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
  if (c.code) tradeDrop(c);
  if (c.code && clients.get(c.code) === c) remember(c);
  if (c.code && clients.get(c.code) === c) clients.delete(c.code);
  try { c.socket.destroy(); } catch (e) {}
}

// derruba conexões mortas
setInterval(() => {
  for (const c of clients.values()) {
    // celular com o jogo minimizado ou sinal ruim: dá até ~1 min antes de derrubar
    if (c.alive) c.miss = 0;
    else if ((c.miss = (c.miss || 0) + 1) >= 2) { drop(c); continue; }
    c.alive = false;
    sendRaw(c, 9, Buffer.alloc(0));
  }
}, 30000);

// versão mais nova do app (o app compara com a dele e oferece atualizar)
// o app baixa o APK daqui do servidor (/apk); o servidor busca no GitHub e guarda uma cópia
const APK_FILE = "/tmp/sinucou.apk";
let apkReady = ""; // link (fixo no commit) do APK que já está guardado
// o link do versao.json aponta para o commit exato do APK: o cache do GitHub nunca entrega um APK velho
let apkBusy = false;
// a versão nova do app fica no GitHub (ramo do APK): publicar um APK NÃO reinicia o servidor
// (no plano grátis cada reinício apagava o ranking e o cadastro)
const VER_URL = process.env.VER_URL || "https://raw.githubusercontent.com/Goscriptsbr/Goscripts/sinucou-apk/versao.json";
let remoteVer = {};
function pullVer() {
  https.get(VER_URL + "?t=" + Date.now(), { headers: { "User-Agent": "sinucou-servidor", "Cache-Control": "no-cache" } }, (r) => {
    if (r.statusCode !== 200) { r.resume(); return; }
    let b = "";
    r.setEncoding("utf8");
    r.on("data", (d) => { b += d; if (b.length > 20000) r.destroy(); });
    r.on("end", () => {
      try {
        const j = JSON.parse(b);
        if (Number(j.versao) > 0 && j.apk) {
          if (Number(j.versao) !== Number(remoteVer.versao)) console.log("versão no GitHub: " + j.versao);
          remoteVer = j;
          refreshApk(0);
        }
      } catch (e) {}
    });
  }).on("error", () => {});
}
setTimeout(pullVer, 1000);
setInterval(pullVer, 3 * 60 * 1000);
function versionFile() {
  let local = {};
  try { local = JSON.parse(fs.readFileSync(__dirname + "/versao.json", "utf8")); } catch (e) {}
  return (Number(remoteVer.versao) || 0) > (Number(local.versao) || 0) ? remoteVer : local;
}
function appVersion() {
  const v = versionFile();
  if (v.versao) v.url = (process.env.PUBLIC_URL || "https://sinucou.onrender.com") + "/apk?v=" + v.versao;
  return v;
}
function fetchTo(url, dest, hops, cb) {
  if (hops > 8) return cb(new Error("redirects"));
  (url.startsWith("https") ? https : http).get(url, { headers: { "User-Agent": "sinucou-servidor", "Accept-Encoding": "identity" } }, (r) => {
    if (r.statusCode >= 300 && r.statusCode < 400 && r.headers.location) {
      r.resume();
      return fetchTo(new URL(r.headers.location, url).toString(), dest, hops + 1, cb);
    }
    if (r.statusCode !== 200) { r.resume(); return cb(new Error("HTTP " + r.statusCode)); }
    const out = fs.createWriteStream(dest + ".part");
    r.pipe(out);
    out.on("finish", () => { fs.rename(dest + ".part", dest, cb); });
    out.on("error", cb);
  }).on("error", cb);
}
function refreshApk(tries) {
  const v = versionFile();
  if (!v.versao || !v.apk || apkReady === v.apk || apkBusy) return;
  apkBusy = true;
  fetchTo(v.apk, APK_FILE, 0, (err) => {
    apkBusy = false;
    if (err) {
      console.log("APK: falhou (" + err.message + "), tentando de novo");
      if ((tries || 0) < 20) setTimeout(() => refreshApk((tries || 0) + 1), 15000);
      return;
    }
    apkReady = v.apk;
    console.log("APK v" + v.versao + " pronto: " + fs.statSync(APK_FILE).size + " bytes");
  });
}
setTimeout(() => refreshApk(0), 2000);

// plano grátis da Render dorme sem acessos: enquanto tem gente conectada, o servidor se chama a cada 10 min
setInterval(() => {
  if (!clients.size) return;
  const u = (process.env.PUBLIC_URL || "https://sinucou.onrender.com") + "/versao";
  https.get(u, (r) => r.resume()).on("error", () => {});
}, 10 * 60 * 1000);
setInterval(() => refreshApk(0), 10 * 60 * 1000);

const server = http.createServer((req, res) => {
  if (req.url.startsWith("/apk")) {
    const v = versionFile();
    if (apkReady && apkReady === v.apk && fs.existsSync(APK_FILE)) {
      const size = fs.statSync(APK_FILE).size;
      res.writeHead(200, {
        "Content-Type": "application/vnd.android.package-archive",
        "Content-Length": size,
        "Content-Disposition": "attachment; filename=\"Sinucou.apk\"",
        "Cache-Control": "no-store",
      });
      return fs.createReadStream(APK_FILE).pipe(res);
    }
    refreshApk(0);
    // ainda baixando do GitHub: manda direto para lá
    res.writeHead(302, { Location: v.apk || "https://github.com/Goscriptsbr/Goscripts" });
    return res.end();
  }
  if (req.url.startsWith("/gconfig") || req.url.startsWith("/glink")) {
    const origin = req.headers.origin || "";
    const okOrigin = /^https:\/\/(www\.)?goscripts\.com\.br$/.test(origin) ? origin : "https://goscripts.com.br";
    const hd = { "Content-Type": "application/json; charset=utf-8", "Access-Control-Allow-Origin": okOrigin, "Access-Control-Allow-Methods": "GET, POST, OPTIONS", "Access-Control-Allow-Headers": "Content-Type", "Cache-Control": "no-store" };
    if (req.method === "OPTIONS") { res.writeHead(204, hd); return res.end(); }
    if (req.url.startsWith("/gconfig")) { res.writeHead(200, hd); return res.end(JSON.stringify({ client_id: GCLIENT })); }
    if (req.method !== "POST") { res.writeHead(405, hd); return res.end("{}"); }
    let body = "";
    req.on("data", (d) => { body += d; if (body.length > 10000) req.destroy(); });
    req.on("end", async () => {
      let j = {};
      try { j = JSON.parse(body); } catch (e) {}
      const r = await gHandle(j.n, j.cred);
      res.writeHead(200, hd);
      res.end(JSON.stringify(r));
    });
    return;
  }
  if (req.url === "/versao") {
    res.writeHead(200, { "Content-Type": "application/json; charset=utf-8" });
    return res.end(JSON.stringify(appVersion()));
  }
  res.writeHead(200, { "Content-Type": "text/plain; charset=utf-8" });
  res.end("Servidor Sinuca/Truco GoScripts no ar. Jogadores online: " + clients.size + "\n");
});
server.on("upgrade", (req, socket) => accept(req, socket));
server.listen(PORT, () => console.log("ouvindo na porta " + PORT));


// ------------------------------------------------------------ torneio (mata-mata 1x1 entre amigos)
function partyMax(p) { return p.tour ? 8 : (p.four ? 4 : 2); }

function startTour(p) {
  const codes = p.members.map((o) => o.code);
  for (let i = codes.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [codes[i], codes[j]] = [codes[j], codes[i]]; }
  let size = 2;
  while (size < codes.length) size *= 2;
  const names = {};
  for (const o of p.members) names[o.code] = o.name;
  // chaves com "bye" espalhados: quem fica sem adversário passa direto
  const slots = new Array(size).fill(null);
  const byes = size - codes.length;
  let k = 0;
  for (let i = 0; i < size / 2; i++) {
    slots[i * 2] = codes[k++] || null;
    slots[i * 2 + 1] = i < byes ? null : (codes[k++] || null);
  }
  const first = [];
  for (let i = 0; i < size; i += 2) first.push({ a: slots[i], b: slots[i + 1], w: null, live: false });
  const T = { id: Date.now() % 1000000, party: p, game: p.game, fee: stakeOf(p.stake), players: codes.slice(), names, rounds: [first], round: 0, out: new Set(), done: false, champ: null };
  p.tourRun = T;
  for (const o of p.members) { unqueue(o); }
  sendTour(T, "start");
  setTimeout(() => tourPlay(T), 2500);
}

function tourWalkovers(T) {
  const rd = T.rounds[T.round];
  for (const mt of rd) {
    if (mt.w || mt.live) continue;
    const aOk = mt.a && !T.out.has(mt.a) && clients.get(mt.a);
    const bOk = mt.b && !T.out.has(mt.b) && clients.get(mt.b);
    if (!aOk && !bOk) mt.w = mt.a || mt.b || "-";
    else if (!bOk) mt.w = mt.a;
    else if (!aOk) mt.w = mt.b;
  }
  tourNext(T);
}

function tourPlay(T) {
  if (T.done) return;
  tourWalkovers(T);
  if (T.done) return;
  const rd = T.rounds[T.round];
  for (const mt of rd) {
    if (mt.w || mt.live) continue;
    const a = clients.get(mt.a), b = clients.get(mt.b);
    if (!a || !b || a.room || b.room) continue;
    mt.live = true;
    matchSeats([a, b], T.game, 0);
    a.room.tour = { T, mt };
  }
  sendTour(T);
}

function tourResult(r, winCode) {
  const info = r.tour;
  const T = info.T, mt = info.mt;
  info.done = true;
  mt.live = false;
  if (!mt.w) mt.w = winCode || mt.a || mt.b;
  if (mt.w === mt.a && mt.b) T.out.add(mt.b);
  else if (mt.w === mt.b && mt.a) T.out.add(mt.a);
  // fecha a sala sem avisar "adversário saiu" (cada um volta para a chave do torneio)
  for (const x of r.members) { x.room = null; x.peer = 0; x.status = "online"; }
  r.members = [];
  tourNext(T);
  sendTour(T);
}

function tourNext(T) {
  if (T.done) return;
  const rd = T.rounds[T.round];
  if (rd.some((mt) => !mt.w)) return;
  const winners = rd.map((mt) => mt.w).filter((w) => w && w !== "-");
  if (winners.length <= 1) {
    T.done = true;
    T.champ = winners[0] || null;
    if (T.champ) tourPrize.set(T.champ, T.fee * T.players.length + 50 * T.players.length);
    sendTour(T, "end");
    return;
  }
  const next = [];
  for (let i = 0; i < winners.length; i += 2) next.push({ a: winners[i], b: winners[i + 1] || null, w: null, live: false });
  T.rounds.push(next);
  T.round++;
  setTimeout(() => tourPlay(T), 4000);
}

function sendTour(T, phase) {
  const d = { t: "tour", id: T.id, game: T.game, fee: T.fee, pot: T.fee * T.players.length, n: T.players.length, names: T.names,
    rounds: T.rounds.map((rd) => rd.map((mt) => ({ a: mt.a, b: mt.b, w: mt.w, live: mt.live }))), round: T.round, done: T.done, champ: T.champ, out: [...T.out], phase: phase || "" };
  for (const code of T.players) { const o = clients.get(code); if (o) sendJ(o, d); }
}
