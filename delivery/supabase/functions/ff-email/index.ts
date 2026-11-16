// @ts-nocheck
// GoPedido — Edge Function "ff-email"
// Manda e-mails para o cliente sobre o pedido, pelo Gmail (mesma conta e senha de app usadas no Supabase).
// Cada e-mail sai UMA vez só por pedido, e só quando a situação do pedido confere com o tipo pedido.
// Precisa do SQL v22 rodado antes.
//
// Ação (POST, corpo JSON): { token, tipo }   tipo = 'novo' | 'postado' | 'cancelado' | 'nota'
//   novo      → logo depois que o cliente faz o pedido (no pagamento online, só depois de aprovado)
//   postado   → quando a loja gera a etiqueta do envio (código de rastreio + botão Rastrear)
//   cancelado → quando a loja cancela o pedido
//   nota      → quando a loja anexa a nota fiscal (PDF e/ou chave de acesso) — precisa do SQL v23
// Ação { acao: 'nf_link', token } → link temporário (10 min) para o cliente baixar o PDF da nota
// Agendamentos (SQL v25): { agendamento: token, tipo: 'ag_novo' | 'ag_remarcado' | 'ag_cancelado' }
//   e { acao: 'lembretes' } → chamado de 5 em 5 minutos pelo agendador; manda o lembrete 3 h antes
//   (o mesmo agendador manda o "Como foi seu pedido?" 40 min depois da entrega, para o cliente avaliar a loja)
// Avisos no celular do lojista (SQL v29): { acao: 'push_chave' | 'push_pedido' | 'push_agenda' | 'push_teste' }
// Avisos no celular do motoboy (SQL v31): { acao: 'push_moto', id, evento: 'pronto' | 'coletado' | 'entregue' }
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
export function moldura({ previa, titulo, texto, corpo = '', botao = null, botao2 = null, rodapeLoja = '', agenda = false, aviso = '' }) {
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
    ${aviso ? aviso : agenda ? 'Você recebeu este e-mail porque marcou um horário pelo GoPedido.<br>O GoPedido é a plataforma; o atendimento é feito pelo estabelecimento.'
             : 'Você recebeu este e-mail porque fez um pedido pelo GoPedido.<br>O GoPedido é a plataforma; a venda e a entrega são feitas pela loja.'} <a href="${SITE}termos.html" style="color:#9a9aa5">Termos de Uso</a>
  </td></tr>
</table></td></tr></table></body></html>`;
}

// Versão em texto simples (os filtros de spam confiam mais em e-mails que têm as duas versões)
export function textoSimples(html) {
  return String(html)
    .replace(/<head>[\s\S]*?<\/head>/i, '')
    .replace(/<div style="display:none[^>]*>[\s\S]*?<\/div>/i, '')
    .replace(/<a [^>]*href="([^"]+)"[^>]*>([\s\S]*?)<\/a>/gi, (m, url, t) => t.replace(/<[^>]+>/g, '').trim() + ' (' + url.replace(/&amp;/g, '&') + ')')
    .replace(/<\/(p|h1|tr|table|div)>/gi, '\n').replace(/<br\s*\/?>/gi, '\n').replace(/<\/td>/gi, '  ')
    .replace(/<[^>]+>/g, '').replace(/&nbsp;/g, ' ').replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&#39;/g, "'")
    .split('\n').map(x => x.replace(/\s+/g, ' ').trim()).filter(Boolean).join('\n');
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
  if (tipo === 'avaliar') {
    const est = [1, 2, 3, 4, 5].map(n => `<td align="center" style="padding:0 3px"><a href="${h(link + '&nota=' + n + '#aval')}" style="display:block;text-decoration:none;font-size:34px;line-height:40px;color:#F5B301">★</a><div style="font-size:11px;color:#9a9aa5">${n}</div></td>`).join('');
    return {
      assunto: `Como foi seu pedido na ${l.nome}?`,
      html: moldura({
        previa: `Seu pedido #${p.numero} foi entregue. Conta pra gente como foi: leva 10 segundos.`,
        titulo: `Como foi seu pedido?`,
        texto: `Seu pedido <b>#${p.numero}</b> da <b>${h(l.nome)}</b> foi ${ret ? 'retirado' : 'entregue'}. Que tal avaliar? Leva 10 segundos e ajuda muito a loja e outros clientes. Toque numa estrela:`,
        corpo: `<table role="presentation" cellpadding="0" cellspacing="0" align="center" style="margin:0 auto 6px"><tr>${est}</tr></table>`,
        botao: { texto: 'Avaliar a loja', url: link + '&avaliar=1#aval' }, rodapeLoja: contato
      })
    };
  }
  if (tipo === 'cancelado') return {
    assunto: `Pedido #${p.numero} cancelado · ${l.nome}`,
    html: moldura({
      previa: `A ${l.nome} cancelou o pedido #${p.numero}.`,
      titulo: `Pedido #${p.numero} cancelado`,
      texto: `A loja <b>${h(l.nome)}</b> cancelou o seu pedido.${p.pagamento === 'pix' ? ` Como você pagou <b>${brl(p.total)}</b> por Pix, a devolução do valor é feita pela loja: fale com ela se ainda não recebeu.` : ''}${p.pagamento === 'mp' && p.mp_status === 'estornado' ? ` O valor de <b>${brl(p.total)}</b> foi devolvido pelo Mercado Pago, no mesmo meio de pagamento que você usou. No cartão, pode levar até a próxima fatura para aparecer.` : ''}${p.pagamento === 'mp' && p.mp_status === 'aprovado' ? ` Como você pagou <b>${brl(p.total)}</b> online, fale com a loja sobre a devolução se ela ainda não tiver feito.` : ''}`,
      corpo: '', botao: { texto: 'Ver meu pedido', url: link }, rodapeLoja: contato
    })
  };
  if (tipo === 'nota') {
    const chaveFmt = (p.nf_chave || '').replace(/(\d{4})(?=\d)/g, '$1 ');
    return {
      assunto: `Nota fiscal do pedido #${p.numero} · ${l.nome}`,
      html: moldura({
        previa: `A ${l.nome} enviou a nota fiscal do seu pedido #${p.numero}.`,
        titulo: 'Sua nota fiscal chegou',
        texto: `A loja <b>${h(l.nome)}</b> anexou a nota fiscal do seu pedido #${p.numero}.${p.nf_path ? ' Abra a página do pedido para baixar o PDF.' : ''}`,
        corpo: p.nf_chave ? `<table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr><td style="background:#F7F6F3;border-radius:14px;padding:16px">
            <div style="font-size:12px;color:#71717F;margin-bottom:4px">Chave de acesso da NF-e</div>
            <div style="font-size:14px;font-weight:700;letter-spacing:.5px;line-height:1.6">${h(chaveFmt)}</div></td></tr></table>
          <p style="margin:12px 0 0;font-size:13px;line-height:1.6;color:#71717F">Você pode consultar a nota no portal da nota fiscal eletrônica com essa chave.</p>` : '',
        botao: { texto: p.nf_path ? 'Baixar a nota fiscal' : 'Ver meu pedido', url: link }, rodapeLoja: contato
      })
    };
  }
  throw new Falha('tipo_invalido');
}

// ---------- Agendamentos (salão, barbearia…) ----------
export const quando = (iso) => {
  const d = new Date(iso);
  const dia = new Intl.DateTimeFormat('pt-BR', { timeZone: 'America/Sao_Paulo', weekday: 'long', day: '2-digit', month: 'long' }).format(d);
  const hora = new Intl.DateTimeFormat('pt-BR', { timeZone: 'America/Sao_Paulo', hour: '2-digit', minute: '2-digit' }).format(d);
  return { dia: dia.charAt(0).toUpperCase() + dia.slice(1), hora };
};
const gcal = (a, l) => {
  const f = (iso) => new Date(iso).toISOString().replace(/[-:]/g, '').replace(/\.\d{3}/, '');
  return 'https://calendar.google.com/calendar/render?action=TEMPLATE&text=' + encodeURIComponent(a.servico_nome + ' · ' + l.nome)
    + '&dates=' + f(a.inicio) + '/' + f(a.fim) + '&location=' + encodeURIComponent(l.endereco || '') + '&details=' + encodeURIComponent('Com ' + a.profissional_nome + '. Marcado pelo GoPedido.');
};
export function montarAgenda(tipo, a, l) {
  const link = SITE + 'agenda.html?t=' + encodeURIComponent(a.token);
  const q = quando(a.inicio);
  const card = `<table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr><td style="background:#F7F6F3;border-radius:14px;padding:16px 18px">
      <div style="font-size:13px;color:#71717F">${h(q.dia)}</div>
      <div style="font-size:26px;font-weight:800;letter-spacing:-0.5px;margin:2px 0 8px">${h(q.hora)}</div>
      <div style="font-size:15px;font-weight:700">${h(a.servico_nome)}</div>
      <div style="font-size:14px;color:#4a4a55;margin-top:2px">com ${h(a.profissional_nome)} · ${a.duracao_min} min${Number(a.preco) ? ' · ' + brl(a.preco) : ''}</div>
      ${l.endereco ? `<div style="font-size:13px;color:#71717F;margin-top:10px">📍 ${h(l.endereco)}</div>` : ''}
    </td></tr></table>`;
  const contato = l.telefone ? `<p style="margin:20px 0 0;font-size:13px;line-height:1.6;color:#71717F">Precisa falar com <b>${h(l.nome)}</b>? <a href="${h(wa(l.telefone, 'Olá! Sobre o meu horário de ' + q.dia.toLowerCase() + ' às ' + q.hora + ' (' + a.servico_nome + ') pelo GoPedido.'))}" style="color:${COR};font-weight:700">Chamar no WhatsApp</a>.</p>` : '';
  if (tipo === 'ag_novo') return {
    assunto: `Horário marcado: ${q.dia.toLowerCase()} às ${q.hora} · ${l.nome}`,
    html: moldura({ agenda: true,
      previa: `${a.servico_nome} com ${a.profissional_nome}, ${q.dia.toLowerCase()} às ${q.hora}.`,
      titulo: 'Seu horário está marcado!',
      texto: `Tudo certo com <b>${h(l.nome)}</b>. Vamos te lembrar por e-mail 3 horas antes. Se não puder ir, cancele pelo botão abaixo para liberar o horário.`,
      corpo: card, botao: { texto: 'Ver ou cancelar meu horário', url: link }, botao2: { texto: 'Adicionar à minha agenda', url: gcal(a, l) }, rodapeLoja: contato
    })
  };
  if (tipo === 'ag_lembrete') return {
    assunto: `Lembrete: hoje às ${q.hora} · ${l.nome}`,
    html: moldura({ agenda: true,
      previa: `Seu horário de ${a.servico_nome} é hoje às ${q.hora}.`,
      titulo: `Seu horário é às ${q.hora}`,
      texto: `Passando para lembrar do seu horário com <b>${h(l.nome)}</b>. Se não puder ir, avise a loja ou cancele pelo botão abaixo.`,
      corpo: card, botao: { texto: 'Ver meu horário', url: link },
      botao2: l.lat != null ? { texto: 'Como chegar', url: 'https://www.google.com/maps/dir/?api=1&destination=' + l.lat + ',' + l.lng } : null, rodapeLoja: contato
    })
  };
  if (tipo === 'ag_remarcado') return {
    assunto: `Horário alterado: ${q.dia.toLowerCase()} às ${q.hora} · ${l.nome}`,
    html: moldura({ agenda: true,
      previa: `Novo horário: ${q.dia.toLowerCase()} às ${q.hora}.`,
      titulo: 'Seu horário foi alterado',
      texto: `<b>${h(l.nome)}</b> alterou o seu horário. Confira como ficou:`,
      corpo: card, botao: { texto: 'Ver meu horário', url: link }, botao2: { texto: 'Adicionar à minha agenda', url: gcal(a, l) }, rodapeLoja: contato
    })
  };
  if (tipo === 'ag_cancelado') return {
    assunto: `Horário cancelado · ${l.nome}`,
    html: moldura({ agenda: true,
      previa: `O horário de ${q.dia.toLowerCase()} às ${q.hora} foi cancelado.`,
      titulo: 'Horário cancelado',
      texto: a.cancelado_por === 'cliente'
        ? `Você cancelou o seu horário de <b>${h(a.servico_nome)}</b> em <b>${h(l.nome)}</b> (${h(q.dia.toLowerCase())} às ${h(q.hora)}). Quando quiser, é só marcar de novo.`
        : `<b>${h(l.nome)}</b> cancelou o seu horário de <b>${h(a.servico_nome)}</b> (${h(q.dia.toLowerCase())} às ${h(q.hora)}). Você pode marcar outro horário pelo botão abaixo.`,
      corpo: '', botao: { texto: 'Marcar outro horário', url: SITE + 'agenda.html?l=' + encodeURIComponent(l.slug || '') }, rodapeLoja: contato
    })
  };
  throw new Falha('tipo_invalido');
}

async function enviarAgenda(admin, enviar, a, tipo) {
  const ja = a.emails || {};
  const { data: l } = ok(await admin.from('ff_lojas').select('nome, slug, telefone, endereco, lat, lng, dono').eq('id', a.loja_id).maybeSingle(), 'loja');
  const { assunto, html } = montarAgenda(tipo, a, l || { nome: 'Estabelecimento' });
  let responder = '';
  try { const { data: u } = await admin.auth.admin.getUserById(l && l.dono); responder = (u && u.user && u.user.email) || ''; } catch (_) {}
  const marca = { emails: { ...ja, [tipo]: new Date().toISOString() }, ...(tipo === 'ag_lembrete' ? { lembrete_em: new Date().toISOString() } : {}) };
  ok(await admin.from('ff_agendamentos').update(marca).eq('id', a.id), 'marcar');
  try {
    await enviar({ para: a.cliente_email, assunto, html, texto: textoSimples(html), loja: (l && l.nome) || '', responder });
  } catch (e) {
    await admin.from('ff_agendamentos').update({ emails: ja, ...(tipo === 'ag_lembrete' ? { lembrete_em: null } : {}) }).eq('id', a.id);
    throw new Falha('email_falhou', 502, String(e && e.message || e).slice(0, 300));
  }
}

// Roda de 5 em 5 minutos (agendador do Supabase): manda o lembrete de quem tem horário nas próximas 3 horas

// ---------------------------------------------------------------------------
// Lojas de assinatura e códigos digitais (SQL v33)
//   { acao: 'assin_pago', id }     → pagamento aprovado: confirmação (+ código, se o plano entrega código)
//   { acao: 'assin_convite', id }  → o lojista cadastrou o assinante: link para escolher o período e pagar
//   { acao: 'assin_link', id }     → quem já é assinante tentou assinar de novo: manda o link de renovação
//   { acao: 'codigos_pedido', id } → pedido com produto de código digital: manda os códigos por e-mail
//   e o agendador (acao 'lembretes') avisa 3 dias antes, no dia e 3 dias depois do vencimento.
// ---------------------------------------------------------------------------
const dBR = (d) => String(d || '').slice(0, 10).split('-').reverse().join('/');
const AVISO_ASSIN = 'Você recebeu este e-mail porque tem uma assinatura feita pelo GoPedido.<br>O GoPedido é a plataforma; a assinatura é vendida pela loja.';
const caixaCodigo = (rot, cod) => `<div style="margin:0 0 10px;padding:14px 16px;border:1.5px dashed ${COR};border-radius:14px;background:#FFF7F3">
  <div style="font-size:12px;color:#7a7a85;margin-bottom:4px">${h(rot)}</div>
  <div style="font-family:Menlo,Consolas,monospace;font-size:17px;font-weight:700;letter-spacing:.5px;word-break:break-all;color:#16161B">${h(cod)}</div></div>`;
const linkAssin = (a) => SITE + 'assinatura.html?t=' + encodeURIComponent(a.token);
async function dadosAssin(admin, assinanteId) {
  const { data: a } = ok(await admin.from('ff_assinantes').select('*').eq('id', assinanteId).maybeSingle(), 'assinante');
  if (!a) return null;
  const { data: pl } = ok(await admin.from('ff_assin_planos').select('*').eq('id', a.plano_id).maybeSingle(), 'plano');
  const { data: l } = ok(await admin.from('ff_lojas').select('id, nome, telefone, dono').eq('id', a.loja_id).maybeSingle(), 'loja');
  return { a, pl: pl || { nome: 'Assinatura' }, l: l || { nome: 'Loja' } };
}
async function emailDoDono(admin, dono) {
  try { const { data: u } = await admin.auth.admin.getUserById(dono); return (u && u.user && u.user.email) || ''; } catch (_) { return ''; }
}
const contatoLoja = (l) => {
  const w = String(l.telefone || '').replace(/\D/g, '');
  return w ? `<p style="margin:18px 0 0;font-size:13px;color:#7a7a85">Dúvidas? Fale com a loja: <a href="https://wa.me/${w.length <= 11 ? '55' + w : w}" style="color:${COR}">WhatsApp da ${h(l.nome)}</a></p>` : '';
};

export async function assinPago(admin, enviar, id) {
  if (!/^[0-9a-f-]{36}$/i.test(String(id || ''))) throw new Falha('pagamento_invalido');
  const { data: g } = ok(await admin.from('ff_assin_pagamentos').update({ email_em: new Date().toISOString() })
    .eq('id', id).eq('status', 'aprovado').is('email_em', null).select('*').maybeSingle(), 'pagamento');
  if (!g) return { enviado: false, motivo: 'ja_enviado_ou_situacao' };
  const d = await dadosAssin(admin, g.assinante_id); if (!d) return { enviado: false };
  const { a, pl, l } = d;
  const per = `${g.meses} ${g.meses > 1 ? 'meses' : 'mês'}`;
  const html = moldura({
    previa: `Sua assinatura ${pl.nome} está ativa até ${dBR(g.valido_ate)}.`,
    titulo: g.codigo ? 'Pagamento confirmado: aqui está seu código' : 'Pagamento confirmado!',
    texto: `Oi, ${h(a.nome.split(' ')[0])}! Recebemos o pagamento de <b>${h(pl.nome)}</b> (${per}${Number(g.valor) ? ' · ' + brl(g.valor) : ''}) na <b>${h(l.nome)}</b>. Sua assinatura vale até <b>${dBR(g.valido_ate)}</b>.`,
    corpo: (g.codigo ? caixaCodigo('Seu código', g.codigo) + `<p style="margin:0 0 6px;font-size:13px;color:#7a7a85">Guarde este e-mail. Se tiver dúvida sobre como usar o código, fale com a loja.</p>` : '')
      + `<p style="margin:10px 0 0;font-size:13px;color:#7a7a85">Antes de vencer, avisamos por e-mail com o link para renovar.</p>`,
    botao: { texto: 'Ver minha assinatura', url: linkAssin(a) }, rodapeLoja: contatoLoja(l), aviso: AVISO_ASSIN
  });
  await enviar({ para: a.email, assunto: g.codigo ? `Seu código: ${pl.nome} · ${l.nome}` : `Assinatura confirmada: ${pl.nome} · ${l.nome}`, html, texto: textoSimples(html), loja: l.nome, responder: await emailDoDono(admin, l.dono) });
  return { enviado: true };
}

export async function assinConvite(admin, enviar, id, tipo = 'convite') {
  if (!/^[0-9a-f-]{36}$/i.test(String(id || ''))) throw new Falha('assinante_invalido');
  const d = await dadosAssin(admin, id); if (!d) return { enviado: false };
  const { a, pl, l } = d;
  const av = a.avisos || {};
  if (tipo === 'convite' && (a.status !== 'pendente' || av.convite)) return { enviado: false, motivo: 'situacao' };
  if (tipo === 'link' && (a.status !== 'ativo' || (av.link && Date.now() - new Date(av.link).getTime() < 10 * 60e3))) return { enviado: false, motivo: 'situacao' };
  ok(await admin.from('ff_assinantes').update({ avisos: { ...av, [tipo]: new Date().toISOString() } }).eq('id', a.id), 'marcar');
  const html = tipo === 'convite' ? moldura({
    previa: `Ative sua assinatura ${pl.nome} na ${l.nome}.`,
    titulo: `Sua assinatura na ${l.nome}`,
    texto: `Oi, ${h(a.nome.split(' ')[0])}! A <b>${h(l.nome)}</b> cadastrou você na assinatura <b>${h(pl.nome)}</b>. Para ativar, escolha por quanto tempo quer assinar e pague pelo Pix ou cartão.`,
    botao: { texto: 'Escolher o período e pagar', url: linkAssin(a) }, rodapeLoja: contatoLoja(l), aviso: AVISO_ASSIN
  }) : moldura({
    previa: `Você já é assinante de ${pl.nome}.`,
    titulo: 'Você já é assinante',
    texto: `Oi, ${h(a.nome.split(' ')[0])}! Alguém tentou assinar <b>${h(pl.nome)}</b> na <b>${h(l.nome)}</b> com o seu e-mail, mas você já é assinante${a.valido_ate ? ' até <b>' + dBR(a.valido_ate) + '</b>' : ''}. Para renovar antes, use o botão abaixo.`,
    botao: { texto: 'Ver minha assinatura', url: linkAssin(a) }, rodapeLoja: contatoLoja(l), aviso: AVISO_ASSIN
  });
  await enviar({ para: a.email, assunto: tipo === 'convite' ? `Ative sua assinatura: ${pl.nome} · ${l.nome}` : `Sua assinatura ${pl.nome} · ${l.nome}`, html, texto: textoSimples(html), loja: l.nome, responder: await emailDoDono(admin, l.dono) });
  return { enviado: true };
}

export async function codigosPedido(admin, enviar, id, rede = fetch) {
  if (!/^[0-9a-f-]{36}$/i.test(String(id || ''))) throw new Falha('pedido_invalido');
  const { data: p } = ok(await admin.from('ff_pedidos').update({ codigos_em: new Date().toISOString() })
    .eq('id', id).is('codigos_em', null).select('*').maybeSingle(), 'pedido');
  if (!p) return { enviado: false, motivo: 'ja_enviado' };
  const { data: cods } = ok(await admin.from('ff_codigos').select('codigo, produto_id').eq('pedido_id', p.id), 'códigos');
  const { data: itens } = ok(await admin.from('ff_pedido_itens').select('produto_id, nome, qtd').eq('pedido_id', p.id), 'itens');
  const { data: l } = ok(await admin.from('ff_lojas').select('id, nome, telefone, dono').eq('id', p.loja_id).maybeSingle(), 'loja');
  const ids = [...new Set((cods || []).map(c => c.produto_id))];
  const nomes = {}; (itens || []).forEach(i => { if (!nomes[i.produto_id]) nomes[i.produto_id] = i.nome; });
  // quantos o pedido precisava × quantos foram separados
  const { data: prods } = ok(await admin.from('ff_produtos').select('id, nome').in('id', [...new Set((itens || []).map(i => i.produto_id))]).eq('entrega_codigo', true), 'produtos');
  const precisa = (itens || []).filter(i => (prods || []).some(x => x.id === i.produto_id)).reduce((t, i) => t + Number(i.qtd), 0);
  const faltou = Math.max(0, precisa - (cods || []).length);
  if (faltou && l) {
    try {
      await mandarPush(admin, await pessoasDaLoja(admin, l), { titulo: `Faltaram ${faltou} código${faltou > 1 ? 's' : ''} no pedido #${p.numero}`, corpo: 'Cadastre mais códigos no produto e mande para o cliente pelo WhatsApp.', url: SITE + 'painel.html?loja=' + l.id, tag: 'cod-' + p.id }, rede);
    } catch (_) {}
  }
  if (!p.cliente_email || !(cods || []).length) return { enviado: false, faltou };
  const html = moldura({
    previa: `Seus códigos do pedido #${p.numero} chegaram.`,
    titulo: 'Seus códigos chegaram',
    texto: `Oi, ${h(String(p.cliente_nome || '').split(' ')[0])}! Aqui estão os códigos do seu pedido <b>#${p.numero}</b> na <b>${h(l ? l.nome : '')}</b>.`,
    corpo: (cods || []).map(c => caixaCodigo(nomes[c.produto_id] || 'Código', c.codigo)).join('')
      + (faltou ? `<p style="margin:6px 0 0;font-size:13px;color:#b45309">${faltou} código${faltou > 1 ? 's' : ''} ainda não ${faltou > 1 ? 'estão disponíveis' : 'está disponível'}: a loja vai mandar para você em breve.</p>` : '')
      + `<p style="margin:10px 0 0;font-size:13px;color:#7a7a85">Guarde este e-mail. Dúvidas sobre como usar, fale com a loja.</p>`,
    botao: { texto: 'Acompanhar o pedido', url: SITE + 'pedido.html?t=' + encodeURIComponent(p.token) }, rodapeLoja: l ? contatoLoja(l) : ''
  });
  await enviar({ para: p.cliente_email, assunto: `Seus códigos · pedido #${p.numero} · ${l ? l.nome : ''}`, html, texto: textoSimples(html), loja: l ? l.nome : '', responder: l ? await emailDoDono(admin, l.dono) : '' });
  return { enviado: true, faltou };
}

// Avisos de vencimento: 3 dias antes, no dia e 3 dias depois (só entre 8h e 21h)
export async function lembretesAssin(admin, enviar, agora = new Date()) {
  const sp = new Date(agora.getTime() - 3 * 3600e3), hora = sp.getUTCHours();
  if (hora < 8 || hora >= 21) return 0;
  const hoje = sp.toISOString().slice(0, 10);
  const dia = (n) => new Date(Date.parse(hoje + 'T12:00:00Z') + n * 864e5).toISOString().slice(0, 10);
  const { data } = ok(await admin.from('ff_assinantes').select('*').eq('status', 'ativo').gte('valido_ate', dia(-3)).lte('valido_ate', dia(3)).order('valido_ate').limit(40), 'assinantes vencendo');
  let n = 0;
  for (const a of data || []) {
    const d = Math.round((Date.parse(a.valido_ate + 'T12:00:00Z') - Date.parse(hoje + 'T12:00:00Z')) / 864e5);
    const chave = d > 0 ? 'v3' : d === 0 ? 'v0' : d <= -3 ? 'vx' : '';
    const av = a.avisos || {};
    if (!chave || av[chave] === a.valido_ate) continue;
    ok(await admin.from('ff_assinantes').update({ avisos: { ...av, [chave]: a.valido_ate } }).eq('id', a.id), 'marcar aviso');
    try {
      const dd = await dadosAssin(admin, a.id); if (!dd) continue;
      const { pl, l } = dd;
      const tit = d > 0 ? `Sua assinatura vence em ${d} dia${d > 1 ? 's' : ''}` : d === 0 ? 'Sua assinatura vence hoje' : 'Sua assinatura venceu';
      const html = moldura({
        previa: `${pl.nome} na ${l.nome}: renove pelo Pix ou cartão.`,
        titulo: tit,
        texto: `Oi, ${h(a.nome.split(' ')[0])}! Sua assinatura <b>${h(pl.nome)}</b> na <b>${h(l.nome)}</b> ${d >= 0 ? 'vale até' : 'venceu em'} <b>${dBR(a.valido_ate)}</b>. ${d >= 0 ? 'Renove agora para não ficar sem.' : 'Renove para voltar a ter acesso.'} Você escolhe por quanto tempo e paga pelo Pix ou cartão.`,
        botao: { texto: 'Renovar minha assinatura', url: linkAssin(a) }, rodapeLoja: contatoLoja(l), aviso: AVISO_ASSIN
      });
      await enviar({ para: a.email, assunto: `${tit}: ${pl.nome} · ${l.nome}`, html, texto: textoSimples(html), loja: l.nome, responder: await emailDoDono(admin, l.dono) });
      n++;
    } catch (_) { /* tenta no próximo ciclo só se desmarcar; aqui segue */ }
  }
  return n;
}

export async function lembretes(admin, enviar, agora = new Date()) {
  const ate = new Date(agora.getTime() + 3 * 3600e3).toISOString();
  const { data } = ok(await admin.from('ff_agendamentos').select('*')
    .eq('status', 'agendado').is('lembrete_em', null).gt('inicio', agora.toISOString()).lte('inicio', ate)
    .order('inicio').limit(40), 'lembretes');
  let enviados = 0, pulados = 0, falhas = 0;
  for (const a of data || []) {
    // marcou faz pouco (menos de 3h30 antes): o e-mail de confirmação já serve de lembrete
    const curto = new Date(a.inicio).getTime() - new Date(a.criado_em).getTime() < 3.5 * 3600e3 && !(a.emails && a.emails.ag_remarcado);
    if (!a.cliente_email || curto) {
      ok(await admin.from('ff_agendamentos').update({ lembrete_em: agora.toISOString() }).eq('id', a.id), 'pular');
      pulados++; continue;
    }
    try { await enviarAgenda(admin, enviar, a, 'ag_lembrete'); enviados++; } catch (_) { falhas++; }
  }
  // Pedido entregue há mais de 40 min (e menos de 2 dias), sem avaliação: pede para avaliar a loja (uma vez só)
  let avaliar = 0;
  try {
    const { data: ps } = await admin.from('ff_pedidos').select('*')
      .eq('status', 'entregue').neq('cliente_email', '').is('emails->>avaliar', null)
      .lt('atualizado_em', new Date(agora.getTime() - 40 * 60e3).toISOString())
      .gt('atualizado_em', new Date(agora.getTime() - 48 * 3600e3).toISOString())
      .order('atualizado_em').limit(30);
    for (const p of ps || []) {
      const ja = p.emails || {};
      const marca = { ...ja, avaliar: agora.toISOString() };
      const { data: av } = await admin.from('ff_avaliacoes').select('id').eq('pedido_id', p.id).maybeSingle();
      ok(await admin.from('ff_pedidos').update({ emails: marca }).eq('id', p.id), 'marcar avaliar');
      if (av) continue; // já avaliou
      try {
        const { data: l } = ok(await admin.from('ff_lojas').select('nome, telefone, endereco, dono').eq('id', p.loja_id).maybeSingle(), 'loja');
        const { assunto, html } = montarEmail('avaliar', p, l || { nome: 'Loja' }, []);
        let responder = '';
        try { const { data: u } = await admin.auth.admin.getUserById(l && l.dono); responder = (u && u.user && u.user.email) || ''; } catch (_) {}
        await enviar({ para: p.cliente_email, assunto, html, texto: textoSimples(html), loja: (l && l.nome) || '', responder });
        avaliar++;
      } catch (_) { await admin.from('ff_pedidos').update({ emails: ja }).eq('id', p.id); }
    }
  } catch (_) { /* segue */ }

  // Planos que vencem em até 5 dias (um aviso por vencimento)
  let planos = 0;
  try {
    const hoje = new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Sao_Paulo' }).format(agora);
    const lim = new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Sao_Paulo' }).format(new Date(agora.getTime() + 5 * 86400e3));
    const { data: vs } = await admin.from('ff_assinaturas').select('email, plano, valido_ate, aviso_em')
      .neq('plano', 'gratis').gte('valido_ate', hoje).lte('valido_ate', lim).is('aviso_em', null).limit(30);
    for (const v of vs || []) {
      ok(await admin.from('ff_assinaturas').update({ aviso_em: hoje }).eq('email', v.email), 'aviso plano');
      const dias = Math.round((new Date(v.valido_ate + 'T12:00:00Z').getTime() - new Date(hoje + 'T12:00:00Z').getTime()) / 86400e3);
      const nome = v.plano === 'premium' ? 'Premium' : 'Profissional';
      const html = moldura({
        previa: `Seu plano ${nome} do GoPedido vence ${dias === 0 ? 'hoje' : dias === 1 ? 'amanhã' : 'em ' + dias + ' dias'}.`,
        titulo: `Seu plano vence ${dias === 0 ? 'hoje' : dias === 1 ? 'amanhã' : 'em ' + dias + ' dias'}`,
        texto: `O plano <b>${nome}</b> da sua loja no GoPedido vale até <b>${v.valido_ate.split('-').reverse().join('/')}</b>. Renove pelo painel com Pix ou cartão para não perder os limites do plano. Pagando 2 ou 3 meses de uma vez sai mais barato.<br><br>Se não renovar, a conta volta para o plano Grátis sozinha. Nada é apagado.`,
        botao: { texto: 'Renovar meu plano', url: SITE + 'painel.html?planos=1' }
      }).replace('Você recebeu este e-mail porque fez um pedido pelo GoPedido.<br>O GoPedido é a plataforma; a venda e a entrega são feitas pela loja.', 'Você recebeu este e-mail porque tem uma loja no GoPedido.');
      try { await enviar({ para: v.email, assunto: `Seu plano ${nome} do GoPedido vence ${dias === 0 ? 'hoje' : dias === 1 ? 'amanhã' : 'em ' + dias + ' dias'}`, html, texto: textoSimples(html), loja: '' }); planos++; }
      catch (_) { await admin.from('ff_assinaturas').update({ aviso_em: null }).eq('email', v.email); }
    }
  } catch (_) { /* sem o SQL v27 ainda */ }
  let assinaturas = 0;
  try { assinaturas = await lembretesAssin(admin, enviar, agora); } catch (_) {}
  return { enviados, pulados, falhas, planos, avaliar, assinaturas };
}

// ---------------------------------------------------------------------------
// Avisos no celular (Web Push) — SQL v29
// As chaves VAPID são criadas pela própria função na primeira vez e guardadas no banco (ff_config),
// então não precisa configurar segredo nenhum.
// Ações: { acao: 'push_chave' }                    → chave pública para o navegador assinar os avisos
//        { acao: 'push_pedido', id }               → chamado pelo banco quando entra pedido (uma vez só)
//        { acao: 'push_agenda', id }               → chamado pelo banco quando o cliente marca horário
//        { acao: 'push_teste' } + login do lojista → manda um aviso de teste para os aparelhos dele
// ---------------------------------------------------------------------------
const te = new TextEncoder();
export const b64u = (buf) => {
  const b = buf instanceof Uint8Array ? buf : new Uint8Array(buf);
  let s = ''; for (let i = 0; i < b.length; i++) s += String.fromCharCode(b[i]);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
};
export const deB64u = (s) => {
  const t = String(s).replace(/-/g, '+').replace(/_/g, '/'); const p = t + '==='.slice((t.length + 3) % 4);
  const bin = atob(p); const o = new Uint8Array(bin.length); for (let i = 0; i < bin.length; i++) o[i] = bin.charCodeAt(i); return o;
};
const junta = (...ps) => { const n = ps.reduce((a, p) => a + p.length, 0); const o = new Uint8Array(n); let i = 0; for (const p of ps) { o.set(p, i); i += p.length; } return o; };
async function hmac(chave, dados) {
  const k = await crypto.subtle.importKey('raw', chave, { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  return new Uint8Array(await crypto.subtle.sign('HMAC', k, dados));
}

export async function novasChavesVapid() {
  const par = await crypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify']);
  const pub = new Uint8Array(await crypto.subtle.exportKey('raw', par.publicKey));
  const jwk = await crypto.subtle.exportKey('jwk', par.privateKey);
  return { publica: b64u(pub), privada: jwk };
}

async function vapidCabecalho(endpoint, vapid, contato) {
  const aud = new URL(endpoint).origin;
  const cab = b64u(te.encode(JSON.stringify({ typ: 'JWT', alg: 'ES256' })));
  const corpo = b64u(te.encode(JSON.stringify({ aud, exp: Math.floor(Date.now() / 1000) + 12 * 3600, sub: contato })));
  const k = await crypto.subtle.importKey('jwk', vapid.privada, { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign']);
  const ass = new Uint8Array(await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, k, te.encode(cab + '.' + corpo)));
  return 'vapid t=' + cab + '.' + corpo + '.' + b64u(ass) + ', k=' + vapid.publica;
}

// Criptografia do aviso (RFC 8291, aes128gcm): só o aparelho do lojista consegue ler
export async function cifrar(texto, p256dh, auth, _teste = null) {
  const uaPub = deB64u(p256dh), segredo = deB64u(auth);
  const par = _teste ? _teste.par : await crypto.subtle.generateKey({ name: 'ECDH', namedCurve: 'P-256' }, true, ['deriveBits']);
  const asPub = new Uint8Array(await crypto.subtle.exportKey('raw', par.publicKey));
  const uaKey = await crypto.subtle.importKey('raw', uaPub, { name: 'ECDH', namedCurve: 'P-256' }, false, []);
  const ecdh = new Uint8Array(await crypto.subtle.deriveBits({ name: 'ECDH', public: uaKey }, par.privateKey, 256));
  const prkKey = await hmac(segredo, ecdh);
  const ikm = await hmac(prkKey, junta(te.encode('WebPush: info\0'), uaPub, asPub, new Uint8Array([1])));
  const sal = _teste ? _teste.sal : crypto.getRandomValues(new Uint8Array(16));
  const prk = await hmac(sal, ikm);
  const cek = (await hmac(prk, junta(te.encode('Content-Encoding: aes128gcm\0'), new Uint8Array([1])))).slice(0, 16);
  const nonce = (await hmac(prk, junta(te.encode('Content-Encoding: nonce\0'), new Uint8Array([1])))).slice(0, 12);
  const k = await crypto.subtle.importKey('raw', cek, { name: 'AES-GCM' }, false, ['encrypt']);
  const cifra = new Uint8Array(await crypto.subtle.encrypt({ name: 'AES-GCM', iv: nonce }, k, junta(te.encode(texto), new Uint8Array([2]))));
  const rs = new Uint8Array([0, 0, 0x10, 0]); // 4096
  return junta(sal, rs, new Uint8Array([asPub.length]), asPub, cifra);
}

export async function chavesVapid(admin) {
  const { data } = ok(await admin.from('ff_config').select('valor').eq('chave', 'vapid').maybeSingle(), 'vapid');
  if (data && data.valor && data.valor.publica) return data.valor;
  const nova = await novasChavesVapid();
  // se duas chamadas criarem ao mesmo tempo, fica a primeira que gravou
  await admin.from('ff_config').insert({ chave: 'vapid', valor: nova });
  const { data: d2 } = ok(await admin.from('ff_config').select('valor').eq('chave', 'vapid').maybeSingle(), 'vapid');
  return d2.valor;
}

// Manda o aviso para todos os aparelhos das pessoas; apaga os que não existem mais
export async function mandarPush(admin, usuarios, aviso, rede = fetch) {
  const ids = [...new Set((usuarios || []).filter(Boolean))];
  if (!ids.length) return { aparelhos: 0, enviados: 0 };
  const { data: subs } = ok(await admin.from('ff_push').select('id, endpoint, p256dh, auth').in('user_id', ids), 'aparelhos');
  return mandarParaAparelhos(admin, subs, aviso, rede, 'ff_push');
}
export async function mandarParaAparelhos(admin, subs, aviso, rede = fetch, tabela = 'ff_push') {
  if (!subs || !subs.length) return { aparelhos: 0, enviados: 0 };
  const vapid = await chavesVapid(admin);
  const corpo = JSON.stringify(aviso);
  let enviados = 0; const mortos = [];
  await Promise.all(subs.map(async (s) => {
    try {
      const r = await rede(s.endpoint, {
        method: 'POST',
        headers: { Authorization: await vapidCabecalho(s.endpoint, vapid, 'https://goscripts.com.br/delivery/'),
                   'Content-Encoding': 'aes128gcm', 'Content-Type': 'application/octet-stream', TTL: '86400', Urgency: 'high' },
        body: await cifrar(corpo, s.p256dh, s.auth)
      });
      if (r.status === 404 || r.status === 410) mortos.push(s.id);
      else if (r.status < 300) enviados++;
    } catch (_) { /* aparelho fora do ar: tenta na próxima */ }
  }));
  if (mortos.length) await admin.from(tabela).delete().in('id', mortos);
  return { aparelhos: subs.length, enviados };
}

// Dono da loja + equipe com acesso a ela
async function pessoasDaLoja(admin, l) {
  const { data: eq } = await admin.from('ff_equipe').select('user_id, todas, lojas').eq('dono', l.dono);
  return [l.dono, ...((eq || []).filter(e => e.todas || (e.lojas || []).includes(l.id)).map(e => e.user_id))];
}

const PAG = { pix: 'Pix', mp: 'Pago online', dinheiro: 'Dinheiro', debito: 'Débito', credito: 'Crédito' };
export async function pushPedido(admin, id, rede = fetch) {
  if (!/^[0-9a-f-]{36}$/i.test(String(id || ''))) throw new Falha('pedido_invalido');
  // marca primeiro (de uma vez só), para não mandar dois avisos do mesmo pedido
  const { data: p } = ok(await admin.from('ff_pedidos').update({ push_em: new Date().toISOString() })
    .eq('id', id).is('push_em', null).neq('status', 'cancelado')
    .or('pagamento.neq.mp,mp_status.eq.aprovado').select('*').maybeSingle(), 'pedido');
  if (!p) return { enviado: false, motivo: 'ja_enviado_ou_situacao' };
  const { data: l } = ok(await admin.from('ff_lojas').select('id, nome, dono').eq('id', p.loja_id).maybeSingle(), 'loja');
  if (!l) return { enviado: false, motivo: 'loja' };
  const tipo = p.tipo_entrega === 'retirada' ? 'Retirada' : p.tipo_entrega === 'envio' ? 'Envio' : 'Entrega';
  const r = await mandarPush(admin, await pessoasDaLoja(admin, l), {
    titulo: `Novo pedido #${p.numero} · ${brl(p.total)}`,
    corpo: `${p.cliente_nome} · ${tipo} · ${PAG[p.pagamento] || p.pagamento}${l.nome ? ' — ' + l.nome : ''}`,
    url: SITE + 'painel.html?loja=' + l.id, tag: 'pedido-' + p.id
  }, rede);
  return { enviado: r.enviados > 0, ...r };
}

// Motoboys (SQL v31): 'pronto' = loja aceitou um pedido de entrega; 'coletado' = um motoboy saiu com ele; 'entregue'
export async function pushMoto(admin, id, evento, rede = fetch) {
  if (!/^[0-9a-f-]{36}$/i.test(String(id || ''))) throw new Falha('pedido_invalido');
  const st = { pronto: 'preparando', coletado: 'saiu', entregue: 'entregue' }[evento];
  if (!st) throw new Falha('tipo_invalido');
  // marca primeiro (uma vez por evento)
  const { data: p0 } = ok(await admin.from('ff_pedidos').select('id, pushes, status').eq('id', id).maybeSingle(), 'pedido');
  if (!p0 || p0.status !== st || (p0.pushes || {})[evento]) return { enviado: false, motivo: 'ja_enviado_ou_situacao' };
  const { data: p } = ok(await admin.from('ff_pedidos').update({ pushes: { ...(p0.pushes || {}), [evento]: new Date().toISOString() } })
    .eq('id', id).eq('status', st).is('pushes->>' + evento, null).select('*').maybeSingle(), 'pedido');
  if (!p || p.tipo_entrega !== 'entrega') return { enviado: false, motivo: 'ja_enviado_ou_situacao' };
  const { data: l } = ok(await admin.from('ff_lojas').select('id, nome, dono').eq('id', p.loja_id).maybeSingle(), 'loja');
  if (!l) return { enviado: false, motivo: 'loja' };
  // motoboys do turno atual (o código que está valendo agora)
  const { data: ac } = await admin.from('ff_entregador_acesso').select('codigo, expira').eq('loja_id', l.id).maybeSingle();
  let motos = [];
  if (ac && new Date(ac.expira) > new Date()) {
    const { data } = ok(await admin.from('ff_push_moto').select('id, endpoint, p256dh, auth, ent_id').eq('loja_id', l.id).eq('codigo', ac.codigo), 'motoboys');
    motos = data || [];
  }
  const ent = p.entregador_nome || 'o entregador';
  const urlMoto = SITE + 'entregador.html';
  const cobrar = p.pagamento === 'pix' || p.pagamento === 'mp' ? 'já pago' : p.pagamento === 'dinheiro' ? 'cobrar em dinheiro' : 'levar maquininha';
  let r1 = { aparelhos: 0, enviados: 0 }, r2 = { aparelhos: 0, enviados: 0 };
  if (evento === 'pronto') {
    r1 = await mandarParaAparelhos(admin, motos, {
      titulo: `Nova entrega para retirar · #${p.numero}`,
      corpo: `${p.endereco}${p.distancia_km ? ' · ' + String(Number(p.distancia_km).toFixed(1)).replace('.', ',') + ' km' : ''} · ${brl(p.total)} (${cobrar})`,
      url: urlMoto, tag: 'moto-' + p.id
    }, rede, 'ff_push_moto');
  } else if (evento === 'coletado') {
    r1 = await mandarParaAparelhos(admin, motos.filter(m => !p.entregador_id || m.ent_id !== p.entregador_id), {
      titulo: `Pedido #${p.numero} coletado por ${ent}`,
      corpo: `Não precisa ir buscar: ${ent} já saiu com ele. ${p.endereco}`,
      url: urlMoto, tag: 'moto-' + p.id
    }, rede, 'ff_push_moto');
    r2 = await mandarPush(admin, await pessoasDaLoja(admin, l), {
      titulo: `🛵 ${ent} saiu com o pedido #${p.numero}`,
      corpo: `${p.cliente_nome} · ${p.endereco}${l.nome ? ' — ' + l.nome : ''}`,
      url: SITE + 'painel.html?loja=' + l.id, tag: 'pedido-' + p.id
    }, rede);
  } else {
    r2 = await mandarPush(admin, await pessoasDaLoja(admin, l), {
      titulo: `✅ Pedido #${p.numero} entregue por ${ent}`,
      corpo: `${p.cliente_nome} · ${brl(p.total)}${l.nome ? ' — ' + l.nome : ''}`,
      url: SITE + 'painel.html?loja=' + l.id, tag: 'pedido-' + p.id
    }, rede);
  }
  return { enviado: r1.enviados + r2.enviados > 0, motoboys: r1, loja: r2 };
}

export async function pushAgenda(admin, id, rede = fetch) {
  if (!/^[0-9a-f-]{36}$/i.test(String(id || ''))) throw new Falha('agendamento_invalido');
  const { data: a } = ok(await admin.from('ff_agendamentos').update({ push_em: new Date().toISOString() })
    .eq('id', id).is('push_em', null).eq('status', 'agendado').eq('origem', 'site').select('*').maybeSingle(), 'agendamento');
  if (!a) return { enviado: false, motivo: 'ja_enviado_ou_situacao' };
  const { data: l } = ok(await admin.from('ff_lojas').select('id, nome, dono').eq('id', a.loja_id).maybeSingle(), 'loja');
  if (!l) return { enviado: false, motivo: 'loja' };
  const q = quando(a.inicio);
  const r = await mandarPush(admin, await pessoasDaLoja(admin, l), {
    titulo: `Novo horário: ${q.dia.toLowerCase()} às ${q.hora}`,
    corpo: `${a.cliente_nome} · ${a.servico_nome} com ${a.profissional_nome}${l.nome ? ' — ' + l.nome : ''}`,
    url: SITE + 'painel.html?loja=' + l.id, tag: 'agenda-' + a.id
  }, rede);
  return { enviado: r.enviados > 0, ...r };
}

// ---------- Boas-vindas (SQL v40) ----------
const passo = (n, titulo, texto) => `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin:0 0 12px"><tr>
  <td width="34" valign="top"><div style="width:26px;height:26px;border-radius:9px;background:#FFEDE6;color:${COR};font-weight:800;font-size:14px;line-height:26px;text-align:center">${n}</div></td>
  <td valign="top" style="font-size:14px;line-height:1.55;color:#4a4a55"><b style="color:#16161B">${titulo}</b><br>${texto}</td></tr></table>`;
const caixaAviso = (html) => `<div style="margin:6px 0 12px;padding:14px 16px;border-radius:14px;background:#FFF4DC;border:1px solid #F3DFAE;font-size:14px;line-height:1.55;color:#5c4510">${html}</div>`;
const primeiroNome = (u) => {
  const md = (u && u.user_metadata) || {};
  const n = String(md.nome || md.full_name || md.name || '').trim().split(/\s+/)[0];
  return n && n.length <= 30 ? n : '';
};

export function montarBoasVindas(tipo, nome, l) {
  const oi = nome ? `Oi, ${h(nome)}!` : 'Oi!';
  if (tipo === 'lojista') {
    const linkLoja = l && l.slug ? SITE + 'loja.html?l=' + encodeURIComponent(l.slug) : SITE;
    const nomeLoja = (l && l.nome) || 'sua loja';
    const html = moldura({
      previa: `${nomeLoja} já está no ar. Veja os primeiros passos para começar a vender.`,
      titulo: `Bem-vindo ao GoPedido! ${nomeLoja} está criada`,
      texto: `${oi} Sua loja já tem <a href="${h(linkLoja)}" style="color:${COR};font-weight:700">endereço próprio na internet</a>. Em poucos minutos ela fica pronta para receber pedidos. Veja os primeiros passos:`,
      corpo: passo(1, 'Cadastre seus produtos', 'Nome, foto, preço e opções (tamanhos, adicionais, venda por quilo).')
        + passo(2, 'Conecte o Mercado Pago', 'Pix e cartão caem direto na sua conta. A conexão é direta: o GoPedido não vê sua senha nem os dados de cartão.')
        + passo(3, 'Configure a entrega', 'Taxa por distância com seus motoboys, retirada no balcão ou envio para todo o Brasil com frete calculado.')
        + passo(4, 'Divulgue o link', 'Coloque o link da loja no WhatsApp, no Instagram e no Google.')
        + `<p style="margin:14px 0 0;font-size:14px;line-height:1.6;color:#4a4a55"><b style="color:#16161B">Quando quiser, ligue também:</b> caixa no balcão com leitor de código de barras, mesas e garçom pelo celular e o financeiro com o lucro do dia. Fica em <b>Minha loja → Caixa e mesas</b>.</p>`
        + `<p style="margin:10px 0 0;font-size:14px;line-height:1.6;color:#4a4a55"><b style="color:#16161B">Motoboys:</b> eles entram na área do entregador com a conta deles e o código da loja, que aparece no seu painel.</p>`
        + `<p style="margin:14px 0 0;font-size:13px;color:#7a7a85">Quer ver tudo funcionando? <a href="${SITE}lojistas.html#video" style="color:${COR};font-weight:700">Assista ao vídeo de 1 minuto</a>.</p>`,
      botao: { texto: 'Abrir meu painel', url: SITE + 'painel.html' + (l && l.id ? '?loja=' + l.id : '') },
      botao2: { texto: 'Ver minha loja', url: linkLoja },
      aviso: 'Você recebeu este e-mail porque criou uma loja no GoPedido.'
    });
    return { assunto: `Bem-vindo ao GoPedido: ${nomeLoja} está criada`, html };
  }
  if (tipo === 'motoboy') {
    const html = moldura({
      previa: 'Como pegar e entregar pedidos pela área do entregador do GoPedido.',
      titulo: 'Bem-vindo à área do entregador',
      texto: `${oi} Agora você faz entregas pelo GoPedido. Veja como funciona:`,
      corpo: caixaAviso(`<b>Importante:</b> para ver e coletar os pedidos, você precisa <b>entrar na sua conta</b> na área do entregador (a mesma conta Google que você usou agora). Só abrir o link não basta: sem entrar, nenhuma entrega aparece.`)
        + passo(1, 'Entre com o código da loja', 'A loja te passa um código. Ele troca a cada 8 horas: quando vencer, peça o novo para a loja.')
        + passo(2, 'Ligue os avisos', 'Permita as notificações para o celular tocar quando tiver entrega nova. Dica: adicione a página à tela inicial.')
        + passo(3, 'Retire e entregue', 'Marque quando sair com o pedido e quando entregar. Endereço, mapa e o valor a cobrar aparecem no pedido.')
        + `<p style="margin:10px 0 0;font-size:13px;color:#7a7a85">Dúvidas sobre as entregas, pagamento ou horários são combinadas direto com a loja.</p>`,
      botao: { texto: 'Abrir a área do entregador', url: SITE + 'entregador.html' },
      aviso: 'Você recebeu este e-mail porque entrou na área do entregador do GoPedido.<br>O GoPedido é a plataforma; as entregas são combinadas com cada loja.'
    });
    return { assunto: 'Bem-vindo à área do entregador do GoPedido', html };
  }
  const html = moldura({
    previa: 'Sua conta está pronta. Peça nas lojas da sua cidade e acompanhe tudo pelo celular.',
    titulo: 'Bem-vindo ao GoPedido!',
    texto: `${oi} Sua conta está pronta. Com ela fica mais fácil pedir:`,
    corpo: passo(1, 'Endereços salvos', 'Cadastre uma vez e peça com poucos toques.')
      + passo(2, 'Acompanhe seus pedidos', 'Veja cada etapa, do preparo até a entrega.')
      + passo(3, 'Pague como preferir', 'Pix ou cartão. No pagamento online, os dados do cartão vão direto para o Mercado Pago.')
      + `<p style="margin:14px 0 0;font-size:13px;color:#7a7a85">Tem uma loja? <a href="${SITE}lojistas.html" style="color:${COR};font-weight:700">Venda pelo GoPedido sem comissão por pedido</a>.</p>`,
    botao: { texto: 'Ver as lojas', url: SITE },
    botao2: { texto: 'Minha conta', url: SITE + 'conta.html' },
    aviso: 'Você recebeu este e-mail porque criou uma conta no GoPedido.'
  });
  return { assunto: 'Bem-vindo ao GoPedido!', html };
}

export async function boasVindas(admin, enviar, id) {
  if (!/^[0-9a-f-]{36}$/i.test(String(id || ''))) throw new Falha('boasvindas_invalido');
  const { data: b } = ok(await admin.from('ff_boasvindas').update({ enviado_em: new Date().toISOString() })
    .eq('id', id).is('enviado_em', null).select('*').maybeSingle(), 'boasvindas');
  if (!b) return { enviado: false, motivo: 'ja_enviado' };
  let u = null;
  try { const r = await admin.auth.admin.getUserById(b.usuario); u = r && r.data && r.data.user; } catch (_) {}
  if (!u || !u.email) return { enviado: false, motivo: 'sem_email' };
  let l = null;
  if (b.tipo === 'lojista' && b.loja_id) {
    const { data } = ok(await admin.from('ff_lojas').select('id, nome, slug').eq('id', b.loja_id).maybeSingle(), 'loja');
    l = data;
  }
  const { assunto, html } = montarBoasVindas(b.tipo, primeiroNome(u), l);
  try {
    await enviar({ para: u.email, assunto, html, texto: textoSimples(html) });
  } catch (e) {
    await admin.from('ff_boasvindas').update({ enviado_em: null }).eq('id', b.id);
    throw new Falha('email_falhou', 502, String(e && e.message || e).slice(0, 300));
  }
  return { enviado: true };
}

export async function tratar(req, admin, enviar, rede = fetch) {
  if (req.method === 'OPTIONS') return { status: 200, corpo: 'ok' };
  if (req.method !== 'POST') throw new Falha('metodo_invalido', 405);
  const b = (await req.json().catch(() => ({}))) || {};

  if (b.acao === 'lembretes') return { status: 200, corpo: await lembretes(admin, enviar) };

  // Avisos no celular do lojista
  if (b.acao === 'push_chave') return { status: 200, corpo: { chave: (await chavesVapid(admin)).publica } };
  if (b.acao === 'push_pedido') return { status: 200, corpo: await pushPedido(admin, b.id, rede) };
  if (b.acao === 'push_agenda') return { status: 200, corpo: await pushAgenda(admin, b.id, rede) };
  if (b.acao === 'push_moto') return { status: 200, corpo: await pushMoto(admin, b.id, String(b.evento || ''), rede) };
  // Assinaturas e códigos digitais (SQL v33)
  if (b.acao === 'assin_pago') return { status: 200, corpo: await assinPago(admin, enviar, b.id) };
  if (b.acao === 'assin_convite') return { status: 200, corpo: await assinConvite(admin, enviar, b.id, 'convite') };
  if (b.acao === 'assin_link') return { status: 200, corpo: await assinConvite(admin, enviar, b.id, 'link') };
  if (b.acao === 'boas_vindas') return { status: 200, corpo: await boasVindas(admin, enviar, b.id) };
  if (b.acao === 'codigos_pedido') return { status: 200, corpo: await codigosPedido(admin, enviar, b.id, rede) };
  if (b.acao === 'push_teste') {
    const jwt = String(req.headers.get('authorization') || '').replace(/^Bearer\s+/i, '');
    const { data: u } = jwt ? await admin.auth.getUser(jwt) : { data: null };
    if (!u || !u.user) throw new Falha('sem_login', 401);
    const r = await mandarPush(admin, [u.user.id], {
      titulo: 'Avisos ligados ✅', corpo: 'É assim que vai chegar cada pedido novo, mesmo com o celular bloqueado.',
      url: SITE + 'painel.html', tag: 'teste'
    }, rede);
    return { status: 200, corpo: r };
  }

  // E-mails de agendamento: { agendamento: token, tipo: 'ag_novo' | 'ag_remarcado' | 'ag_cancelado' }
  if (b.agendamento !== undefined) {
    if (!/^[a-z0-9]{16,40}$/i.test(String(b.agendamento || ''))) throw new Falha('agendamento_invalido');
    const tipo = String(b.tipo || '');
    if (!['ag_novo', 'ag_remarcado', 'ag_cancelado'].includes(tipo)) throw new Falha('tipo_invalido');
    const { data: a } = ok(await admin.from('ff_agendamentos').select('*').eq('token', b.agendamento).maybeSingle(), 'agendamento');
    if (!a) throw new Falha('agendamento_invalido', 404);
    const ja = a.emails || {};
    const pula = (motivo) => ({ status: 200, corpo: { enviado: false, motivo } });
    if (!a.cliente_email) return pula('sem_email');
    if (tipo === 'ag_novo' && (ja.ag_novo || a.status !== 'agendado')) return pula(ja.ag_novo ? 'ja_enviado' : 'situacao');
    if (tipo === 'ag_cancelado' && (ja.ag_cancelado || a.status !== 'cancelado')) return pula(ja.ag_cancelado ? 'ja_enviado' : 'situacao');
    // remarcado: só se a última mudança é depois do último aviso, e o horário ainda vai acontecer
    if (tipo === 'ag_remarcado' && (a.status !== 'agendado' || new Date(a.inicio) < new Date()
        || (ja.ag_remarcado && new Date(a.atualizado_em) <= new Date(ja.ag_remarcado)))) return pula('situacao');
    await enviarAgenda(admin, enviar, a, tipo);
    return { status: 200, corpo: { enviado: true } };
  }

  if (!/^[a-z0-9]{8,40}$/i.test(String(b.token || ''))) throw new Falha('pedido_invalido');

  // Link do PDF da nota: quem tem o token do pedido é o cliente (mesma regra da página de acompanhamento)
  if (b.acao === 'nf_link') {
    const { data: p } = ok(await admin.from('ff_pedidos').select('nf_path').eq('token', b.token).maybeSingle(), 'pedido');
    if (!p || !p.nf_path) throw new Falha('sem_nota', 404);
    const r = await admin.storage.from('ff-notas').createSignedUrl(p.nf_path, 600, { download: 'nota-fiscal.pdf' });
    if (r.error || !r.data) throw new Falha('sem_nota', 404, r.error && r.error.message || '');
    return { status: 200, corpo: { url: r.data.signedUrl } };
  }

  const tipo = String(b.tipo || '');
  if (!['novo', 'postado', 'cancelado', 'nota'].includes(tipo)) throw new Falha('tipo_invalido');

  const { data: p } = ok(await admin.from('ff_pedidos').select('*').eq('token', b.token).maybeSingle(), 'pedido');
  if (!p) throw new Falha('pedido_invalido', 404);
  const ja = p.emails || {};
  const pula = (motivo) => ({ status: 200, corpo: { enviado: false, motivo } });
  if (!p.cliente_email) return pula('sem_email');
  // A nota pode ser trocada pela loja: manda de novo se mudou desde o último envio
  if (ja[tipo] && !(tipo === 'nota' && p.nf_em && new Date(p.nf_em) > new Date(ja[tipo]))) return pula('ja_enviado');
  // Só manda se a situação do pedido bate com o tipo do e-mail
  if (tipo === 'novo' && p.status === 'cancelado') return pula('situacao');
  if (tipo === 'novo' && p.pagamento === 'mp' && p.mp_status !== 'aprovado') return pula('aguardando_pagamento');
  if (tipo === 'nota' && !(p.nf_path || p.nf_chave)) return pula('situacao');
  if (tipo === 'postado' && !(p.tipo_entrega === 'envio' && p.etiqueta_status === 'gerada' && p.rastreio && p.status !== 'cancelado')) return pula('situacao');
  if (tipo === 'cancelado' && p.status !== 'cancelado') return pula('situacao');

  const { data: l } = ok(await admin.from('ff_lojas').select('nome, telefone, endereco, dono').eq('id', p.loja_id).maybeSingle(), 'loja');
  const { data: itens } = ok(await admin.from('ff_pedido_itens').select('nome, preco, qtd').eq('pedido_id', p.id), 'itens');
  const { assunto, html } = montarEmail(tipo, p, l || { nome: 'Loja' }, itens || []);
  const texto = textoSimples(html);
  // Quem responder o e-mail fala com a loja (e-mail de acesso do dono)
  let responder = '';
  try { const { data: u } = await admin.auth.admin.getUserById(l && l.dono); responder = (u && u.user && u.user.email) || ''; } catch (_) {}

  // Marca antes de enviar, para dois cliques ao mesmo tempo não mandarem dois e-mails
  ok(await admin.from('ff_pedidos').update({ emails: { ...ja, [tipo]: new Date().toISOString() } }).eq('id', p.id), 'marcar');
  try {
    await enviar({ para: p.cliente_email, assunto, html, texto, loja: (l && l.nome) || '', responder });
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
      const enviar = ({ para, assunto, html, texto, loja, responder }) => transporte.sendMail({
        ...(responder ? { replyTo: responder } : {}),
        from: `"${loja ? loja.replace(/["<>]/g, '') + ' via ' + nome : nome}" <${USER}>`,
        to: para, subject: assunto, html, text: texto,
        headers: { 'X-Entity-Ref-ID': 'gopedido-' + Date.now() }  // evita o Gmail agrupar e-mails de pedidos diferentes
      });
      const r = await tratar(req, admin, enviar);
      return resp(r.status, r.corpo);
    } catch (e) {
      return resp(e instanceof Falha ? e.status : 500, { error: e instanceof Falha ? e.message : 'erro_interno', detalhe: e instanceof Falha ? e.detalhe : String(e && e.message || e) });
    }
  });
}
