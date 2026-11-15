// @ts-nocheck
// GoPedido — Edge Function "ff-mercadopago"
// Pagamento online OPCIONAL por loja: cada lojista conecta a conta do Mercado Pago dele e o dinheiro
// cai direto nessa conta. O GoPedido não cobra comissão e não recebe nada das vendas.
// Precisa do SQL v23 rodado antes.
//
// Ações (POST, corpo JSON):
//   { acao: 'url',         loja }     → link para o lojista autorizar a conta dele (só o dono)
//   { acao: 'conectar',    loja, code } → guarda as chaves que o Mercado Pago devolveu (só o dono)
//   { acao: 'desconectar', loja }     → apaga as chaves e desliga o pagamento online (só o dono)
//   { acao: 'status',      loja }     → se a conta continua válida e o nome dela (dono ou equipe)
//   { acao: 'iniciar',     token }    → dados para o pagamento dentro da página do pedido (chave pública da loja)
//   { acao: 'pix',         token, email? } → cria o Pix e devolve o QR Code e o copia e cola
//   { acao: 'cartao',      token, dados }  → paga com cartão (dados vêm do formulário seguro do Mercado Pago)
//   { acao: 'pagar',       token }    → alternativa: link para pagar na página do Mercado Pago
//   { acao: 'conferir',    token | pedido } → pergunta ao Mercado Pago se o pedido já foi pago
//   { acao: 'estornar',    pedido }   → devolve o dinheiro de um pedido pago (dono ou equipe)
// Usa a API de Orders do Mercado Pago (a de Payments está sendo descontinuada). O link alternativo (Checkout Pro) usa preferências.
// Aviso do Mercado Pago (webhook): POST ?acao=aviso  — configure em Suas integrações → Webhooks, tópico "Order".
//   O servidor nunca confia no aviso: sempre consulta a order no Mercado Pago com a chave da loja antes de marcar como pago.
//
// Como publicar: Supabase → Edge Functions → "Deploy a new function" → "Via Editor"
//   nome: ff-mercadopago → cole este arquivo inteiro → Deploy → em Details desligue "Verify JWT".
// Segredos (Edge Functions → Secrets): MP_CLIENT_ID, MP_CLIENT_SECRET
// Opcional: MP_REDIRECT (padrão https://goscripts.com.br/delivery/painel.html)
//           MP_TESTE = 1 enquanto testa com contas de teste (usa o comprador test@testuser.com)
// Planos do GoPedido (SQL v27) — o dinheiro cai na conta do GoPedido, não na da loja:
//           MP_PLANO_TOKEN      = Access Token de produção da conta que recebe os planos (só aqui, nunca no site)
//           MP_PLANO_PUBLIC_KEY = Public Key dessa mesma conta (para o formulário de cartão)
//   { acao: 'plano_info' } · { acao: 'plano_pix', plano, meses, qtd? } (plano 'extra' = produtos a mais, só Premium, SQL v28;
//     'extra_assin' = assinantes a mais, SQL v33) · { acao: 'plano_cartao', plano, meses, token, dados } · { acao: 'plano_conferir', id }
// Lojas de assinatura (SQL v33) — o dinheiro cai na conta Mercado Pago da loja:
//   { acao: 'assin_novo', loja, plano, nome, email, telefone } → cria o assinante (pendente) e devolve o link de pagamento
//   { acao: 'assin_info', token } · { acao: 'assin_pix', token, meses, plano? } · { acao: 'assin_cartao', token, meses, plano?, dados } · { acao: 'assin_conferir', id }

import { createClient } from 'npm:@supabase/supabase-js@2';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS'
};
const SITE = 'https://goscripts.com.br/delivery/';
const API = 'https://api.mercadopago.com';

class Falha extends Error {
  constructor(codigo, status = 400, detalhe = '') { super(codigo); this.status = status; this.detalhe = detalhe; }
}
const ok = (r, onde) => { if (r && r.error) throw new Falha('erro_banco', 500, onde + ': ' + (r.error.message || r.error)); return r; };
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const centavos = (v) => Math.round(Number(v || 0) * 100);
const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;

// Situação do Mercado Pago → situação do pedido
// Situação de uma order (API de Orders) → situação do pedido
export function situacaoOrdem(o) {
  const st = String(o && o.status || ''), det = String(o && o.status_detail || '');
  if (st === 'refunded' || det === 'refunded') return 'estornado';
  if (st === 'processed' && (det === 'accredited' || det === 'partially_refunded' || !det)) return 'aprovado';
  if (st === 'failed' || st === 'canceled' || st === 'cancelled' || st === 'expired') return 'recusado';
  return 'pendente';   // created, action_required (esperando o Pix), processing…
}
const ORD = /^[A-Za-z0-9]{8,40}$/;
const valor = (v) => Number(v || 0).toFixed(2);   // a API de Orders recebe valores como texto: "50.00"

export function situacao(st) {
  if (st === 'approved') return 'aprovado';
  if (st === 'refunded' || st === 'charged_back') return 'estornado';
  if (st === 'rejected' || st === 'cancelled') return 'recusado';
  return 'pendente';   // pending, in_process, authorized…
}

export async function tratar(req, admin, env, http = fetch, fnUrl = '') {
  if (req.method === 'OPTIONS') return { status: 200, corpo: 'ok' };
  if (req.method !== 'POST') throw new Falha('metodo_invalido', 405);
  if (!env.MP_CLIENT_ID || !env.MP_CLIENT_SECRET) throw new Falha('mp_nao_configurado', 500, 'faltam os segredos MP_CLIENT_ID / MP_CLIENT_SECRET');
  const REDIRECT = env.MP_REDIRECT || SITE + 'painel.html';
  // Modo teste do Mercado Pago: a API de Orders só aceita este comprador de teste
  const TESTE = env.MP_TESTE === '1';
  const compradorTeste = (email) => TESTE ? 'test@testuser.com' : email;
  const url = new URL(req.url);

  // ---------- aviso do Mercado Pago (webhook) ----------
  if (url.searchParams.get('acao') === 'aviso') {
    const corpo = (await req.json().catch(() => ({}))) || {};
    let lojaId = url.searchParams.get('loja') || '';
    const tipo = String(corpo.type || corpo.topic || url.searchParams.get('type') || url.searchParams.get('topic') || '');
    const id = String((corpo.data && corpo.data.id) || url.searchParams.get('data.id') || url.searchParams.get('id') || '');
    try {
      // Pagamento de plano (conta do GoPedido)
      if (env.MP_PLANO_TOKEN && /order/.test(tipo) && ORD.test(id) && /^\d{1,20}$/.test(String(corpo.user_id || '')) && String(corpo.user_id) === await idContaPlano()) {
        const o = await mpPlano('GET', '/v1/orders/' + encodeURIComponent(id));
        await gravarPlano(o);
        return { status: 200, corpo: { ok: true } };
      }
      // Aviso configurado no painel do aplicativo não traz a loja: acha pela conta do Mercado Pago do vendedor
      if (!UUID.test(lojaId) && /^\d{1,20}$/.test(String(corpo.user_id || ''))) {
        const { data } = await admin.from('ff_mp_contas').select('loja_id').eq('mp_user_id', String(corpo.user_id)).limit(1).maybeSingle();
        lojaId = data && data.loja_id || '';
      }
      // Responde 200 mesmo quando não é para nós: senão o Mercado Pago fica reenviando
      if (UUID.test(lojaId)) {
        if (/order/.test(tipo) && ORD.test(id)) await aplicarOrdem(lojaId, id);
        else if (/payment/.test(tipo) && /^\d{1,20}$/.test(id)) await aplicarPagamento(lojaId, id);
      }
    } catch (_) { /* o cliente ainda pode conferir pela página do pedido */ }
    return { status: 200, corpo: { ok: true } };
  }

  const b = (await req.json().catch(() => ({}))) || {};
  const acao = String(b.acao || '');

  // ---------- quem está chamando ----------
  let usuario = null;
  const tok = (req.headers.get('Authorization') || '').replace(/^Bearer\s+/i, '');
  if (tok) { const { data } = await admin.auth.getUser(tok); usuario = data && data.user || null; }
  const precisaLogin = () => { if (!usuario) throw new Falha('nao_logado', 401); };
  async function pegaLoja(id) {
    if (!UUID.test(String(id || ''))) throw new Falha('loja_invalida');
    const { data } = ok(await admin.from('ff_lojas').select('*').eq('id', id).maybeSingle(), 'loja');
    if (!data) throw new Falha('loja_invalida', 404);
    return data;
  }
  const exigeDono = (l) => { precisaLogin(); if (String(l.dono) !== String(usuario.id)) throw new Falha('so_dono', 403); };
  async function exigeEquipe(l) {
    precisaLogin();
    if (String(l.dono) === String(usuario.id)) return;
    const { data } = ok(await admin.from('ff_equipe').select('todas, lojas').eq('user_id', usuario.id).eq('dono', l.dono).maybeSingle(), 'equipe');
    if (!data || !(data.todas || (data.lojas || []).map(String).includes(String(l.id)))) throw new Falha('sem_acesso', 403);
  }

  return await acoes();

  // ================= funções =================
  // ----- planos do GoPedido (conta do GoPedido) -----
  async function mpPlano(metodo, caminho, corpo, extra = {}) {
    if (!env.MP_PLANO_TOKEN) throw new Falha('planos_nao_configurados', 500, 'falta o segredo MP_PLANO_TOKEN');
    const r = await http(API + caminho, { method: metodo, headers: { 'Content-Type': 'application/json', 'Accept': 'application/json', 'Authorization': 'Bearer ' + env.MP_PLANO_TOKEN, ...extra }, body: corpo === undefined ? undefined : JSON.stringify(corpo) });
    const texto = await r.text(); let j; try { j = texto ? JSON.parse(texto) : {}; } catch (_) { j = { message: texto.slice(0, 200) }; }
    const e0 = (j && Array.isArray(j.errors) && j.errors[0]) || {}, det = [].concat(e0.details || []).map(String).join(', ');
    if (!r.ok) {
      const ord = (j && j.data && j.data.id) ? j.data : (j && j.id && j.transactions ? j : null);
      if (ord) { ord._detalhe = det || e0.code || ''; return ord; }
      throw new Falha('mp_erro', 400, [j.message || j.error || e0.message || e0.code, det].filter(Boolean).join(' · ') || ('HTTP ' + r.status));
    }
    return j;
  }
  async function idContaPlano() {
    try { const u = await mpPlano('GET', '/users/me'); return String(u.id || ''); } catch (_) { return ''; }
  }
  // Grava o resultado da order do plano; aprovado e com o valor certo → libera o plano
  async function gravarPlano(o) {
    const ref = String(o.external_reference || '');
    // código do pedido do plano: "plano-<id>" (o Mercado Pago só aceita letras, números, - e _)
    if (!/^plano[-:]/.test(ref)) return null;
    const id = ref.slice(6); if (!UUID.test(id)) return null;
    const { data: g } = ok(await admin.from('ff_plano_pagamentos').select('*').eq('id', id).maybeSingle(), 'pagamento');
    if (!g) return null;
    let st = situacaoOrdem(o);
    const pago = Number(o.total_paid_amount || o.total_amount || 0);
    if (st === 'aprovado' && centavos(pago) < centavos(g.valor)) st = 'pendente';
    if (g.status === 'aprovado') return g;
    if (st === 'aprovado') { ok(await admin.rpc('ff_plano_aplicar', { p_pag: g.id }), 'liberar plano'); }
    else if (st !== g.status && !(g.status === 'pendente' && st === 'recusado' && g.metodo === 'pix')) ok(await admin.from('ff_plano_pagamentos').update({ status: st }).eq('id', g.id), 'situação');
    const { data } = ok(await admin.from('ff_plano_pagamentos').select('*').eq('id', g.id).maybeSingle(), 'pagamento');
    return data;
  }
  // Só o dono da conta compra plano (quem é da equipe não)
  async function exigeDonoConta() {
    precisaLogin();
    const { data } = ok(await admin.from('ff_equipe').select('dono').eq('user_id', usuario.id).limit(1).maybeSingle(), 'equipe');
    if (data) throw new Falha('so_dono', 403);
  }
  async function calcPlano(plano, meses, qtd = 0) {
    if (!['profissional', 'premium', 'extra', 'extra_assin'].includes(String(plano)) || ![1, 2, 3].includes(Number(meses))) throw new Falha('plano_invalido');
    const { data } = plano === 'extra' || plano === 'extra_assin'
      ? ok(await admin.rpc(plano === 'extra' ? 'ff_extra_calc' : 'ff_extra_assin_calc', { p_email: usuario.email, p_qtd: Math.floor(Number(qtd) || 0), p_meses: Number(meses) }), 'preço')
      : ok(await admin.rpc('ff_plano_calc', { p_email: usuario.email, p_plano: plano, p_meses: Number(meses) }), 'preço');
    if (data && data.erro) throw new Falha(data.erro, 400, data.valido_ate ? String(data.valido_ate) : '');
    return data;
  }
  async function novoPagamentoPlano(plano, meses, metodo, qtd = 0) {
    const c = await calcPlano(plano, meses, qtd);
    const { data } = ok(await admin.from('ff_plano_pagamentos').insert({ user_id: usuario.id, email: String(usuario.email).toLowerCase(), plano, meses: Number(meses), valor: c.valor, metodo, ...(plano === 'extra' || plano === 'extra_assin' ? { qtd: Math.floor(Number(qtd)) } : {}) }).select('*').single(), 'criar pagamento');
    return { g: data, c };
  }
  function descPlano(g) { return g.plano === 'extra_assin' ? `GoPedido · +${g.qtd} assinantes extras · ${g.meses} ${g.meses > 1 ? 'meses' : 'mês'}` : g.plano === 'extra' ? `GoPedido · +${g.qtd} produtos extras · ${g.meses} ${g.meses > 1 ? 'meses' : 'mês'}` : `GoPedido · Plano ${g.plano === 'premium' ? 'Premium' : 'Profissional'} · ${g.meses} ${g.meses > 1 ? 'meses' : 'mês'}`; }

  async function pedirToken(corpo) {
    const r = await http(API + '/oauth/token', {
      method: 'POST', headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
      body: JSON.stringify({ client_id: env.MP_CLIENT_ID, client_secret: env.MP_CLIENT_SECRET, ...corpo })
    });
    const j = await r.json().catch(() => ({}));
    if (!r.ok || !j.access_token) throw new Falha('mp_autorizacao', 400, j.message || j.error_description || j.error || ('HTTP ' + r.status));
    return j;
  }
  async function salvarConta(lojaId, j) {
    ok(await admin.from('ff_mp_contas').upsert({
      loja_id: lojaId, access_token: j.access_token, refresh_token: j.refresh_token || '',
      ...(j.public_key ? { public_key: j.public_key } : {}),
      mp_user_id: String(j.user_id || ''),
      expira: new Date(Date.now() + (Number(j.expires_in) > 0 ? Number(j.expires_in) - 3600 : 15552000) * 1000).toISOString(),
      atualizado_em: new Date().toISOString()
    }), 'salvar conta');
  }
  async function desligar(lojaId) {
    ok(await admin.from('ff_lojas').update({ mp_conectado: false, aceita_mp: false }).eq('id', lojaId), 'desligar');
  }
  // Chave válida da loja (renova sozinha uns dias antes de vencer; a do Mercado Pago dura 180 dias)
  async function chaveDaLoja(lojaId) {
    const { data: c } = ok(await admin.from('ff_mp_contas').select('*').eq('loja_id', lojaId).maybeSingle(), 'conta');
    if (!c) throw new Falha('mp_desconectado');
    if (new Date(c.expira).getTime() - Date.now() > 3 * 86400000) return c.access_token;
    if (!c.refresh_token) { await desligar(lojaId); throw new Falha('mp_desconectado'); }
    try {
      const j = await pedirToken({ grant_type: 'refresh_token', refresh_token: c.refresh_token });
      await salvarConta(lojaId, j);
      return j.access_token;
    } catch (e) { await desligar(lojaId); throw new Falha('mp_desconectado', 400, e.detalhe || ''); }
  }
  async function mp(lojaId, metodo, caminho, corpo, extra = {}) {
    const chave = await chaveDaLoja(lojaId);
    const r = await http(API + caminho, {
      method: metodo,
      headers: { 'Content-Type': 'application/json', 'Accept': 'application/json', 'Authorization': 'Bearer ' + chave, ...extra },
      body: corpo === undefined ? undefined : JSON.stringify(corpo)
    });
    const texto = await r.text();
    let j; try { j = texto ? JSON.parse(texto) : {}; } catch (_) { j = { message: texto.slice(0, 200) }; }
    if (r.status === 401) { await desligar(lojaId); throw new Falha('mp_desconectado'); }
    // API de Orders: pagamento recusado volta 402 com { errors: [{ code, message, details }], data: order }
    const e0 = (j && Array.isArray(j.errors) && j.errors[0]) || {};
    const det = [].concat(e0.details || []).map(String).join(', ');
    if (!r.ok) {
      const ord = (j && j.data && j.data.id) ? j.data : (j && j.id && j.transactions ? j : null);
      if (ord) { ord._detalhe = det || e0.code || ''; return ord; }
    }
    if (!r.ok) throw new Falha('mp_erro', 400, [j.message || j.error || e0.message || e0.code, det, (j.cause && j.cause[0] && j.cause[0].description) || ''].filter(Boolean).join(' · ') || ('HTTP ' + r.status));
    return j;
  }

  // Grava no pedido o que o Mercado Pago diz sobre um pagamento (sempre consultando o Mercado Pago)
  async function aplicarPagamento(lojaId, pagamentoId) {
    const pg = await mp(lojaId, 'GET', '/v1/payments/' + encodeURIComponent(pagamentoId));
    return gravar(lojaId, pg);
  }
  async function gravar(lojaId, pg) {
    const pedidoId = String(pg.external_reference || '');
    if (!UUID.test(pedidoId)) return null;
    const { data: p } = ok(await admin.from('ff_pedidos').select('*').eq('id', pedidoId).eq('loja_id', lojaId).maybeSingle(), 'pedido');
    if (!p || p.pagamento !== 'mp') return null;
    let st = situacao(pg.status);
    // Só aprova se o valor pago bate com o total do pedido (ninguém paga R$ 1 por um pedido de R$ 100)
    if (st === 'aprovado' && centavos(pg.transaction_amount) < centavos(p.total)) st = 'pendente';
    // Um pagamento recusado não desfaz um aprovado anterior (o cliente pode ter tentado dois cartões)
    if (p.mp_status === 'aprovado' && st === 'recusado') return p;
    if (p.mp_status === 'estornado' && st !== 'estornado') return p;
    const mud = { mp_status: st, mp_pagamento_id: String(pg.id || '') };
    if (st === 'aprovado' && !p.pago_em) mud.pago_em = new Date().toISOString();
    if (p.mp_status === mud.mp_status && p.mp_pagamento_id === mud.mp_pagamento_id) return p;
    const { data } = ok(await admin.from('ff_pedidos').update(mud).eq('id', p.id).select('*').maybeSingle(), 'gravar');
    return data;
  }
  async function aplicarOrdem(lojaId, ordemId) {
    const o = await mp(lojaId, 'GET', '/v1/orders/' + encodeURIComponent(ordemId));
    if (/^assin-/.test(String(o.external_reference || ''))) return gravarAssin(lojaId, o);
    return gravarOrdem(lojaId, o);
  }

  // ----- lojas de assinatura (conta Mercado Pago da loja) -----
  async function gravarAssin(lojaId, o) {
    const id = String(o.external_reference || '').slice(6); if (!UUID.test(id)) return null;
    const { data: g } = ok(await admin.from('ff_assin_pagamentos').select('*').eq('id', id).eq('loja_id', lojaId).maybeSingle(), 'pagamento');
    if (!g) return null;
    if (g.status === 'aprovado') return g;
    let st = situacaoOrdem(o);
    const pago = Number(o.total_paid_amount || o.total_amount || 0);
    if (st === 'aprovado' && centavos(pago) < centavos(g.valor)) st = 'pendente';
    if (st === 'aprovado') ok(await admin.rpc('ff_assin_aplicar', { p_pag: g.id }), 'renovar assinatura');
    else if (st !== g.status && !(g.status === 'pendente' && st === 'recusado' && g.metodo === 'pix')) ok(await admin.from('ff_assin_pagamentos').update({ status: st }).eq('id', g.id), 'situação');
    const { data } = ok(await admin.from('ff_assin_pagamentos').select('*').eq('id', g.id).maybeSingle(), 'pagamento');
    return data;
  }
  async function assinantePor(token) {
    if (!/^[a-f0-9]{32,64}$/i.test(String(token || ''))) throw new Falha('assinante_invalido');
    const { data: a } = ok(await admin.from('ff_assinantes').select('*').eq('token', token).maybeSingle(), 'assinante');
    if (!a) throw new Falha('assinante_invalido', 404);
    if (a.status === 'cancelado') throw new Falha('assinante_cancelado');
    const { data: l } = ok(await admin.from('ff_lojas').select('id, nome, slug, tipo, imagem_url, cor, telefone, mp_conectado, ativa, verificacao').eq('id', a.loja_id).maybeSingle(), 'loja');
    if (!l) throw new Falha('loja_invalida', 404);
    return { a, l };
  }
  async function lojaAssinPodeCobrar(l, novo) {
    if (l.tipo !== 'assinatura' || !l.ativa || l.verificacao !== 'verificada') throw new Falha('loja_indisponivel');
    if (!l.mp_conectado) throw new Falha('mp_desconectado');
    const { data: bq } = ok(await admin.rpc('ff_bloqueio_loja', { p_loja: l.id }), 'bloqueio');
    if (bq) throw new Falha('loja_bloqueada_plano');
    if (novo) { const { data: cabe } = ok(await admin.rpc('ff_assin_cabe', { p_loja: l.id }), 'vagas'); if (!cabe) throw new Falha('sem_vagas'); }
  }
  async function planoAssin(lojaId, planoId) {
    if (!UUID.test(String(planoId || ''))) throw new Falha('plano_invalido');
    const { data: pl } = ok(await admin.from('ff_assin_planos').select('*').eq('id', planoId).eq('loja_id', lojaId).maybeSingle(), 'plano');
    if (!pl || !pl.ativo) throw new Falha('plano_invalido');
    return pl;
  }
  function precoAssin(pl, meses) {
    const v = Number((pl.precos || {})[String(meses)]);
    if (![1, 3, 6, 12].includes(Number(meses)) || !(v > 0)) throw new Falha('periodo_invalido');
    return Math.round(v * 100) / 100;
  }
  function descAssin(pl, l, meses) { return `${pl.nome} · ${meses} ${meses > 1 ? 'meses' : 'mês'} · ${l.nome}`.slice(0, 200); }
  async function novoPagAssin(a, l, pl, meses, metodo) {
    await lojaAssinPodeCobrar(l, a.status !== 'ativo');
    const { data } = ok(await admin.from('ff_assin_pagamentos').insert({ assinante_id: a.id, loja_id: l.id, plano_id: pl.id, meses: Number(meses), valor: precoAssin(pl, meses), metodo }).select('*').single(), 'criar pagamento');
    return data;
  }
  async function gravarOrdem(lojaId, o) {
    const pedidoId = String(o.external_reference || '');
    if (!UUID.test(pedidoId)) return null;
    const { data: p } = ok(await admin.from('ff_pedidos').select('*').eq('id', pedidoId).eq('loja_id', lojaId).maybeSingle(), 'pedido');
    if (!p || p.pagamento !== 'mp') return null;
    let st = situacaoOrdem(o);
    const pago = Number(o.total_paid_amount || o.total_amount || 0);
    if (st === 'aprovado' && centavos(pago) < centavos(p.total)) st = 'pendente';
    if (p.mp_status === 'aprovado' && st !== 'aprovado' && st !== 'estornado') return p;
    if (p.mp_status === 'estornado' && st !== 'estornado') return p;
    // uma tentativa recusada não apaga um Pix ainda em aberto de outra tentativa
    const mud = { mp_status: st, mp_pagamento_id: String(o.id || '') };
    if (st === 'aprovado' && !p.pago_em) mud.pago_em = new Date().toISOString();
    if (p.mp_status === mud.mp_status && p.mp_pagamento_id === mud.mp_pagamento_id) return p;
    const { data } = ok(await admin.from('ff_pedidos').update(mud).eq('id', p.id).select('*').maybeSingle(), 'gravar');
    return data;
  }

  async function pedidoPor() {
    let q = admin.from('ff_pedidos').select('*');
    if (UUID.test(String(b.pedido || ''))) q = q.eq('id', b.pedido);
    else if (/^[a-z0-9]{8,40}$/i.test(String(b.token || ''))) q = q.eq('token', b.token);
    else throw new Falha('pedido_invalido');
    const { data } = ok(await q.maybeSingle(), 'pedido');
    if (!data) throw new Falha('pedido_invalido', 404);
    if (data.pagamento !== 'mp') throw new Falha('nao_e_online');
    return data;
  }
  function resumo(p) { return { mp_status: p.mp_status, pago_em: p.pago_em, status: p.status }; }
  // Pedido que ainda pode ser pago online
  async function pedidoParaPagar() {
    const p = await pedidoPor();
    if (p.status === 'cancelado') throw new Falha('pedido_cancelado');
    const { data: l } = ok(await admin.from('ff_lojas').select('id, nome, mp_conectado, aceita_mp').eq('id', p.loja_id).maybeSingle(), 'loja');
    if (!l || !l.mp_conectado || !l.aceita_mp) throw new Falha('mp_desconectado');
    return { p, l };
  }
  function descricao(p, l) { return `Pedido #${p.numero} · ${l.nome}`.slice(0, 200); }

  async function acoes() {
    if (acao === 'url') {
      const l = await pegaLoja(b.loja); exigeDono(l);
      const q = new URLSearchParams({ client_id: env.MP_CLIENT_ID, response_type: 'code', platform_id: 'mp', state: 'mp:' + l.id, redirect_uri: REDIRECT });
      return { status: 200, corpo: { url: 'https://auth.mercadopago.com.br/authorization?' + q.toString() } };
    }

    if (acao === 'conectar') {
      const l = await pegaLoja(b.loja); exigeDono(l);
      if (!/^[A-Za-z0-9_-]{6,200}$/.test(String(b.code || ''))) throw new Falha('codigo_invalido');
      const j = await pedirToken({ grant_type: 'authorization_code', code: b.code, redirect_uri: REDIRECT });
      await salvarConta(l.id, j);
      let conta = '';
      try {
        const r = await http(API + '/users/me', { headers: { 'Authorization': 'Bearer ' + j.access_token } });
        const u = await r.json().catch(() => ({}));
        conta = String(u.nickname || u.email || '').slice(0, 80);
      } catch (_) { /* o nome da conta é só para mostrar */ }
      ok(await admin.from('ff_lojas').update({ mp_conectado: true, mp_conta: conta }).eq('id', l.id), 'marcar');
      return { status: 200, corpo: { ok: true, conta } };
    }

    if (acao === 'desconectar') {
      const l = await pegaLoja(b.loja); exigeDono(l);
      ok(await admin.from('ff_mp_contas').delete().eq('loja_id', l.id), 'apagar');
      ok(await admin.from('ff_lojas').update({ mp_conectado: false, mp_conta: '', aceita_mp: false }).eq('id', l.id), 'desmarcar');
      return { status: 200, corpo: { ok: true } };
    }

    if (acao === 'status') {
      const l = await pegaLoja(b.loja); await exigeEquipe(l);
      if (!l.mp_conectado) return { status: 200, corpo: { conectado: false } };
      try { await mp(l.id, 'GET', '/users/me'); return { status: 200, corpo: { conectado: true, conta: l.mp_conta } }; }
      catch (e) { if (e.message === 'mp_desconectado') return { status: 200, corpo: { conectado: false } }; throw e; }
    }

    if (acao === 'iniciar') {
      const { p, l } = await pedidoParaPagar();
      if (p.mp_status === 'aprovado') return { status: 200, corpo: { pago: true } };
      await chaveDaLoja(l.id);   // confere se a conta continua conectada (e renova se precisar)
      const { data: c } = ok(await admin.from('ff_mp_contas').select('public_key').eq('loja_id', l.id).maybeSingle(), 'chave pública');
      return { status: 200, corpo: { public_key: (c && c.public_key) || '', total: Number(p.total), email: p.cliente_email || '' } };
    }

    if (acao === 'pix') {
      const { p, l } = await pedidoParaPagar();
      if (p.mp_status === 'aprovado') return { status: 200, corpo: { pago: true } };
      const qr = (o) => {
        const pg = (o.transactions && o.transactions.payments || [])[0] || {};
        const m = pg.payment_method || {};
        return { qr: m.qr_code || '', qr_img: m.qr_code_base64 || '', link: m.ticket_url || '', valor: Number(pg.amount || o.total_amount) };
      };
      // Já existe um Pix em aberto para este pedido com o mesmo valor? Mostra o mesmo QR Code
      if (ORD.test(p.mp_pagamento_id || '') && !/^\d+$/.test(p.mp_pagamento_id)) {
        try {
          const ant = await mp(l.id, 'GET', '/v1/orders/' + p.mp_pagamento_id);
          const st = situacaoOrdem(ant);
          if (st === 'aprovado') { await gravarOrdem(l.id, ant); return { status: 200, corpo: { pago: true } }; }
          const q = qr(ant);
          if (st === 'pendente' && q.qr && centavos(ant.total_amount) === centavos(p.total)) return { status: 200, corpo: q };
        } catch (_) { /* cria um novo */ }
      }
      const email = String(p.cliente_email || b.email || '').trim().toLowerCase();
      if (!EMAIL.test(email)) throw new Falha('email_obrigatorio');
      const o = await mp(l.id, 'POST', '/v1/orders', {
        type: 'online', processing_mode: 'automatic',
        total_amount: valor(p.total),
        external_reference: p.id,
        description: descricao(p, l),
        transactions: { payments: [{ amount: valor(p.total), payment_method: { id: 'pix', type: 'bank_transfer' }, expiration_time: 'PT2H' }] },
        payer: { email: compradorTeste(email), first_name: TESTE ? 'APRO' : (String(p.cliente_nome || '').split(' ')[0].replace(/[^A-Za-zÀ-ÿ ]/g, '').slice(0, 40) || 'Cliente') }
      }, { 'X-Idempotency-Key': 'pix-' + p.id + '-' + centavos(p.total) + '-' + Math.floor(Date.now() / 600000) });
      ok(await admin.from('ff_pedidos').update({ mp_pagamento_id: String(o.id) }).eq('id', p.id), 'pix');
      return { status: 200, corpo: qr(o) };
    }

    if (acao === 'cartao') {
      const { p, l } = await pedidoParaPagar();
      if (p.mp_status === 'aprovado') return { status: 200, corpo: { ...resumo(p), pago: true } };
      const d = b.dados || {};
      if (!/^[A-Za-z0-9]{20,64}$/.test(String(d.token || ''))) throw new Falha('cartao_invalido');
      const email = String((d.payer && d.payer.email) || p.cliente_email || '').trim().toLowerCase();
      if (!EMAIL.test(email)) throw new Falha('email_obrigatorio');
      const ident = d.payer && d.payer.identification;
      const o = await mp(l.id, 'POST', '/v1/orders', {
        type: 'online', processing_mode: 'automatic',
        // o valor é sempre o total do pedido no banco, nunca o que vem do navegador
        total_amount: valor(p.total),
        external_reference: p.id,
        description: descricao(p, l),
        transactions: { payments: [{ amount: valor(p.total), payment_method: {
          id: String(d.payment_method_id || '').slice(0, 40), type: 'credit_card', token: d.token,
          installments: Math.max(1, Math.min(12, parseInt(d.installments, 10) || 1)),
          statement_descriptor: l.nome.replace(/[^A-Za-z0-9 ]/g, '').slice(0, 13) || 'GOPEDIDO'
        } }] },
        payer: { email: compradorTeste(email), ...(ident && ident.number ? { identification: { type: String(ident.type || 'CPF').slice(0, 10), number: String(ident.number).replace(/\D/g, '').slice(0, 14) } } : {}) }
      }, { 'X-Idempotency-Key': 'cartao-' + p.id + '-' + d.token.slice(-16) });
      const novo = (await gravarOrdem(l.id, o)) || p;
      const pg = (o.transactions && o.transactions.payments || [])[0] || {};
      return { status: 200, corpo: { ...resumo(novo), detalhe: pg.status_detail || o.status_detail || o._detalhe || '' } };
    }

    if (acao === 'pagar') {
      const p = await pedidoPor();
      if (p.status === 'cancelado') throw new Falha('pedido_cancelado');
      if (p.mp_status === 'aprovado') return { status: 200, corpo: { pago: true } };
      const { data: l } = ok(await admin.from('ff_lojas').select('id, nome, mp_conectado, aceita_mp').eq('id', p.loja_id).maybeSingle(), 'loja');
      if (!l || !l.mp_conectado || !l.aceita_mp) throw new Falha('mp_desconectado');
      const volta = SITE + 'pedido.html?t=' + encodeURIComponent(p.token) + '&mp=1';
      const pref = await mp(l.id, 'POST', '/checkout/preferences', {
        items: [{ id: p.id, title: `Pedido #${p.numero} · ${l.nome}`.slice(0, 250), quantity: 1, currency_id: 'BRL', unit_price: Number(Number(p.total).toFixed(2)) }],
        payer: p.cliente_email ? { email: p.cliente_email, name: p.cliente_nome } : { name: p.cliente_nome },
        external_reference: p.id,
        notification_url: fnUrl + '?acao=aviso&loja=' + l.id,
        back_urls: { success: volta, pending: volta, failure: volta },
        auto_return: 'approved',
        // boleto demora dias para compensar: não serve para delivery
        payment_methods: { excluded_payment_types: [{ id: 'ticket' }, { id: 'atm' }] },
        statement_descriptor: l.nome.replace(/[^A-Za-z0-9 ]/g, '').slice(0, 13) || 'GOPEDIDO',
        expires: true,
        expiration_date_to: new Date(Date.now() + 2 * 3600000).toISOString(),
        metadata: { pedido: p.id, numero: p.numero }
      }, { 'X-Idempotency-Key': 'pref-' + p.id + '-' + centavos(p.total) });
      return { status: 200, corpo: { url: pref.init_point } };
    }

    if (acao === 'conferir') {
      let p = await pedidoPor();
      if (p.pagamento !== 'mp' || p.mp_status === 'aprovado' || p.mp_status === 'estornado') return { status: 200, corpo: resumo(p) };
      if (ORD.test(p.mp_pagamento_id || '') && !/^\d+$/.test(p.mp_pagamento_id)) {
        p = (await aplicarOrdem(p.loja_id, p.mp_pagamento_id)) || p;
        if (p.mp_status === 'aprovado') return { status: 200, corpo: resumo(p) };
      }
      if (/^\d{1,20}$/.test(String(b.pagamento || ''))) {
        p = (await aplicarPagamento(p.loja_id, b.pagamento)) || p;
        if (p.mp_status === 'aprovado') return { status: 200, corpo: resumo(p) };
      }
      const r = await mp(p.loja_id, 'GET', '/v1/payments/search?sort=date_created&criteria=desc&external_reference=' + encodeURIComponent(p.id));
      const lista = (r.results || []);
      const melhor = lista.find(x => x.status === 'approved') || lista[0];
      if (melhor) p = (await gravar(p.loja_id, melhor)) || p;
      return { status: 200, corpo: resumo(p) };
    }

    // ===== Lojas de assinatura =====
    if (acao === 'assin_novo') {
      const l = await pegaLoja(b.loja);
      await lojaAssinPodeCobrar(l, false);
      const pl = await planoAssin(l.id, b.plano);
      const nome = String(b.nome || '').trim().slice(0, 80), email = String(b.email || '').trim().toLowerCase(), tel = String(b.telefone || '').replace(/\D/g, '').slice(0, 13);
      if (nome.length < 2) throw new Falha('nome_obrigatorio');
      if (!EMAIL.test(email)) throw new Falha('email_obrigatorio');
      const { data: ex } = ok(await admin.from('ff_assinantes').select('id, token, status').eq('loja_id', l.id).eq('plano_id', pl.id).eq('email', email).neq('status', 'cancelado').maybeSingle(), 'assinante');
      if (ex && ex.status === 'ativo') {
        // já é assinante: manda o link de renovação para o e-mail dele (não mostra o link aqui)
        try { await http(fnUrl.replace('ff-mercadopago', 'ff-email'), { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ acao: 'assin_link', id: ex.id }) }); } catch (_) {}
        return { status: 200, corpo: { ja_assinante: true } };
      }
      if (ex) { ok(await admin.from('ff_assinantes').update({ nome, telefone: tel }).eq('id', ex.id), 'atualizar'); return { status: 200, corpo: { token: ex.token } }; }
      const { data: cabe } = ok(await admin.rpc('ff_assin_cabe', { p_loja: l.id }), 'vagas'); if (!cabe) throw new Falha('sem_vagas');
      const { data: a } = ok(await admin.from('ff_assinantes').insert({ loja_id: l.id, plano_id: pl.id, nome, email, telefone: tel, origem: 'site' }).select('token').single(), 'criar assinante');
      return { status: 200, corpo: { token: a.token } };
    }

    if (acao === 'assin_info') {
      const { a, l } = await assinantePor(b.token);
      const { data: planos } = ok(await admin.from('ff_assin_planos').select('id, nome, descricao, precos, entrega_codigo').eq('loja_id', l.id).eq('ativo', true).order('ordem').order('criado_em'), 'planos');
      let public_key = '';
      if (l.mp_conectado) { try { await chaveDaLoja(l.id); const { data: c } = ok(await admin.from('ff_mp_contas').select('public_key').eq('loja_id', l.id).maybeSingle(), 'chave'); public_key = (c && c.public_key) || ''; } catch (_) {} }
      const { data: hist } = ok(await admin.from('ff_assin_pagamentos').select('id, meses, valor, status, metodo, criado_em, pago_em, valido_ate').eq('assinante_id', a.id).order('criado_em', { ascending: false }).limit(6), 'histórico');
      return { status: 200, corpo: {
        assinante: { nome: a.nome, email: a.email, status: a.status, valido_ate: a.valido_ate, plano_id: a.plano_id },
        loja: { id: l.id, nome: l.nome, slug: l.slug, imagem_url: l.imagem_url, cor: l.cor, telefone: l.telefone, pode_pagar: !!l.mp_conectado },
        planos: planos || [], public_key, historico: hist || [] } };
    }

    if (acao === 'assin_pix' || acao === 'assin_cartao') {
      const { a, l } = await assinantePor(b.token);
      const pl = await planoAssin(l.id, b.plano || a.plano_id);
      const meses = Number(b.meses);
      precoAssin(pl, meses);
      if (acao === 'assin_pix') {
        const qr = (o, g) => { const pg = (o.transactions && o.transactions.payments || [])[0] || {}, m = pg.payment_method || {}; return { id: g.id, valor: Number(g.valor), qr: m.qr_code || '', qr_img: m.qr_code_base64 || '', link: m.ticket_url || '' }; };
        const { data: ab } = ok(await admin.from('ff_assin_pagamentos').select('*').eq('assinante_id', a.id).eq('plano_id', pl.id).eq('meses', meses)
          .eq('metodo', 'pix').eq('status', 'pendente').gte('criado_em', new Date(Date.now() - 25 * 60000).toISOString()).order('criado_em', { ascending: false }).limit(1).maybeSingle(), 'pix aberto');
        if (ab && ORD.test(ab.mp_ordem || '')) {
          try {
            const ant = await mp(l.id, 'GET', '/v1/orders/' + ab.mp_ordem);
            const g2 = await gravarAssin(l.id, ant);
            if (g2 && g2.status === 'aprovado') return { status: 200, corpo: { id: ab.id, pago: true, valido_ate: g2.valido_ate } };
            if (situacaoOrdem(ant) === 'pendente' && centavos(ant.total_amount) === centavos(precoAssin(pl, meses)) && qr(ant, ab).qr) return { status: 200, corpo: qr(ant, ab) };
          } catch (_) { /* cria outro */ }
        }
        const g = await novoPagAssin(a, l, pl, meses, 'pix');
        const o = await mp(l.id, 'POST', '/v1/orders', {
          type: 'online', processing_mode: 'automatic', total_amount: valor(g.valor), external_reference: 'assin-' + g.id, description: descAssin(pl, l, meses),
          transactions: { payments: [{ amount: valor(g.valor), payment_method: { id: 'pix', type: 'bank_transfer' }, expiration_time: 'PT30M' }] },
          payer: { email: compradorTeste(a.email), first_name: TESTE ? 'APRO' : (String(a.nome).split(' ')[0].replace(/[^A-Za-zÀ-ÿ ]/g, '').slice(0, 40) || 'Cliente') }
        }, { 'X-Idempotency-Key': 'assin-pix-' + g.id });
        ok(await admin.from('ff_assin_pagamentos').update({ mp_ordem: String(o.id || '') }).eq('id', g.id), 'pix');
        return { status: 200, corpo: qr(o, g) };
      }
      const d = b.dados || {};
      if (!/^[A-Za-z0-9]{20,64}$/.test(String(d.token || ''))) throw new Falha('cartao_invalido');
      const g = await novoPagAssin(a, l, pl, meses, 'cartao');
      const ident = d.payer && d.payer.identification;
      const o = await mp(l.id, 'POST', '/v1/orders', {
        type: 'online', processing_mode: 'automatic', total_amount: valor(g.valor), external_reference: 'assin-' + g.id, description: descAssin(pl, l, meses),
        transactions: { payments: [{ amount: valor(g.valor), payment_method: {
          id: String(d.payment_method_id || '').slice(0, 40), type: 'credit_card', token: d.token,
          installments: Math.max(1, Math.min(12, parseInt(d.installments, 10) || 1)),
          statement_descriptor: l.nome.replace(/[^A-Za-z0-9 ]/g, '').slice(0, 13) || 'GOPEDIDO' } }] },
        payer: { email: compradorTeste(String((d.payer && d.payer.email) || a.email).toLowerCase()), ...(ident && ident.number ? { identification: { type: String(ident.type || 'CPF').slice(0, 10), number: String(ident.number).replace(/\D/g, '').slice(0, 14) } } : {}) }
      }, { 'X-Idempotency-Key': 'assin-cartao-' + g.id });
      ok(await admin.from('ff_assin_pagamentos').update({ mp_ordem: String(o.id || '') }).eq('id', g.id), 'cartão');
      const g2 = await gravarAssin(l.id, o) || g;
      const pg = (o.transactions && o.transactions.payments || [])[0] || {};
      return { status: 200, corpo: { id: g.id, status: g2.status, valido_ate: g2.valido_ate, detalhe: pg.status_detail || o.status_detail || o._detalhe || '' } };
    }

    if (acao === 'assin_conferir') {
      if (!UUID.test(String(b.id || ''))) throw new Falha('pagamento_invalido');
      const { data: g } = ok(await admin.from('ff_assin_pagamentos').select('*').eq('id', b.id).maybeSingle(), 'pagamento');
      if (!g) throw new Falha('pagamento_invalido', 404);
      if (g.status !== 'pendente' || !ORD.test(g.mp_ordem || '')) return { status: 200, corpo: { status: g.status, valido_ate: g.valido_ate } };
      const g2 = await gravarAssin(g.loja_id, await mp(g.loja_id, 'GET', '/v1/orders/' + g.mp_ordem)) || g;
      return { status: 200, corpo: { status: g2.status, valido_ate: g2.valido_ate } };
    }

    // ===== Planos do GoPedido =====
    if (acao === 'plano_info') {
      await exigeDonoConta();
      const tabela = {};
      for (const pl of ['profissional', 'premium']) {
        tabela[pl] = {};
        for (const m of [1, 2, 3]) {
          try { tabela[pl][m] = await calcPlano(pl, m); } catch (e) { tabela[pl][m] = { erro: e.message, valido_ate: e.detalhe || null }; }
        }
      }
      let extra = null;
      try { extra = await calcPlano('extra', 1, 10); extra = { preco: Number(extra.preco), premium_ate: extra.premium_ate }; } catch (e) { extra = { erro: e.message }; }
      tabela.extra = extra;
      let extraA = null;
      try { extraA = await calcPlano('extra_assin', 1, 5); extraA = { preco: Number(extraA.preco), premium_ate: extraA.premium_ate }; } catch (e) { extraA = { erro: e.message }; }
      tabela.extra_assin = extraA;
      const { data: hist } = ok(await admin.from('ff_plano_pagamentos').select('id, plano, meses, qtd, valor, status, metodo, criado_em, pago_em, valido_ate')
        .eq('user_id', usuario.id).order('criado_em', { ascending: false }).limit(10), 'histórico');
      return { status: 200, corpo: { ativo: !!env.MP_PLANO_TOKEN, public_key: env.MP_PLANO_PUBLIC_KEY || '', email: usuario.email, tabela, historico: hist || [] } };
    }

    if (acao === 'plano_pix') {
      await exigeDonoConta();
      const plano = String(b.plano || ''), meses = Number(b.meses), qtd = Math.floor(Number(b.qtd) || 0);
      const qr = (o, g) => {
        const pg = (o.transactions && o.transactions.payments || [])[0] || {}, m = pg.payment_method || {};
        return { id: g.id, valor: Number(g.valor), qr: m.qr_code || '', qr_img: m.qr_code_base64 || '', link: m.ticket_url || '' };
      };
      // Pix em aberto do mesmo plano e tempo (últimos 30 min): mostra o mesmo QR Code
      const { data: ab } = ok(await admin.from('ff_plano_pagamentos').select('*').eq('user_id', usuario.id).eq('plano', plano).eq('meses', meses)
        .eq('metodo', 'pix').eq('status', 'pendente').eq('qtd', plano === 'extra' || plano === 'extra_assin' ? qtd : 0).gte('criado_em', new Date(Date.now() - 30 * 60000).toISOString()).order('criado_em', { ascending: false }).limit(1).maybeSingle(), 'pix aberto');
      if (ab && ORD.test(ab.mp_id || '')) {
        try {
          const ant = await mpPlano('GET', '/v1/orders/' + ab.mp_id);
          const g2 = await gravarPlano(ant);
          if (g2 && g2.status === 'aprovado') return { status: 200, corpo: { id: ab.id, pago: true } };
          const c = await calcPlano(plano, meses, qtd);
          if (situacaoOrdem(ant) === 'pendente' && centavos(ant.total_amount) === centavos(c.valor) && qr(ant, ab).qr) return { status: 200, corpo: qr(ant, ab) };
        } catch (_) { /* cria outro */ }
      }
      const { g } = await novoPagamentoPlano(plano, meses, 'pix', qtd);
      const o = await mpPlano('POST', '/v1/orders', {
        type: 'online', processing_mode: 'automatic', total_amount: valor(g.valor), external_reference: 'plano-' + g.id, description: descPlano(g),
        transactions: { payments: [{ amount: valor(g.valor), payment_method: { id: 'pix', type: 'bank_transfer' }, expiration_time: 'PT30M' }] },
        payer: { email: compradorTeste(g.email), ...(TESTE ? { first_name: 'APRO' } : {}) }
      }, { 'X-Idempotency-Key': 'plano-pix-' + g.id });
      ok(await admin.from('ff_plano_pagamentos').update({ mp_id: String(o.id || '') }).eq('id', g.id), 'pix');
      return { status: 200, corpo: qr(o, g) };
    }

    if (acao === 'plano_cartao') {
      await exigeDonoConta();
      const d = b.dados || {};
      if (!/^[A-Za-z0-9]{20,64}$/.test(String(d.token || ''))) throw new Falha('cartao_invalido');
      const { g } = await novoPagamentoPlano(String(b.plano || ''), Number(b.meses), 'cartao', Math.floor(Number(b.qtd) || 0));
      const ident = d.payer && d.payer.identification;
      const o = await mpPlano('POST', '/v1/orders', {
        type: 'online', processing_mode: 'automatic', total_amount: valor(g.valor), external_reference: 'plano-' + g.id, description: descPlano(g),
        transactions: { payments: [{ amount: valor(g.valor), payment_method: {
          id: String(d.payment_method_id || '').slice(0, 40), type: 'credit_card', token: d.token,
          installments: Math.max(1, Math.min(12, parseInt(d.installments, 10) || 1)), statement_descriptor: 'GOPEDIDO' } }] },
        payer: { email: compradorTeste(String((d.payer && d.payer.email) || g.email).toLowerCase()), ...(ident && ident.number ? { identification: { type: String(ident.type || 'CPF').slice(0, 10), number: String(ident.number).replace(/\D/g, '').slice(0, 14) } } : {}) }
      }, { 'X-Idempotency-Key': 'plano-cartao-' + g.id });
      ok(await admin.from('ff_plano_pagamentos').update({ mp_id: String(o.id || '') }).eq('id', g.id), 'cartão');
      const g2 = await gravarPlano(o) || g;
      const pg = (o.transactions && o.transactions.payments || [])[0] || {};
      return { status: 200, corpo: { id: g.id, status: g2.status, valido_ate: g2.valido_ate, detalhe: pg.status_detail || o.status_detail || o._detalhe || '' } };
    }

    if (acao === 'plano_conferir') {
      precisaLogin();
      if (!UUID.test(String(b.id || ''))) throw new Falha('pagamento_invalido');
      const { data: g } = ok(await admin.from('ff_plano_pagamentos').select('*').eq('id', b.id).eq('user_id', usuario.id).maybeSingle(), 'pagamento');
      if (!g) throw new Falha('pagamento_invalido', 404);
      if (g.status === 'aprovado' || !ORD.test(g.mp_id || '')) return { status: 200, corpo: { status: g.status, valido_ate: g.valido_ate } };
      const g2 = await gravarPlano(await mpPlano('GET', '/v1/orders/' + g.mp_id)) || g;
      return { status: 200, corpo: { status: g2.status, valido_ate: g2.valido_ate } };
    }

    if (acao === 'estornar') {
      const p = await pedidoPor();
      const l = await pegaLoja(p.loja_id); await exigeEquipe(l);
      if (p.mp_status !== 'aprovado' || !p.mp_pagamento_id) throw new Falha('nada_a_estornar');
      if (/^\d+$/.test(p.mp_pagamento_id)) await mp(l.id, 'POST', '/v1/payments/' + encodeURIComponent(p.mp_pagamento_id) + '/refunds', {}, { 'X-Idempotency-Key': 'estorno-' + p.id });
      else await mp(l.id, 'POST', '/v1/orders/' + encodeURIComponent(p.mp_pagamento_id) + '/refund', undefined, { 'X-Idempotency-Key': 'estorno-' + p.id });
      ok(await admin.from('ff_pedidos').update({ mp_status: 'estornado' }).eq('id', p.id), 'estorno');
      return { status: 200, corpo: { ok: true } };
    }

    throw new Falha('acao_invalida');
  }
}

function chave(novo, antigo) {
  try {
    const j = JSON.parse(Deno.env.get(novo) || '');
    const v = j && (j.default || Object.values(j)[0]);
    if (v) return v;
  } catch (_) { /* não é JSON */ }
  return Deno.env.get(antigo) || '';
}

if (typeof Deno !== 'undefined') {
  Deno.serve(async (req) => {
    const resp = (status, corpo) => new Response(typeof corpo === 'string' ? corpo : JSON.stringify(corpo), {
      status, headers: { ...CORS, 'Content-Type': typeof corpo === 'string' ? 'text/plain' : 'application/json' }
    });
    try {
      const SECRETA = chave('SUPABASE_SECRET_KEYS', 'SUPABASE_SERVICE_ROLE_KEY');
      if (!SECRETA) return resp(500, { error: 'erro_banco', detalhe: 'a Edge Function não encontrou a chave secreta do projeto' });
      const BASE = Deno.env.get('SUPABASE_URL');
      const admin = createClient(BASE, SECRETA, { auth: { persistSession: false, autoRefreshToken: false } });
      const env = {
        MP_CLIENT_ID: Deno.env.get('MP_CLIENT_ID'), MP_CLIENT_SECRET: Deno.env.get('MP_CLIENT_SECRET'),
        MP_REDIRECT: Deno.env.get('MP_REDIRECT'), MP_TESTE: Deno.env.get('MP_TESTE'),
        MP_PLANO_TOKEN: Deno.env.get('MP_PLANO_TOKEN'), MP_PLANO_PUBLIC_KEY: Deno.env.get('MP_PLANO_PUBLIC_KEY')
      };
      const r = await tratar(req, admin, env, fetch, BASE + '/functions/v1/ff-mercadopago');
      return resp(r.status, r.corpo);
    } catch (e) {
      return resp(e instanceof Falha ? e.status : 500, { error: e instanceof Falha ? e.message : 'erro_interno', detalhe: e instanceof Falha ? e.detalhe : String(e && e.message || e) });
    }
  });
}
