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
// As variáveis SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY já existem na Edge Function.

import { createClient } from 'npm:@supabase/supabase-js@2';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS'
};

class Falha extends Error {
  constructor(codigo, status = 400) { super(codigo); this.status = status; }
}

const EMAIL_OK = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
const limpaNome = (s) => String(s || '').trim().slice(0, 60);
const limpaEmail = (s) => String(s || '').trim().toLowerCase().slice(0, 120);

export async function tratar(req, admin) {
  if (req.method === 'OPTIONS') return { status: 200, corpo: 'ok' };
  if (req.method !== 'POST') throw new Falha('metodo_invalido', 405);

  // Quem está chamando?
  const token = (req.headers.get('Authorization') || '').replace(/^Bearer\s+/i, '');
  if (!token) throw new Falha('nao_logado', 401);
  const { data: u, error: eu } = await admin.auth.getUser(token);
  const dono = u && u.user;
  if (eu || !dono) throw new Falha('nao_logado', 401);

  // Quem é da equipe não pode gerenciar a equipe
  const { data: souFunc } = await admin.from('ff_equipe').select('id').eq('user_id', dono.id).maybeSingle();
  if (souFunc) throw new Falha('so_dono', 403);

  const b = await req.json().catch(() => ({}));

  // As lojas escolhidas precisam ser do dono
  const lojasValidas = async (todas, lojas) => {
    if (todas) return [];
    const { data } = await admin.from('ff_lojas').select('id').eq('dono', dono.id);
    const minhas = (data || []).map(l => l.id);
    const ok = [...new Set((Array.isArray(lojas) ? lojas : []).filter(id => minhas.includes(id)))];
    if (!ok.length) throw new Falha('escolha_lojas');
    return ok;
  };
  const membro = async (id) => {
    const { data } = await admin.from('ff_equipe').select('*').eq('id', id).eq('dono', dono.id).maybeSingle();
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
    const { data: plano } = await admin.rpc('ff_plano_de', { p_user: dono.id });
    const { data: max } = await admin.rpc('ff_equipe_max', { p_plano: plano || 'gratis' });
    const { count } = await admin.from('ff_equipe').select('id', { count: 'exact', head: true }).eq('dono', dono.id);
    if ((count || 0) >= (max || 1)) throw new Falha('limite_equipe');

    const { data: cu, error: ec } = await admin.auth.admin.createUser({
      email, password: senha, email_confirm: true, user_metadata: { nome, equipe_de: dono.id }
    });
    if (ec || !cu || !cu.user) throw erroAuth(ec);

    const { data: row, error: ei } = await admin.from('ff_equipe')
      .insert({ dono: dono.id, user_id: cu.user.id, nome, email, todas, lojas }).select().single();
    if (ei) {
      await admin.auth.admin.deleteUser(cu.user.id);   // desfaz a conta se não entrou na equipe
      throw new Falha(/limite_equipe/.test(ei.message || '') ? 'limite_equipe' : 'erro_conta');
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
      if (error) throw new Falha('erro_conta');
      row = data;
    }
    return { status: 200, corpo: { ok: true, membro: row } };
  }

  if (b.acao === 'remover') {
    const m = await membro(b.id);
    await admin.from('ff_equipe').delete().eq('id', m.id);   // perde o acesso na hora
    await admin.auth.admin.deleteUser(m.user_id);           // e a conta deixa de existir
    return { status: 200, corpo: { ok: true } };
  }

  throw new Falha('acao_invalida');
}

if (typeof Deno !== 'undefined') {
  Deno.serve(async (req) => {
    const resp = (status, corpo) => new Response(typeof corpo === 'string' ? corpo : JSON.stringify(corpo), {
      status, headers: { ...CORS, 'Content-Type': typeof corpo === 'string' ? 'text/plain' : 'application/json' }
    });
    try {
      const admin = createClient(Deno.env.get('SUPABASE_URL'), Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'), {
        auth: { persistSession: false, autoRefreshToken: false }
      });
      const r = await tratar(req, admin);
      return resp(r.status, r.corpo);
    } catch (e) {
      return resp(e instanceof Falha ? e.status : 500, { error: e instanceof Falha ? e.message : 'erro_interno' });
    }
  });
}
