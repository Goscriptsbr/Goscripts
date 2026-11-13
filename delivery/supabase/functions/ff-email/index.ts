// @ts-nocheck
// GoPedido — Edge Function "ff-email"
// Manda e-mails para o cliente sobre o pedido, pelo Gmail (mesma conta e senha de app usadas no Supabase).
// Cada e-mail sai UMA vez só por pedido, e só quando a situação do pedido confere com o tipo pedido.
// Precisa do SQL v22 rodado antes.
//
// Ação (POST, corpo JSON): { token, tipo }   tipo = 'novo' | 'postado' | 'cancelado'
//   novo      → logo depois que o cliente faz o pedido (resumo + botão Acompanhar pedido)
//   postado   → quando a loja gera a etiqueta do envio (código de rastreio + botão Rastrear)
//   cancelado → quando a loja cancela o pedido
//
// Como publicar: Supabase → Edge Functions → "Deploy a new function" → "Via Editor"
//   nome: ff-email → cole este arquivo inteiro → Deploy → em Details desligue "Verify JWT".
// Segredos (Edge Functions → Secrets):
//   GMAIL_USER      = o Gmail que manda os e-mails (o mesmo do SMTP do Supabase)
//   GMAIL_SENHA_APP = a senha de app de 16 letras desse Gmail (a mesma do SMTP do Supabase)
//   EMAIL_NOME      = (opcional) nome que aparece como remetente; padrão "GoPedido"

import { createClient } from 'npm:@supabase/supabase-js@2';
import nodemailer from 'npm:nodemailer@6.9.16';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS'
};
const SITE = 'https://goscripts.com.br/delivery/';
const COR = '#F2451C';

class Falha extends Error {
  constructor(codigo, status = 400, detalhe = '') { super(codigo); this.status = status; this.detalhe = detalhe; }
}
const ok = (r, onde) => { if (r && r.error) throw new Falha('erro_banco', 500, onde + ': ' + (r.error.message || r.error)); return r; };

export const h = (s) => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
export const brl = (v) => 'R$ ' + Number(v || 0).toFixed(2).replace('.', ',').replace(/\B(?=(\d{3})+(?!\d))/g, '.');
const so = (s) => String(s || '').replace(/\D/g, '');
const wa = (tel, msg) => { let d = so(tel); if (d.length <= 11) d = '55' + d; return 'https://wa.me/' + d + '?text=' + encodeURIComponent(msg); };

// Moldura igual à dos e-mails de cadastro
export function moldura({ previa, titulo, texto, corpo = '', botao = null, botao2 = null, rodapeLoja = '' }) {
  const btn = (b, cheio) => b ? `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin-top:12px"><tr><td align="center" style="border-radius:14px;background:${cheio ? COR : '#ffffff'};${cheio ? '' : 'border:1.5px solid #E6E3DE;'}">
      <a href="${h(b.url)}" style="display:block;padding:15px 20px;color:${cheio ? '#ffffff' : '#16161B'};font-size:16px;font-weight:700;text-decoration:none;border-radius:14px">${h(b.texto)}</a></td></tr></table>` : '';
  return `<!DOCTYPE html><html lang="pt-BR"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${h(titulo)}</title></head>
<body style="margin:0;padding:0;background:#F7F6F3;font-family:-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;color:#16161B">
<div style="display:none;max-height:0;overflow:hidden">${h(previa)}</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#F7F6F3;padding:28px 12px"><tr><td align="center">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:500px">
  <tr><td align="center" style="padding:0 0 20px;font-size:22px;font-weight:800;letter-spacing:-0.5px">Go<span style="color:${COR}">Pedido</span></td></tr>
  <tr><td style="background:#ffffff;border-radius:20px;padding:30px 26px;box-shadow:0 2px 12px rgba(22,22,27,.06)">
    <h1 style="margin:0 0 10px;font-size:22px;line-height:1.25;letter-spacing:-0.5px">${h(titulo)}</h1>
    <p style="margin:0 0 18px;font-size:15px;line-height:1.6;color:#4a4a55">${texto}</p>
    ${corpo}
    ${btn(botao, true)}${btn(botao2, false)}
    ${rodapeLoja}
  </td></tr>
  <tr><td align="center" style="padding:20px 10px 0;font-size:12px;line-height:1.6;color:#9a9aa5">
    Você recebeu este e-mail porque fez um pedido pelo GoPedido.<br>
    O GoPedido é a plataforma; a venda e a entrega são feitas pela loja. <a href="${SITE}termos.html" style="color:#9a9aa5">Termos de Uso</a>
  </td></tr>
</table></td></tr></table></body></html>`;
}

export function montarEmail(tipo, p, l, itens) {
  const link = SITE + 'pedido.html?t=' + encodeURIComponent(p.token);
  const env = p.tipo_entrega === 'envio', ret = p.tipo_entrega === 'retirada';
  const contato = l.telefone ? `<p style="margin:20px 0 0;font-size:13px;line-height:1.6;color:#71717F">Dúvidas, trocas ou reembolsos são com a loja <b>${h(l.nome)}</b>: <a href="${h(wa(l.telefone, 'Olá! Sobre o meu pedido #' + p.numero + ' pelo GoPedido.'))}" style="color:${COR};font-weight:700">falar no WhatsApp</a>.</p>`
    : `<p style="margin:20px 0 0;font-size:13px;line-height:1.6;color:#71717F">Dúvidas, trocas ou reembolsos são com a loja <b>${h(l.nome)}</b>.</p>`;
  const linha = (a, b, forte) => `<tr><td style="padding:6px 0;font-size:14px;color:${forte ? '#16161B' : '#4a4a55'};${forte ? 'font-weight:800;font-size:16px;' : ''}">${a}</td><td align="right" style="padding:6px 0;font-size:14px;white-space:nowrap;${forte ? 'font-weight:800;font-size:16px;' : ''}">${b}</td></tr>`;
  const resumo = `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="border-top:1px solid #EEECE8;border-bottom:1px solid #EEECE8;margin:4px 0 6px">
      ${(itens || []).map(i => linha(`<b>${i.qtd}×</b> ${h(i.nome)}`, brl(i.preco * i.qtd))).join('')}
    </table>
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
      ${linha('Subtotal', brl(p.subtotal))}
      ${linha(ret ? 'Retirada na loja' : env ? 'Frete (' + h(p.frete_nome || 'envio') + ')' : 'Entrega', Number(p.taxa_entrega) ? brl(p.taxa_entrega) : 'Grátis')}
      ${Number(p.desconto) ? linha('Desconto', '- ' + brl(p.desconto)) : ''}
      ${linha('Total', brl(p.total), true)}
    </table>
    <p style="margin:14px 0 0;font-size:13px;line-height:1.6;color:#71717F">${ret ? 'Retirar em: ' + h(l.endereco || 'endereço da loja') : (env ? 'Enviar para: ' : 'Entregar em: ') + h(p.endereco) + (p.complemento ? ' · ' + h(p.complemento) : '')}</p>`;

  if (tipo === 'novo') return {
    assunto: `Pedido #${p.numero} recebido · ${l.nome}`,
    html: moldura({
      previa: `A ${l.nome} recebeu seu pedido #${p.numero}. Guarde este e-mail para acompanhar.`,
      titulo: `Pedido #${p.numero} recebido!`,
      texto: `A loja <b>${h(l.nome)}</b> já recebeu seu pedido. ${env ? 'Ela vai separar, embalar e postar; quando postar, você recebe outro e-mail com o código de rastreio.' : ret ? 'Avisaremos na página do pedido quando estiver pronto para retirar.' : 'Acompanhe cada etapa até a entrega.'} Guarde este e-mail: o botão abaixo abre seu pedido a qualquer momento.`,
      corpo: resumo, botao: { texto: 'Acompanhar meu pedido', url: link }, rodapeLoja: contato
    })
  };
  if (tipo === 'postado') {
    const rastrear = 'https://www.melhorrastreio.com.br/rastreio/' + encodeURIComponent(p.rastreio);
    return {
      assunto: `Seu pedido #${p.numero} foi enviado · ${l.nome}`,
      html: moldura({
        previa: `Código de rastreio: ${p.rastreio}`,
        titulo: 'Seu pedido está a caminho',
        texto: `A loja <b>${h(l.nome)}</b> preparou o envio do seu pedido #${p.numero} pela <b>${h(p.frete_nome || 'transportadora')}</b>${p.frete_prazo ? `, com prazo de até <b>${p.frete_prazo} dia${p.frete_prazo > 1 ? 's' : ''} úteis</b> depois da postagem` : ''}.`,
        corpo: `<table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr><td align="center" style="background:#F7F6F3;border-radius:14px;padding:16px">
            <div style="font-size:12px;color:#71717F;margin-bottom:4px">Código de rastreio</div>
            <div style="font-size:20px;font-weight:800;letter-spacing:1px">${h(p.rastreio)}</div></td></tr></table>
          <p style="margin:12px 0 0;font-size:13px;line-height:1.6;color:#71717F">O rastreio pode levar algumas horas para mostrar movimentação depois que a loja entregar o pacote na transportadora.</p>`,
        botao: { texto: 'Rastrear meu pedido', url: rastrear }, botao2: { texto: 'Ver meu pedido', url: link }, rodapeLoja: contato
      })
    };
  }
  if (tipo === 'cancelado') return {
    assunto: `Pedido #${p.numero} cancelado · ${l.nome}`,
    html: moldura({
      previa: `A ${l.nome} cancelou o pedido #${p.numero}.`,
      titulo: `Pedido #${p.numero} cancelado`,
      texto: `A loja <b>${h(l.nome)}</b> cancelou o seu pedido.${p.pagamento === 'pix' ? ` Como você pagou <b>${brl(p.total)}</b> por Pix, a devolução do valor é feita pela loja: fale com ela se ainda não recebeu.` : ''}`,
      corpo: '', botao: { texto: 'Ver meu pedido', url: link }, rodapeLoja: contato
    })
  };
  throw new Falha('tipo_invalido');
}

export async function tratar(req, admin, enviar) {
  if (req.method === 'OPTIONS') return { status: 200, corpo: 'ok' };
  if (req.method !== 'POST') throw new Falha('metodo_invalido', 405);
  const b = await req.json().catch(() => ({}));
  const tipo = String(b.tipo || '');
  if (!['novo', 'postado', 'cancelado'].includes(tipo)) throw new Falha('tipo_invalido');
  if (!/^[a-z0-9]{8,40}$/i.test(String(b.token || ''))) throw new Falha('pedido_invalido');

  const { data: p } = ok(await admin.from('ff_pedidos').select('*').eq('token', b.token).maybeSingle(), 'pedido');
  if (!p) throw new Falha('pedido_invalido', 404);
  const ja = p.emails || {};
  const pula = (motivo) => ({ status: 200, corpo: { enviado: false, motivo } });
  if (!p.cliente_email) return pula('sem_email');
  if (ja[tipo]) return pula('ja_enviado');
  // Só manda se a situação do pedido bate com o tipo do e-mail
  if (tipo === 'novo' && p.status === 'cancelado') return pula('situacao');
  if (tipo === 'postado' && !(p.tipo_entrega === 'envio' && p.etiqueta_status === 'gerada' && p.rastreio && p.status !== 'cancelado')) return pula('situacao');
  if (tipo === 'cancelado' && p.status !== 'cancelado') return pula('situacao');

  const { data: l } = ok(await admin.from('ff_lojas').select('nome, telefone, endereco').eq('id', p.loja_id).maybeSingle(), 'loja');
  const { data: itens } = ok(await admin.from('ff_pedido_itens').select('nome, preco, qtd').eq('pedido_id', p.id), 'itens');
  const { assunto, html } = montarEmail(tipo, p, l || { nome: 'Loja' }, itens || []);

  // Marca antes de enviar, para dois cliques ao mesmo tempo não mandarem dois e-mails
  ok(await admin.from('ff_pedidos').update({ emails: { ...ja, [tipo]: new Date().toISOString() } }).eq('id', p.id), 'marcar');
  try {
    await enviar({ para: p.cliente_email, assunto, html });
  } catch (e) {
    await admin.from('ff_pedidos').update({ emails: ja }).eq('id', p.id); // deixa tentar de novo
    throw new Falha('email_falhou', 502, String(e && e.message || e).slice(0, 300));
  }
  return { status: 200, corpo: { enviado: true } };
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
      const USER = Deno.env.get('GMAIL_USER'), SENHA = (Deno.env.get('GMAIL_SENHA_APP') || '').replace(/\s+/g, '');
      if (!USER || !SENHA) return resp(500, { error: 'email_nao_configurado', detalhe: 'faltam os segredos GMAIL_USER / GMAIL_SENHA_APP' });
      const admin = createClient(Deno.env.get('SUPABASE_URL'), SECRETA, { auth: { persistSession: false, autoRefreshToken: false } });
      // Porta 465 (as Edge Functions não deixam sair pela 25 nem pela 587)
      const transporte = nodemailer.createTransport({ host: 'smtp.gmail.com', port: 465, secure: true, auth: { user: USER, pass: SENHA } });
      const nome = Deno.env.get('EMAIL_NOME') || 'GoPedido';
      const enviar = ({ para, assunto, html }) => transporte.sendMail({ from: `"${nome}" <${USER}>`, to: para, subject: assunto, html });
      const r = await tratar(req, admin, enviar);
      return resp(r.status, r.corpo);
    } catch (e) {
      return resp(e instanceof Falha ? e.status : 500, { error: e instanceof Falha ? e.message : 'erro_interno', detalhe: e instanceof Falha ? e.detalhe : String(e && e.message || e) });
    }
  });
}
