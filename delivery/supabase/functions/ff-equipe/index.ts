// @ts-nocheck
// GoPedido — Edge Function "ff-equipe"
// Cria, altera e remove as contas de administradores da loja (equipe).
// Só o DONO da conta pode usar. Precisa do SQL v18 rodado antes.
//
// Ações (POST, corpo JSON):
//   { acao: 'criar',   nome, email, senha, todas, lojas }
//   { acao: 'editar',  id, nome?, email?, senha?, todas?, lojas? }
//   { acao: 'remover', id }
//
// Como publicar: Supabase → Edge Functions → "Deploy a new function" → "Via Editor"
//   nome: ff-equipe  → cole este arquivo inteiro → Deploy.
// As chaves já existem na Edge Function: usa as novas (SUPABASE_SECRET_KEYS / SUPABASE_PUBLISHABLE_KEYS)
// e, se o projeto ainda for das chaves antigas, SUPABASE_SERVICE_ROLE_KEY / SUPABASE_ANON_KEY.

import { createClient } from 'npm:@supabase/supabase-js@2';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS'
};

class Falha extends Error {
  constructor(codigo, status = 400, detalhe = '') { super(codigo); this.status = status; this.detalhe = detalhe; }
}
// Qualquer erro de banco vira uma falha com o motivo real (aparece no painel)
const ok = (r, onde) => { if (r && r.error) throw new Falha('erro_banco', 500, onde + ': ' + (r.error.message || r.error)); return r; };

const EMAIL_OK = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
const limpaNome = (s) => String(s || '').trim().slice(0, 60);
const limpaEmail = (s) => String(s || '').trim().toLowerCase().slice(0, 120);

export async function tratar(req, admin, comoUsuario) {
  if (req.method === 'OPTIONS') return { status: 200, corpo: 'ok' };
  if (req.method !== 'POST') throw new Falha('metodo_invalido', 405);

  // Quem está chamando?
  const token = (req.headers.get('Authorization') || '').replace(/^Bearer\s+/i, '');
  if (!token) throw new Falha('nao_logado', 401);
  const { data: u, error: eu } = await admin.auth.getUser(token);
  const dono = u && u.user;
  if (eu || !dono) throw new Falha('nao_logado', 401);

  // Quem é da equipe não pode gerenciar a equipe
  const { data: souFunc } = ok(await admin.from('ff_equipe').select('id').eq('user_id', dono.id).maybeSingle(), 'equipe');
  if (souFunc) throw new Falha('so_dono', 403);

  const b = await req.json().catch(() => ({}));

  // As lojas escolhidas precisam ser do dono
  const lojasValidas = async (todas, lojas) => {
    if (todas) return [];
    const { data } = ok(await admin.from('ff_lojas').select('id').eq('dono', dono.id), 'lojas');
    let minhas = (data || []).map(l => String(l.id));
    // Confere também com o login de quem chamou (as mesmas lojas que aparecem no painel dele)
    if (comoUsuario) {
      const r = await comoUsuario.rpc('ff_minhas_lojas');
      if (!r.error && Array.isArray(r.data)) minhas = [...new Set(minhas.concat(r.data.filter(l => String(l.dono) === String(dono.id)).map(l => String(l.id))))];
    }
    lojas = (Array.isArray(lojas) ? lojas : []).map(String);
    const validas = [...new Set(lojas.filter(id => minhas.includes(id)))];
    if (!validas.length) throw new Falha('escolha_lojas', 400, `enviadas: ${lojas.length}, suas lojas encontradas: ${minhas.length}`);
    return validas;
  };
  const membro = async (id) => {
    const { data } = ok(await admin.from('ff_equipe').select('*').eq('id', id).eq('dono', dono.id).maybeSingle(), 'membro');
    if (!data) throw new Falha('membro_invalido', 404);
    return data;
  };
  const erroAuth = (e) => {
    const m = String((e && e.message) || '');
    if (/already|registered|exists|duplicate/i.test(m)) return new Falha('email_existe');
    if (/password/i.test(m)) return new Falha('senha_fraca');
    if (/email/i.test(m)) return new Falha('email_invalido');
    return new Falha('erro_conta');
  };

  if (b.acao === 'criar') {
    const nome = limpaNome(b.nome), email = limpaEmail(b.email), senha = String(b.senha || '');
    if (nome.length < 2) throw new Falha('nome_invalido');
    if (!EMAIL_OK.test(email)) throw new Falha('email_invalido');
    if (senha.length < 6) throw new Falha('senha_curta');
    if (email === String(dono.email || '').toLowerCase()) throw new Falha('email_existe');
    const todas = b.todas !== false;
    const lojas = await lojasValidas(todas, b.lojas);

    // Limite do plano (o banco também confere)
    const { data: plano } = ok(await admin.rpc('ff_plano_de', { p_user: dono.id }), 'plano');
    const { data: max } = ok(await admin.rpc('ff_equipe_max', { p_plano: plano || 'gratis' }), 'limite');
    const { count } = ok(await admin.from('ff_equipe').select('id', { count: 'exact', head: true }).eq('dono', dono.id), 'contagem');
    if ((count || 0) >= (max || 1)) throw new Falha('limite_equipe');

    const { data: cu, error: ec } = await admin.auth.admin.createUser({
      email, password: senha, email_confirm: true, user_metadata: { nome, equipe_de: dono.id }
    });
    if (ec || !cu || !cu.user) throw erroAuth(ec);

    const { data: row, error: ei } = await admin.from('ff_equipe')
      .insert({ dono: dono.id, user_id: cu.user.id, nome, email, todas, lojas }).select().single();
    if (ei) {
      await admin.auth.admin.deleteUser(cu.user.id);   // desfaz a conta se não entrou na equipe
      if (/limite_equipe/.test(ei.message || '')) throw new Falha('limite_equipe');
      throw new Falha('erro_banco', 500, 'salvar equipe: ' + ei.message);
    }
    return { status: 200, corpo: { ok: true, membro: row } };
  }

  if (b.acao === 'editar') {
    const m = await membro(b.id);
    const mud = {}, conta = {};
    if (b.nome !== undefined) { const n = limpaNome(b.nome); if (n.length < 2) throw new Falha('nome_invalido'); mud.nome = n; }
    if (b.email !== undefined && limpaEmail(b.email) !== m.email) {
      const e = limpaEmail(b.email); if (!EMAIL_OK.test(e)) throw new Falha('email_invalido');
      conta.email = e; conta.email_confirm = true; mud.email = e;
    }
    if (b.senha) { if (String(b.senha).length < 6) throw new Falha('senha_curta'); conta.password = String(b.senha); }
    if (b.todas !== undefined || b.lojas !== undefined) {
      const todas = b.todas !== undefined ? b.todas !== false : m.todas;
      mud.todas = todas; mud.lojas = await lojasValidas(todas, b.lojas !== undefined ? b.lojas : m.lojas);
    }
    if (Object.keys(conta).length) {
      const { error } = await admin.auth.admin.updateUserById(m.user_id, conta);
      if (error) throw erroAuth(error);
    }
    let row = m;
    if (Object.keys(mud).length) {
      const { data, error } = await admin.from('ff_equipe').update(mud).eq('id', m.id).select().single();
      if (error) throw new Falha('erro_banco', 500, 'editar equipe: ' + error.message);
      row = data;
    }
    return { status: 200, corpo: { ok: true, membro: row } };
  }

  if (b.acao === 'remover') {
    const m = await membro(b.id);
    ok(await admin.from('ff_equipe').delete().eq('id', m.id), 'remover');   // perde o acesso na hora
    await admin.auth.admin.deleteUser(m.user_id);           // e a conta deixa de existir
    return { status: 200, corpo: { ok: true } };
  }

  throw new Falha('acao_invalida');
}

// Lê uma chave do dicionário novo do Supabase ({"default": "sb_..."}), ou da variável antiga
function chave(novo, antigo) {
  try {
    const d = JSON.parse(Deno.env.get(novo) || '{}');
    const v = d.default || Object.values(d)[0];
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
      const PUBLICA = chave('SUPABASE_PUBLISHABLE_KEYS', 'SUPABASE_ANON_KEY');
      if (!SECRETA) return resp(500, { error: 'erro_banco', detalhe: 'a Edge Function não encontrou a chave secreta do projeto' });
      const admin = createClient(Deno.env.get('SUPABASE_URL'), SECRETA, {
        auth: { persistSession: false, autoRefreshToken: false }
      });
      // Cliente com o login de quem chamou (respeita as regras de segurança do banco)
      const comoUsuario = createClient(Deno.env.get('SUPABASE_URL'), PUBLICA || SECRETA, {
        auth: { persistSession: false, autoRefreshToken: false },
        global: { headers: { Authorization: req.headers.get('Authorization') || '' } }
      });
      const r = await tratar(req, admin, comoUsuario);
      return resp(r.status, r.corpo);
    } catch (e) {
      return resp(e instanceof Falha ? e.status : 500, { error: e instanceof Falha ? e.message : 'erro_interno', detalhe: e instanceof Falha ? e.detalhe : String(e && e.message || e) });
    }
  });
}
