// @ts-nocheck
// GoPedido — Edge Function "ff-melhorenvio"
// Liga cada loja de Variedades à conta do Melhor Envio do próprio lojista:
// cotação de frete, saldo, etiqueta (compra + geração), impressão e rastreio.
// Precisa do SQL v20 rodado antes.
//
// Ações (POST, corpo JSON):
//   { acao: 'url',         loja }               → link para o lojista autorizar (só o dono)
//   { acao: 'conectar',    loja, code }         → guarda as chaves que o Melhor Envio devolveu (só o dono)
//   { acao: 'desconectar', loja }               → apaga as chaves (só o dono)
//   { acao: 'saldo',       loja }               → saldo da carteira (dono ou equipe)
//   { acao: 'cotar',       loja, cep, itens }   → opções de frete (público, usado no checkout)
//   { acao: 'etiqueta',    pedido }             → compra e gera a etiqueta com o saldo da conta (dono ou equipe)
//   { acao: 'imprimir',    pedido }             → link do PDF da etiqueta (dono ou equipe)
//   { acao: 'rastrear',    pedido | token }     → atualiza o código de rastreio (equipe, ou o cliente com o token)
//   { acao: 'cancelar',    pedido }             → cancela a etiqueta no Melhor Envio e o valor volta para o saldo (dono ou equipe)
//
// Como publicar: Supabase → Edge Functions → "Deploy a new function" → "Via Editor"
//   nome: ff-melhorenvio → cole este arquivo inteiro → Deploy → em Details desligue "Verify JWT".
// Segredos (Edge Functions → Secrets): ME_CLIENT_ID, ME_CLIENT_SECRET, ME_AMBIENTE (sandbox ou producao)
// Opcional: ME_REDIRECT (padrão https://goscripts.com.br/delivery/painel.html)

import { createClient } from 'npm:@supabase/supabase-js@2';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS'
};

class Falha extends Error {
  constructor(codigo, status = 400, detalhe = '') { super(codigo); this.status = status; this.detalhe = detalhe; }
}
const ok = (r, onde) => { if (r && r.error) throw new Falha('erro_banco', 500, onde + ': ' + (r.error.message || r.error)); return r; };

const ESCOPOS = 'cart-read cart-write orders-read shipping-calculate shipping-cancel shipping-checkout shipping-companies shipping-generate shipping-preview shipping-print shipping-tracking users-read transactions-read';
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const so = (s) => String(s || '').replace(/\D/g, '');
const num = (v, d) => { const n = Number(v); return Number.isFinite(n) && n > 0 ? n : d; };

// Igual ao GP.parseEnd do site: "Rua, 123 - Bairro, Cidade/UF - CEP 00000-000"
export function parseEnd(t) {
  const o = { rua: '', numero: '', bairro: '', cidade: '', uf: '', cep: '' };
  let s = String(t || '').trim();
  const mc = s.match(/\s*-\s*CEP\s*(\d{5}-?\d{3})\s*$/i);
  if (mc) { o.cep = so(mc[1]); s = s.slice(0, mc.index); }
  const i = s.indexOf(' - '), l1 = i >= 0 ? s.slice(0, i) : s, l2 = i >= 0 ? s.slice(i + 3) : '';
  const m1 = l1.match(/^(.*),\s*([^,]{1,12})$/);
  if (m1) { o.rua = m1[1].trim(); o.numero = m1[2].trim(); } else o.rua = l1.trim();
  if (l2) {
    const j = l2.lastIndexOf(','), resto = (j >= 0 ? l2.slice(j + 1) : l2).trim();
    o.bairro = j >= 0 ? l2.slice(0, j).trim() : '';
    const m3 = resto.match(/^(.*?)(?:\/([A-Za-z]{2}))?$/);
    o.cidade = (m3 ? m3[1] : resto).trim(); o.uf = m3 && m3[2] ? m3[2].toUpperCase() : '';
  }
  if (!o.cep) { const m = String(t || '').match(/(\d{5})-?(\d{3})/); if (m) o.cep = m[1] + m[2]; }
  return o;
}

// Mesma chave que o banco confere no pedido: "produto|variação|qtd" somados e ordenados
export function chaveItens(itens) {
  const soma = new Map();
  for (const it of itens) {
    const k = String(it.id) + '|' + String(it.v || '');
    soma.set(k, (soma.get(k) || 0) + it.qtd);
  }
  return [...soma.keys()].sort().map(k => k + '|' + soma.get(k)).join(',');
}

export async function tratar(req, admin, comoUsuario, env, http = fetch) {
  if (req.method === 'OPTIONS') return { status: 200, corpo: 'ok' };
  if (req.method !== 'POST') throw new Falha('metodo_invalido', 405);
  if (!env.ME_CLIENT_ID || !env.ME_CLIENT_SECRET) throw new Falha('me_nao_configurado', 500, 'faltam os segredos ME_CLIENT_ID / ME_CLIENT_SECRET');

  const BASE = String(env.ME_AMBIENTE || 'sandbox').toLowerCase().startsWith('prod')
    ? 'https://melhorenvio.com.br' : 'https://sandbox.melhorenvio.com.br';
  const REDIRECT = env.ME_REDIRECT || 'https://goscripts.com.br/delivery/painel.html';
  const UA = 'GoPedido (goscripts.com.br)';

  const b = await req.json().catch(() => ({}));
  const acao = String(b.acao || '');

  // ---------- quem está chamando ----------
  let usuario = null;
  const tok = (req.headers.get('Authorization') || '').replace(/^Bearer\s+/i, '');
  if (tok) {
    const { data } = await admin.auth.getUser(tok);
    usuario = data && data.user || null;
  }
  const precisaLogin = () => { if (!usuario) throw new Falha('nao_logado', 401); };

  const pegaLoja = async (id) => {
    if (!UUID.test(String(id || ''))) throw new Falha('loja_invalida');
    const { data } = ok(await admin.from('ff_lojas').select('*').eq('id', id).maybeSingle(), 'loja');
    if (!data) throw new Falha('loja_invalida', 404);
    return data;
  };
  const exigeDono = (l) => { precisaLogin(); if (String(l.dono) !== String(usuario.id)) throw new Falha('so_dono', 403); };
  const exigeEquipe = async (l) => {
    precisaLogin();
    if (String(l.dono) === String(usuario.id)) return;
    const { data } = ok(await admin.from('ff_equipe').select('todas, lojas').eq('user_id', usuario.id).eq('dono', l.dono).maybeSingle(), 'equipe');
    if (!data || !(data.todas || (data.lojas || []).map(String).includes(String(l.id)))) throw new Falha('sem_acesso', 403);
  };

  // ---------- conversa com o Melhor Envio ----------
  const pedirToken = async (corpo) => {
    const r = await http(BASE + '/oauth/token', {
      method: 'POST',
      headers: { 'Accept': 'application/json', 'Content-Type': 'application/json', 'User-Agent': UA },
      body: JSON.stringify({ client_id: env.ME_CLIENT_ID, client_secret: env.ME_CLIENT_SECRET, redirect_uri: REDIRECT, ...corpo })
    });
    const j = await r.json().catch(() => ({}));
    if (!r.ok || !j.access_token) throw new Falha('me_autorizacao', 400, j.error_description || j.message || j.error || ('HTTP ' + r.status));
    return j;
  };

  const salvarConta = async (lojaId, j, conta) => {
    const linha = {
      loja_id: lojaId, access_token: j.access_token, refresh_token: j.refresh_token || '',
      expira: new Date(Date.now() + (num(j.expires_in, 2592000) - 60) * 1000).toISOString(),
      atualizado_em: new Date().toISOString()
    };
    if (conta !== undefined) linha.conta = conta;
    ok(await admin.from('ff_me_contas').upsert(linha), 'salvar conta');
  };

  // Chave válida da loja (renova sozinha quando está perto de vencer)
  const chaveDaLoja = async (lojaId) => {
    const { data: c } = ok(await admin.from('ff_me_contas').select('*').eq('loja_id', lojaId).maybeSingle(), 'conta');
    if (!c) throw new Falha('me_desconectado');
    if (new Date(c.expira).getTime() - Date.now() > 10 * 60 * 1000) return c.access_token;
    if (!c.refresh_token) throw new Falha('me_desconectado');
    try {
      const j = await pedirToken({ grant_type: 'refresh_token', refresh_token: c.refresh_token });
      await salvarConta(lojaId, j);
      return j.access_token;
    } catch (e) {
      // Autorização perdida (o lojista revogou ou passou muito tempo): pede para conectar de novo
      ok(await admin.from('ff_lojas').update({ me_conectado: false }).eq('id', lojaId), 'desligar');
      throw new Falha('me_desconectado', 400, e.detalhe || '');
    }
  };

  const api = async (lojaId, metodo, caminho, corpo) => {
    const access = await chaveDaLoja(lojaId);
    const r = await http(BASE + caminho, {
      method: metodo,
      headers: { 'Accept': 'application/json', 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + access, 'User-Agent': UA },
      body: corpo === undefined ? undefined : JSON.stringify(corpo)
    });
    const texto = await r.text();
    let j; try { j = texto ? JSON.parse(texto) : {}; } catch (_) { j = { message: texto.slice(0, 200) }; }
    if (r.status === 401) {
      ok(await admin.from('ff_lojas').update({ me_conectado: false }).eq('id', lojaId), 'desligar');
      throw new Falha('me_desconectado');
    }
    if (!r.ok) {
      const det = j.message || j.error || (j.errors ? JSON.stringify(j.errors) : '') || ('HTTP ' + r.status);
      if (/saldo|balance|insufficient|insuficiente/i.test(det)) throw new Falha('me_saldo', 400, det);
      throw new Falha('me_erro', 400, det);
    }
    return j;
  };

  // ---------- pedido (para etiqueta, impressão e rastreio) ----------
  const pegaPedido = async () => {
    let q = admin.from('ff_pedidos').select('*');
    if (UUID.test(String(b.pedido || ''))) q = q.eq('id', b.pedido);
    else if (/^[a-z0-9]{8,40}$/i.test(String(b.token || ''))) q = q.eq('token', b.token);
    else throw new Falha('pedido_invalido');
    const { data: p } = ok(await q.maybeSingle(), 'pedido');
    if (!p) throw new Falha('pedido_invalido', 404);
    if (p.tipo_entrega !== 'envio') throw new Falha('nao_e_envio');
    return p;
  };

  // ================= ações =================
  if (acao === 'url') {
    const l = await pegaLoja(b.loja); exigeDono(l);
    if (l.tipo !== 'variedades') throw new Falha('envio_so_variedades');
    const u = new URL(BASE + '/oauth/authorize');
    u.searchParams.set('client_id', env.ME_CLIENT_ID);
    u.searchParams.set('redirect_uri', REDIRECT);
    u.searchParams.set('response_type', 'code');
    u.searchParams.set('state', 'me:' + l.id);
    u.searchParams.set('scope', ESCOPOS);
    return { status: 200, corpo: { url: u.toString() } };
  }

  if (acao === 'conectar') {
    const l = await pegaLoja(b.loja); exigeDono(l);
    const code = String(b.code || '');
    if (!code || code.length > 4000) throw new Falha('me_autorizacao', 400, 'código ausente');
    const j = await pedirToken({ grant_type: 'authorization_code', code });
    // Nome da conta conectada (só para mostrar no painel)
    let conta = '';
    try {
      const r = await http(BASE + '/api/v2/me', { headers: { 'Accept': 'application/json', 'Authorization': 'Bearer ' + j.access_token, 'User-Agent': UA } });
      const me = await r.json();
      conta = [me.firstname, me.lastname].filter(Boolean).join(' ') || me.email || '';
    } catch (_) {}
    await salvarConta(l.id, j, conta.slice(0, 80));
    ok(await admin.from('ff_lojas').update({ me_conectado: true, me_conta: conta.slice(0, 80) }).eq('id', l.id), 'loja');
    return { status: 200, corpo: { ok: true, conta } };
  }

  if (acao === 'desconectar') {
    const l = await pegaLoja(b.loja); exigeDono(l);
    ok(await admin.from('ff_me_contas').delete().eq('loja_id', l.id), 'apagar conta');
    ok(await admin.from('ff_lojas').update({ me_conectado: false, me_conta: '', envio_externo: false }).eq('id', l.id), 'loja');
    return { status: 200, corpo: { ok: true } };
  }

  if (acao === 'saldo') {
    const l = await pegaLoja(b.loja); await exigeEquipe(l);
    const j = await api(l.id, 'GET', '/api/v2/me/balance');
    return { status: 200, corpo: { saldo: Number(j.balance || 0), reservado: Number(j.reserved || 0), conta: l.me_conta || '' } };
  }

  if (acao === 'cotar') {
    const l = await pegaLoja(b.loja);
    if (!l.ativa || l.tipo !== 'variedades' || !l.envio_externo || !l.me_conectado) throw new Falha('envio_indisponivel');
    const cep = so(b.cep);
    if (cep.length !== 8) throw new Falha('cep_invalido');
    const origem = parseEnd(l.endereco).cep;
    if (origem.length !== 8) throw new Falha('loja_sem_cep');

    // Itens: confere no banco preço, peso e medidas (o navegador só manda id, variação e quantidade)
    const itens = (Array.isArray(b.itens) ? b.itens : []).slice(0, 60)
      .map(it => ({ id: String(it && it.id || ''), v: it && it.v ? String(it.v) : '', qtd: Math.floor(Number(it && it.qtd)) }))
      .filter(it => UUID.test(it.id) && it.qtd > 0 && it.qtd <= 99);
    if (!itens.length) throw new Falha('carrinho_vazio');
    const ids = [...new Set(itens.map(i => i.id))];
    const { data: prods } = ok(await admin.from('ff_produtos').select('id, nome, preco, variacoes, peso_kg, altura_cm, largura_cm, comprimento_cm').eq('loja_id', l.id).in('id', ids), 'produtos');
    const porId = new Map((prods || []).map(p => [String(p.id), p]));
    const produtos = itens.map(it => {
      const p = porId.get(it.id);
      if (!p) throw new Falha('produto_indisponivel');
      const v = it.v ? (p.variacoes || []).find(x => String(x.id) === it.v) : null;
      if (it.v && !v) throw new Falha('escolha_variacao');
      const preco = v && v.preco != null && v.preco !== '' ? Number(v.preco) : Number(p.preco);
      return {
        id: it.id + (it.v ? '-' + it.v : ''),
        width: Math.max(num(p.largura_cm, 11), 11), height: Math.max(num(p.altura_cm, 4), 2), length: Math.max(num(p.comprimento_cm, 16), 16),
        weight: num(p.peso_kg, 0.3), insurance_value: Math.max(0, preco || 0), quantity: it.qtd
      };
    });

    const lista = await api(l.id, 'POST', '/api/v2/me/shipment/calculate', {
      from: { postal_code: origem }, to: { postal_code: cep }, products: produtos,
      options: { receipt: false, own_hand: false }
    });
    const chave = chaveItens(itens);
    const validas = (Array.isArray(lista) ? lista : []).filter(s => s && !s.error && Number(s.custom_price || s.price) > 0);
    if (!validas.length) return { status: 200, corpo: { opcoes: [] } };

    // Limpa cotações antigas desta loja e guarda as novas (o pedido só aceita o preço guardado aqui)
    await admin.from('ff_cotacoes').delete().eq('loja_id', l.id).lt('expira', new Date().toISOString());
    const linhas = validas.map(s => ({
      loja_id: l.id, cep_destino: cep, servico_id: Number(s.id),
      servico_nome: ((s.company && s.company.name ? s.company.name + ' ' : '') + (s.name || '')).trim().slice(0, 80),
      preco: Math.round(Number(s.custom_price || s.price) * 100) / 100,
      prazo: Number(s.custom_delivery_time || s.delivery_time) || null,
      itens_chave: chave,
      // Caixas que o Melhor Envio montou para essa cotação: a etiqueta usa exatamente as mesmas
      pacotes: (Array.isArray(s.packages) ? s.packages : []).map(pk => ({
        height: Number(pk.dimensions && pk.dimensions.height) || 2, width: Number(pk.dimensions && pk.dimensions.width) || 11,
        length: Number(pk.dimensions && pk.dimensions.length) || 16, weight: Number(pk.weight) || 0.3
      }))
    }));
    const { data: salvas } = ok(await admin.from('ff_cotacoes').insert(linhas).select('id, servico_id, servico_nome, preco, prazo'), 'cotacoes');
    const logo = new Map(validas.map(s => [Number(s.id), s.company && s.company.picture || '']));
    const opcoes = (salvas || []).map(c => ({ cotacao: c.id, nome: c.servico_nome, preco: Number(c.preco), prazo: c.prazo, logo: logo.get(Number(c.servico_id)) || '' }))
      .sort((a, b2) => a.preco - b2.preco);
    return { status: 200, corpo: { opcoes } };
  }

  if (acao === 'etiqueta') {
    const p = await pegaPedido();
    const l = await pegaLoja(p.loja_id); await exigeEquipe(l);
    if (p.status === 'cancelado') throw new Falha('pedido_cancelado');
    if (p.etiqueta_status === 'gerada') return { status: 200, corpo: { ok: true, status: 'gerada', rastreio: p.rastreio } };

    let meId = p.me_pedido_id;
    if (!meId) {
      // Remetente: dados da conta do lojista no Melhor Envio + endereço da loja
      const me = await api(l.id, 'GET', '/api/v2/me');
      const de = parseEnd(l.endereco);
      const docLoja = so(l.cnpj);
      const para = p.endereco_partes || {};
      const { data: itens } = ok(await admin.from('ff_pedido_itens').select('nome, preco, qtd, produto_id, variacao_id').eq('pedido_id', p.id), 'itens');
      const ids = [...new Set((itens || []).map(i => i.produto_id).filter(Boolean))];
      const { data: prods } = ids.length ? ok(await admin.from('ff_produtos').select('id, peso_kg, altura_cm, largura_cm, comprimento_cm').in('id', ids), 'medidas') : { data: [] };
      const med = new Map((prods || []).map(x => [String(x.id), x]));
      // Um volume só: soma o peso, empilha a altura, usa a maior largura/comprimento
      let peso = 0, alt = 0, larg = 11, comp = 16;
      for (const i of itens || []) {
        const m = med.get(String(i.produto_id)) || {};
        peso += num(m.peso_kg, 0.3) * i.qtd;
        alt += num(m.altura_cm, 4) * i.qtd;
        larg = Math.max(larg, num(m.largura_cm, 11));
        alt = Math.max(alt, 2);
        comp = Math.max(comp, num(m.comprimento_cm, 16));
      }
      const doc = so(p.cliente_doc);
      const corpo = {
        service: p.frete_servico,
        from: {
          name: (l.nome || '').slice(0, 60), phone: so(l.telefone) || so(me.phone && me.phone.phone),
          email: me.email || '',
          ...(docLoja.length === 14 ? { company_document: docLoja, document: so(me.document) } : { document: so(me.document) }),
          address: de.rua, number: de.numero || 'S/N', district: de.bairro, city: de.cidade,
          state_abbr: de.uf, postal_code: de.cep, country_id: 'BR'
        },
        to: {
          name: (p.cliente_nome || '').slice(0, 60), phone: so(p.cliente_telefone), email: '',
          ...(doc.length === 14 ? { company_document: doc } : { document: doc }),
          address: para.rua || p.endereco, complement: para.complemento || p.complemento || '',
          number: para.numero || 'S/N', district: para.bairro || '', city: para.cidade || '',
          state_abbr: (para.uf || '').toUpperCase(), postal_code: so(para.cep || p.cep_destino), country_id: 'BR'
        },
        products: (itens || []).map(i => ({ name: String(i.nome).slice(0, 80), quantity: i.qtd, unitary_value: Number(i.preco) })),
        // Mesmas caixas da cotação que o cliente pagou; sem elas, monta uma caixa com a soma dos produtos
        volumes: (Array.isArray(p.frete_pacotes) && p.frete_pacotes.length) ? p.frete_pacotes
          : [{ height: Math.min(Math.ceil(alt), 100), width: Math.ceil(larg), length: Math.ceil(comp), weight: Math.round(peso * 1000) / 1000 }],
        options: { insurance_value: Number(p.subtotal), receipt: false, own_hand: false, reverse: false, non_commercial: true, platform: 'GoPedido', tags: [{ tag: 'Pedido #' + p.numero }] }
      };
      const r = await api(l.id, 'POST', '/api/v2/me/cart', corpo);
      meId = String(r.id || '');
      if (!meId) throw new Falha('me_erro', 400, 'o Melhor Envio não devolveu o número da etiqueta');
      ok(await admin.from('ff_pedidos').update({ me_pedido_id: meId, etiqueta_status: 'carrinho' }).eq('id', p.id), 'salvar etiqueta');
    }

    if (p.etiqueta_status !== 'paga') {
      await api(l.id, 'POST', '/api/v2/me/shipment/checkout', { orders: [meId] }); // paga com o saldo (erro me_saldo se faltar)
      ok(await admin.from('ff_pedidos').update({ etiqueta_status: 'paga' }).eq('id', p.id), 'paga');
    }
    await api(l.id, 'POST', '/api/v2/me/shipment/generate', { orders: [meId] });
    let rastreio = '';
    try {
      const o = await api(l.id, 'GET', '/api/v2/me/orders/' + encodeURIComponent(meId));
      rastreio = o.tracking || o.self_tracking || '';
    } catch (_) {}
    ok(await admin.from('ff_pedidos').update({ etiqueta_status: 'gerada', rastreio: String(rastreio).slice(0, 60) }).eq('id', p.id), 'gerada');
    return { status: 200, corpo: { ok: true, status: 'gerada', rastreio } };
  }

  if (acao === 'imprimir') {
    const p = await pegaPedido();
    const l = await pegaLoja(p.loja_id); await exigeEquipe(l);
    if (!p.me_pedido_id || p.etiqueta_status !== 'gerada') throw new Falha('etiqueta_nao_gerada');
    const j = await api(l.id, 'POST', '/api/v2/me/shipment/print', { mode: 'private', orders: [p.me_pedido_id] });
    if (!j.url) throw new Falha('me_erro', 400, 'sem link de impressão');
    return { status: 200, corpo: { url: j.url } };
  }

  if (acao === 'rastrear') {
    const p = await pegaPedido();
    const l = await pegaLoja(p.loja_id);
    if (!b.token) await exigeEquipe(l); // o cliente usa o token secreto do pedido
    if (!p.me_pedido_id) return { status: 200, corpo: { rastreio: p.rastreio || '', situacao: p.etiqueta_status || '' } };
    let rastreio = p.rastreio || '', situacao = '';
    try {
      const j = await api(l.id, 'POST', '/api/v2/me/shipment/tracking', { orders: [p.me_pedido_id] });
      const t = j && j[p.me_pedido_id] || {};
      rastreio = t.tracking || t.melhorenvio_tracking || rastreio; situacao = t.status || '';
    } catch (e) { if (!b.token) throw e; }
    if (rastreio && rastreio !== p.rastreio) ok(await admin.from('ff_pedidos').update({ rastreio: String(rastreio).slice(0, 60) }).eq('id', p.id), 'rastreio');
    return { status: 200, corpo: { rastreio, situacao } };
  }

  if (acao === 'cancelar') {
    const p = await pegaPedido();
    const l = await pegaLoja(p.loja_id); await exigeEquipe(l);
    if (!p.me_pedido_id || p.etiqueta_status === 'cancelada') return { status: 200, corpo: { ok: true, cancelada: false } };
    if (p.etiqueta_status === 'carrinho') {
      // Ainda não foi paga: só tira do carrinho
      await api(l.id, 'DELETE', '/api/v2/me/cart/' + encodeURIComponent(p.me_pedido_id)).catch(() => {});
    } else {
      const c = await api(l.id, 'POST', '/api/v2/me/shipment/cancellable', { orders: [p.me_pedido_id] });
      const info = c && c[p.me_pedido_id];
      if (info && info.cancellable === false) throw new Falha('etiqueta_nao_cancela', 400, 'a etiqueta já foi postada ou não pode mais ser cancelada');
      await api(l.id, 'POST', '/api/v2/me/shipment/cancel', { order: { id: p.me_pedido_id, reason_id: '2', description: 'Pedido cancelado pela loja (GoPedido #' + p.numero + ')' } });
    }
    ok(await admin.from('ff_pedidos').update({ etiqueta_status: 'cancelada' }).eq('id', p.id), 'cancelada');
    return { status: 200, corpo: { ok: true, cancelada: true } };
  }

  throw new Falha('acao_invalida');
}

// Lê a chave nova (JSON com 'default') ou a antiga
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
      const admin = createClient(Deno.env.get('SUPABASE_URL'), SECRETA, { auth: { persistSession: false, autoRefreshToken: false } });
      const env = {
        ME_CLIENT_ID: Deno.env.get('ME_CLIENT_ID'), ME_CLIENT_SECRET: Deno.env.get('ME_CLIENT_SECRET'),
        ME_AMBIENTE: Deno.env.get('ME_AMBIENTE'), ME_REDIRECT: Deno.env.get('ME_REDIRECT')
      };
      const r = await tratar(req, admin, null, env);
      return resp(r.status, r.corpo);
    } catch (e) {
      return resp(e instanceof Falha ? e.status : 500, { error: e instanceof Falha ? e.message : 'erro_interno', detalhe: e instanceof Falha ? e.detalhe : String(e && e.message || e) });
    }
  });
}
