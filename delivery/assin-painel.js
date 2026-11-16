// GoPedido — painel das lojas de Assinaturas (planos mensais, clubes, códigos digitais)
// Abas "Assinantes" e "Planos". Usado pelo painel.html quando a loja é do tipo "assinatura".
(function () {
  const { $, esc, brl, ic } = GP;
  let sb = null, loja = null, ctx = {}, planos = [], assin = [], filtro = 'ativos', busca = '', livres = {};
  const PER = [1, 3, 6, 12];
  const nomePer = (m) => m === 12 ? '1 ano' : m + (m > 1 ? ' meses' : ' mês');
  const dataBR = (d) => d ? String(d).slice(0, 10).split('-').reverse().join('/') : '';
  const hoje = () => GP.dataSP();
  const dias = (d) => d ? Math.round((Date.parse(d + 'T12:00:00Z') - Date.parse(hoje() + 'T12:00:00Z')) / 864e5) : null;
  const num = (v) => { const n = parseFloat(String(v || '').replace(/\./g, '').replace(',', '.')); return isNaN(n) ? 0 : n; };
  const moeda = (el) => { const d = el.value.replace(/\D/g, '').replace(/^0+/, '').slice(0, 8); el.value = d ? GP.fmtMoeda(Number(d) / 100) : ''; };
  const linkLoja = () => GP.cfg.siteUrl + 'assinatura.html?l=' + loja.slug;
  const linkAssin = (a) => GP.cfg.siteUrl + 'assinatura.html?t=' + a.token;
  const erroSQL = (e) => /ff_assin|ff_codigos|relation|schema cache/i.test((e && e.message) || '') ? 'Falta rodar o SQL v33 no Supabase.' : GP.err(e);

  function situacao(a) {
    if (a.status === 'cancelado') return ['cancelado', 'Cancelado', 'b-off'];
    if (a.status === 'pendente') return ['pendente', 'Aguardando pagamento', 'b-warn'];
    const d = dias(a.valido_ate);
    if (d < 0) return ['vencido', 'Vencido', 'b-bad'];
    if (d <= 7) return ['vencendo', d === 0 ? 'Vence hoje' : `Vence em ${d} dia${d > 1 ? 's' : ''}`, 'b-warn'];
    return ['ativo', 'Ativo', 'b-ok'];
  }

  // ---------- janela (modal) ----------
  function janela(titulo, corpo, rodape) {
    fechar();
    const w = document.createElement('div');
    w.className = 'sheet modal on'; w.id = 'as-mod'; w.setAttribute('role', 'dialog'); w.setAttribute('aria-modal', 'true');
    w.innerHTML = `<div class="sheet-head"><h3>${esc(titulo)}</h3><button class="icon-btn" type="button" data-x>${ic('x')}</button></div>
      <div class="sheet-body">${corpo}</div>${rodape ? `<div class="sheet-foot">${rodape}</div>` : ''}`;
    document.body.appendChild(w); $('ov').classList.add('on');
    w.querySelector('[data-x]').onclick = fechar;
    return w;
  }
  function fechar() { const w = $('as-mod'); if (w) { w.remove(); $('ov').classList.remove('on'); } }
  document.addEventListener('click', (e) => { if (e.target && e.target.id === 'ov' && $('as-mod')) fechar(); });

  // ================= CARREGAR =================
  async function carregar() {
    const [r1, r2] = await Promise.all([
      sb.from('ff_assin_planos').select('*').eq('loja_id', loja.id).order('ordem').order('criado_em'),
      sb.from('ff_assinantes').select('*').eq('loja_id', loja.id).order('criado_em', { ascending: false }).limit(2000)
    ]);
    if (r1.error || r2.error) {
      const m = erroSQL(r1.error || r2.error);
      $('as-lista').innerHTML = `<div class="card empty"><h4>Não foi possível carregar</h4><p>${esc(m)}</p></div>`;
      $('pl-lista').innerHTML = ''; return false;
    }
    planos = r1.data || []; assin = r2.data || [];
    const comCod = planos.filter(p => p.entrega_codigo).map(p => p.id);
    livres = {};
    if (comCod.length) {
      const { data } = await sb.from('ff_codigos').select('plano_id').in('plano_id', comCod).is('usado_em', null);
      (data || []).forEach(c => { livres[c.plano_id] = (livres[c.plano_id] || 0) + 1; });
    }
    return true;
  }

  // ================= ASSINANTES =================
  function renderUso() {
    const p = ctx.plano && ctx.plano();
    const ativos = assin.filter(a => a.status === 'ativo').length;
    const max = p && p.assinantes_max != null ? p.assinantes_max : null;
    $('as-uso').innerHTML = max == null ? '' : `<div class="card asuso"><div class="grow"><b>${p.assinantes != null ? p.assinantes : ativos} de ${max}</b> assinantes ativos<div class="small muted">Plano ${esc({ gratis: 'Grátis', profissional: 'Profissional', premium: 'Premium' }[p.plano] || p.plano)}${p.extras_assin ? ` · inclui ${p.extras_assin} extras` : ''}</div>
      <div class="bar"><i style="width:${Math.min(100, Math.round(100 * (p.assinantes || ativos) / Math.max(1, max)))}%"></i></div></div>
      ${p.plano === 'premium' && p.sou_dono !== false ? `<button type="button" class="btn btn-soft btn-sm" id="as-extra">${ic('plus')}Assinantes</button>` : p.sou_dono !== false ? `<button type="button" class="btn btn-soft btn-sm" id="as-up">Aumentar limite</button>` : ''}</div>`;
    const ex = $('as-extra'); if (ex) ex.onclick = () => ctx.comprarExtras && ctx.comprarExtras();
    const up = $('as-up'); if (up) up.onclick = () => ctx.verPlanos && ctx.verPlanos();
  }
  function renderAssin() {
    renderUso();
    const cont = { ativos: 0, vencendo: 0, vencidos: 0, pendentes: 0, cancelados: 0 };
    assin.forEach(a => { const s = situacao(a)[0]; if (s === 'ativo' || s === 'vencendo') cont.ativos++; if (s === 'vencendo') cont.vencendo++; if (s === 'vencido') cont.vencidos++; if (s === 'pendente') cont.pendentes++; if (s === 'cancelado') cont.cancelados++; });
    const F = [['ativos', 'Ativos'], ['vencendo', 'Vencendo'], ['vencidos', 'Vencidos'], ['pendentes', 'Aguardando'], ['cancelados', 'Cancelados']];
    $('as-filtro').innerHTML = F.map(([k, t]) => `<button type="button" class="${filtro === k ? 'on' : ''}" data-f="${k}">${t} <span>${cont[k]}</span></button>`).join('');
    const q = busca.trim().toLowerCase();
    const lst = assin.filter(a => {
      const s = situacao(a)[0];
      const ok = filtro === 'ativos' ? (s === 'ativo' || s === 'vencendo') : filtro === 'vencendo' ? s === 'vencendo' : filtro === 'vencidos' ? s === 'vencido' : filtro === 'pendentes' ? s === 'pendente' : s === 'cancelado';
      return ok && (!q || GP.acha(a.nome + ' ' + a.email + ' ' + a.telefone, q));
    }).sort((x, y) => String(x.valido_ate || '9999').localeCompare(String(y.valido_ate || '9999')));
    if (!planos.length) { $('as-lista').innerHTML = `<div class="card empty"><div class="big">${ic('star')}</div><h4>Crie seu primeiro plano</h4><p>Antes de ter assinantes, cadastre o que você vende na aba <b>Planos</b> (nome e preço por período).</p><button type="button" class="btn btn-primary" id="as-irplanos" style="margin-top:12px">Criar plano</button></div>`; $('as-irplanos').onclick = () => window.__goTab('planos'); return; }
    if (!lst.length) { $('as-lista').innerHTML = `<div class="card empty"><div class="big">${ic('users')}</div><h4>${q ? 'Ninguém encontrado' : 'Nenhum assinante aqui'}</h4><p>${filtro === 'ativos' && !q ? 'Divulgue o link da sua página de assinaturas ou cadastre um assinante.' : ''}</p></div>`; return; }
    const pn = (id) => (planos.find(p => p.id === id) || {}).nome || 'Plano';
    $('as-lista').innerHTML = lst.map(a => {
      const [s, txt, cls] = situacao(a);
      return `<div class="card asit" data-a="${a.id}">
        <div class="grow" style="min-width:0"><b>${esc(a.nome)}</b><div class="small muted ellipsis">${esc(a.email)}${a.telefone ? ' · ' + esc(a.telefone) : ''}</div>
          <div class="small" style="margin-top:4px">${esc(pn(a.plano_id))}${a.valido_ate ? ` · ${s === 'vencido' ? 'venceu em' : 'até'} <b>${dataBR(a.valido_ate)}</b>` : ''}</div></div>
        <span class="badge ${cls}"><i class="dot"></i>${txt}</span>
        <button type="button" class="icon-btn" data-menu="${a.id}" aria-label="Ações">${ic('edit')}</button></div>`;
    }).join('');
  }
  function acoesAssin(a) {
    const [s] = situacao(a);
    const w = janela(a.nome, `
      <p class="small muted" style="margin:0 0 12px">${esc(a.email)}${a.telefone ? ' · ' + esc(a.telefone) : ''}</p>
      <div class="asacts">
        ${a.status !== 'cancelado' ? `<button type="button" class="btn btn-primary btn-block" data-ac="pago">${ic('check')}Registrar pagamento recebido</button>` : ''}
        ${a.status !== 'cancelado' ? `<button type="button" class="btn btn-ghost btn-block" data-ac="link">${ic('copy')}Copiar link de pagamento</button>` : ''}
        ${a.status !== 'cancelado' && a.telefone ? `<a class="btn btn-ghost btn-block" target="_blank" rel="noopener" href="${GP.wa(a.telefone, `Olá, ${a.nome.split(' ')[0]}! ${s === 'pendente' ? 'Para ativar' : 'Para renovar'} sua assinatura na ${loja.nome}, é só pagar por este link: ${linkAssin(a)}`)}">${ic('chat')}Mandar o link pelo WhatsApp</a>` : ''}
        <button type="button" class="btn btn-ghost btn-block" data-ac="editar">${ic('edit')}Editar dados</button>
        ${a.status !== 'cancelado' ? `<button type="button" class="btn btn-ghost btn-block" data-ac="cancelar" style="color:var(--bad)">${ic('x')}Cancelar assinatura</button>` : `<button type="button" class="btn btn-ghost btn-block" data-ac="reativar">${ic('refresh')}Reativar (aguardando pagamento)</button>`}
      </div>
      <div id="as-hist" class="ashist"></div>`);
    sb.from('ff_assin_pagamentos').select('*').eq('assinante_id', a.id).order('criado_em', { ascending: false }).limit(8).then(({ data }) => {
      const el = $('as-hist'); if (!el || !(data || []).length) return;
      el.innerHTML = '<b class="small">Pagamentos</b>' + data.map(g => `<div><span>${dataBR(g.criado_em)} · ${nomePer(g.meses)} · ${brl(g.valor)} · ${{ pix: 'Pix', cartao: 'Cartão', manual: 'Registrado' }[g.metodo]}${g.codigo ? ' · código ' + esc(g.codigo) : ''}</span><span class="${GP.statusPag(g)[0]}">${GP.statusPag(g)[1]}</span></div>`).join('');
    });
    w.querySelector('.asacts').onclick = async (e) => {
      const b = e.target.closest('[data-ac]'); if (!b) return;
      const ac = b.dataset.ac;
      if (ac === 'link') return GP.copy(linkAssin(a), 'Link copiado! Mande para o assinante pagar.');
      if (ac === 'pago') return registrarPago(a);
      if (ac === 'editar') return editarAssin(a);
      if (ac === 'cancelar') {
        if (!(await GP.confirmar('Cancelar a assinatura?', { texto: `${a.nome} para de receber os avisos de renovação e libera uma vaga no seu plano. O que já foi pago não é devolvido automaticamente.`, ok: 'Cancelar assinatura', cancelar: 'Voltar', perigo: true }))) return;
        const { error } = await sb.from('ff_assinantes').update({ status: 'cancelado' }).eq('id', a.id);
        if (error) return GP.toast(erroSQL(error), 'err');
        GP.toast('Assinatura cancelada.', 'ok'); fechar(); await recarregar();
      }
      if (ac === 'reativar') {
        const { error } = await sb.from('ff_assinantes').update({ status: 'pendente' }).eq('id', a.id);
        if (error) return GP.toast(/ff_assinantes_unico|duplicate/.test(error.message || '') ? 'Já existe outra assinatura deste e-mail neste plano.' : erroSQL(error), 'err');
        GP.toast('Reativada: agora aguardando o pagamento.', 'ok'); fechar(); await recarregar();
      }
    };
  }
  function registrarPago(a) {
    const pl = planos.find(p => p.id === a.plano_id) || planos[0];
    const ps = PER.filter(m => Number((pl.precos || {})[m]) > 0);
    const w = janela('Registrar pagamento', `
      <p class="small muted" style="margin:0 0 12px">Use quando ${esc(a.nome.split(' ')[0])} pagou por fora (dinheiro, Pix direto, transferência). A assinatura é renovada na hora${pl.entrega_codigo ? ' e um código é enviado por e-mail' : ''}, e o tempo novo soma ao que falta.</p>
      <label class="field"><span>Período</span><select class="input" id="rp-m">${PER.map(m => `<option value="${m}" ${m === ps[0] ? 'selected' : ''}>${nomePer(m)}${pl.precos[m] ? ' · ' + brl(pl.precos[m]) : ''}</option>`).join('')}</select></label>
      <label class="field"><span>Valor recebido</span><div class="prefix"><i>R$</i><input class="input" id="rp-v" inputmode="numeric" value="${pl.precos[ps[0]] ? GP.fmtMoeda(pl.precos[ps[0]]) : ''}"></div></label>`,
      `<button type="button" class="btn btn-primary btn-block" id="rp-ok">${ic('check')}Registrar e renovar</button>`);
    $('rp-v').oninput = (e) => moeda(e.target);
    $('rp-m').onchange = () => { const v = pl.precos[$('rp-m').value]; if (v) $('rp-v').value = GP.fmtMoeda(v); };
    $('rp-ok').onclick = async (e) => {
      const b = e.currentTarget; b.disabled = true; b.innerHTML = '<span class="spin"></span>';
      const { data, error } = await sb.rpc('ff_assin_manual', { p_assinante: a.id, p_meses: Number($('rp-m').value), p_valor: num($('rp-v').value) });
      b.disabled = false; b.innerHTML = ic('check') + 'Registrar e renovar';
      if (error) return GP.toast(/limite_assinantes/.test(error.message || '') ? GP.err(error) + ' Aumente o limite para ativar mais assinantes.' : erroSQL(error), 'err');
      GP.toast(`Renovado até ${dataBR(data && data.valido_ate)}!${data && data.faltou_codigo ? ' Atenção: acabaram os códigos deste plano.' : ''}`, data && data.faltou_codigo ? 'err' : 'ok');
      fechar(); await recarregar();
    };
  }
  function formAssin(a) {
    return `<label class="field"><span>Nome</span><input class="input" id="na-nome" maxlength="80" value="${esc(a ? a.nome : '')}"></label>
      <label class="field"><span>E-mail</span><input class="input" id="na-email" type="email" maxlength="120" value="${esc(a ? a.email : '')}"><small>Por ele vão o link de pagamento e os avisos de vencimento.</small></label>
      <label class="field"><span>WhatsApp <span class="muted">(opcional)</span></span><input class="input" id="na-tel" inputmode="tel" maxlength="16" value="${esc(a ? a.telefone : '')}"></label>
      <label class="field"><span>Plano</span><select class="input" id="na-pl">${planos.filter(p => p.ativo || (a && p.id === a.plano_id)).map(p => `<option value="${p.id}" ${a && a.plano_id === p.id ? 'selected' : ''}>${esc(p.nome)}</option>`).join('')}</select></label>`;
  }
  const lerAssin = () => ({ nome: $('na-nome').value.trim(), email: $('na-email').value.trim().toLowerCase(), telefone: $('na-tel').value.trim(), plano_id: $('na-pl').value });
  const validaAssin = (r) => r.nome.length < 2 ? 'Digite o nome.' : !/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(r.email) ? 'Digite um e-mail válido.' : !r.plano_id ? 'Escolha o plano.' : '';
  function novoAssin() {
    if (!planos.some(p => p.ativo)) return GP.toast('Crie um plano ativo antes de cadastrar assinantes.', 'err');
    const INFO = {
      link: 'Mandamos um e-mail com o link para ele escolher o período e pagar pelo Pix ou cartão.',
      pago: 'Na próxima tela você escolhe o período e o valor recebido. A assinatura começa hoje.',
      antigo: 'Para quem já pagava antes de você usar o sistema. Coloque até quando já está pago: ele entra como ativo, sem cobrança agora, e recebe os avisos de renovação perto dessa data.'
    };
    let modo = 'link';
    janela('Novo assinante', formAssin(null) + `
      <div class="field"><span>Situação</span><div class="seg3" id="na-modo" style="margin-top:4px">
        <button type="button" class="on" data-md="link">Vai pagar</button><button type="button" data-md="pago">Pagou agora</button><button type="button" data-md="antigo">Já era assinante</button></div></div>
      <label class="field hide" id="na-ate-w"><span>Pago até (vencimento)</span><input class="input" type="date" id="na-ate"></label>
      <p class="small muted" id="na-info" style="margin:0">${INFO.link}</p>`,
      `<button type="button" class="btn btn-primary btn-block" id="na-ok">Cadastrar</button>`);
    $('na-modo').onclick = (e) => {
      const b = e.target.closest('[data-md]'); if (!b) return; modo = b.dataset.md;
      $('na-modo').querySelectorAll('[data-md]').forEach(x => x.classList.toggle('on', x === b));
      $('na-ate-w').classList.toggle('hide', modo !== 'antigo'); $('na-info').textContent = INFO[modo];
      if (modo === 'antigo') setTimeout(() => $('na-ate').focus(), 50);
    };
    $('na-ok').onclick = async (e) => {
      const r = lerAssin(), msg = validaAssin(r); if (msg) return GP.toast(msg, 'err');
      const extra = { loja_id: loja.id, origem: modo === 'link' ? 'painel' : 'site' };
      if (modo === 'antigo') {
        const ate = $('na-ate').value;
        if (!ate) return GP.toast('Coloque até quando ele já está pago.', 'err');
        if (ate < hoje()) return GP.toast('Essa data já passou. Use "Vai pagar" para mandar o link de renovação.', 'err');
        Object.assign(extra, { status: 'ativo', valido_ate: ate, obs: 'Cadastrado como assinante antigo (pago até ' + dataBR(ate) + ')' });
      }
      const b = e.currentTarget; b.disabled = true; b.innerHTML = '<span class="spin"></span>';
      const { data, error } = await sb.from('ff_assinantes').insert({ ...r, ...extra }).select().single();
      b.disabled = false; b.textContent = 'Cadastrar';
      if (error) return GP.toast(/ff_assinantes_unico|duplicate/.test(error.message || '') ? 'Esse e-mail já é assinante deste plano.' : /limite_assinantes/.test(error.message || '') ? GP.err(error) + ' Aumente o limite para ativar mais assinantes.' : erroSQL(error), 'err');
      assin.unshift(data);
      if (modo === 'pago') return registrarPago(data);
      if (modo === 'antigo') { GP.toast(`Assinante cadastrado como ativo até ${dataBR(data.valido_ate)}.`, 'ok'); fechar(); filtro = 'ativos'; await recarregar(); return; }
      GP.toast('Assinante cadastrado! O link de pagamento foi para o e-mail dele.', 'ok'); fechar(); filtro = 'pendentes'; renderAssin();
    };
  }
  function editarAssin(a) {
    janela('Editar assinante', formAssin(a) + (a.status === 'ativo' ? `<label class="field"><span>Vale até (vencimento)</span><input class="input" type="date" id="na-ate" value="${esc(a.valido_ate || '')}"><small>Para corrigir a data. Para renovar com pagamento, use "Registrar pagamento recebido".</small></label>` : ''),
      `<button type="button" class="btn btn-primary btn-block" id="na-ok">Salvar</button>`);
    $('na-ok').onclick = async () => {
      const r = lerAssin(), msg = validaAssin(r); if (msg) return GP.toast(msg, 'err');
      const ate = $('na-ate') && $('na-ate').value;
      if ($('na-ate') && !ate) return GP.toast('Coloque a data de vencimento.', 'err');
      if (ate && ate !== a.valido_ate) { r.valido_ate = ate; r.avisos = {}; }
      const { error } = await sb.from('ff_assinantes').update(r).eq('id', a.id);
      if (error) return GP.toast(/ff_assinantes_unico|duplicate/.test(error.message || '') ? 'Esse e-mail já é assinante deste plano.' : erroSQL(error), 'err');
      GP.toast('Dados salvos.', 'ok'); fechar(); await recarregar();
    };
  }

  // ================= PLANOS =================
  function renderPlanos() {
    if (!planos.length) { $('pl-lista').innerHTML = `<div class="card empty"><div class="big">${ic('star')}</div><h4>Nenhum plano ainda</h4><p>Ex.: "Game Pass Ultimate", "Clube do Vinho", "Mensalidade da academia". Você define o preço de 1, 3, 6 ou 12 meses.</p></div>`; return; }
    $('pl-lista').innerHTML = planos.map(p => {
      const ps = PER.filter(m => Number((p.precos || {})[m]) > 0);
      const n = assin.filter(a => a.plano_id === p.id && a.status === 'ativo').length;
      return `<div class="card plit ${p.ativo ? '' : 'off'}" data-p="${p.id}">
        <div class="grow" style="min-width:0"><b>${esc(p.nome)}</b>${p.ativo ? '' : ' <span class="badge b-off">Pausado</span>'}
          <div class="small muted">${ps.map(m => nomePer(m) + ' ' + brl(p.precos[m])).join(' · ')}</div>
          <div class="small" style="margin-top:4px">${n} assinante${n === 1 ? '' : 's'} ativo${n === 1 ? '' : 's'}${p.entrega_codigo ? ` · <b style="color:${(livres[p.id] || 0) < 3 ? 'var(--bad)' : 'var(--ok)'}">${livres[p.id] || 0} código${(livres[p.id] || 0) === 1 ? '' : 's'} disponíve${(livres[p.id] || 0) === 1 ? 'l' : 'is'}</b>` : ''}</div></div>
        <button type="button" class="btn btn-ghost btn-sm" data-ed="${p.id}">${ic('edit')}Editar</button></div>`;
    }).join('');
  }
  function formPlano(p) {
    const pr = (p && p.precos) || {};
    janela(p ? 'Editar plano' : 'Novo plano', `
      <label class="field"><span>Nome do plano</span><input class="input" id="pp-nome" maxlength="80" placeholder="Ex.: Game Pass Ultimate" value="${esc(p ? p.nome : '')}"></label>
      <label class="field"><span>Descrição <span class="muted">(opcional)</span></span><textarea class="input" id="pp-desc" maxlength="600" placeholder="O que o assinante recebe, como funciona…">${esc(p ? p.descricao : '')}</textarea></label>
      <div class="field"><span>Preço por período <span class="muted">(deixe em branco o que não quiser vender)</span></span>
        <div class="grid2">${PER.map(m => `<label class="field" style="margin:0"><small style="font-weight:700">${nomePer(m)}</small><div class="prefix"><i>R$</i><input class="input pp-v" data-m="${m}" inputmode="numeric" placeholder="—" value="${pr[m] ? GP.fmtMoeda(pr[m]) : ''}"></div></label>`).join('')}</div></div>
      <label class="switch" style="margin:8px 0"><input type="checkbox" id="pp-ativo" ${!p || p.ativo ? 'checked' : ''}><i></i>Disponível para novos assinantes</label>
      <div class="psec" style="margin-top:6px"><label class="switch"><input type="checkbox" id="pp-cod" ${p && p.entrega_codigo ? 'checked' : ''}><i></i>Entregar um código digital a cada pagamento</label>
        <p class="small muted" style="margin:6px 0 0">Para gift cards, chaves de jogos, códigos de assinatura… A cada pagamento aprovado, o sistema manda um código da sua lista por e-mail, sozinho.</p>
        <div id="pp-cods"></div></div>
      ${p ? `<button type="button" class="btn btn-ghost btn-sm" id="pp-del" style="color:var(--bad);margin-top:12px">${ic('trash')}Excluir plano</button>` : ''}`,
      `<button type="button" class="btn btn-primary btn-block" id="pp-ok">Salvar plano</button>`);
    document.querySelectorAll('.pp-v').forEach(el => { el.oninput = () => moeda(el); });
    const codUI = () => {
      const on = $('pp-cod').checked;
      $('pp-cods').innerHTML = !on ? '' : !p ? '<p class="small" style="margin:8px 0 0">Salve o plano para cadastrar os códigos.</p>' : `<div style="margin-top:10px" id="pp-codbox"><p class="small muted"><span class="spin"></span></p></div>`;
      if (on && p) GP.codigos.abrir(sb, $('pp-codbox'), { loja_id: loja.id, plano_id: p.id, aoMudar: (n) => { livres[p.id] = n; renderPlanos(); } });
    };
    $('pp-cod').onchange = codUI; codUI();
    $('pp-ok').onclick = async (e) => {
      const precos = {}; document.querySelectorAll('.pp-v').forEach(el => { const v = num(el.value); if (v > 0) precos[el.dataset.m] = v; });
      const row = { nome: $('pp-nome').value.trim(), descricao: $('pp-desc').value.trim(), precos, ativo: $('pp-ativo').checked, entrega_codigo: $('pp-cod').checked };
      if (!row.nome) return GP.toast('Dê um nome para o plano.', 'err');
      if (!Object.keys(precos).length) return GP.toast('Coloque o preço de pelo menos um período.', 'err');
      const b = e.currentTarget; b.disabled = true;
      const r = p ? await sb.from('ff_assin_planos').update(row).eq('id', p.id).select().single() : await sb.from('ff_assin_planos').insert({ ...row, loja_id: loja.id, ordem: planos.length }).select().single();
      b.disabled = false;
      if (r.error) return GP.toast(erroSQL(r.error), 'err');
      GP.toast('Plano salvo!', 'ok');
      if (!p && row.entrega_codigo) { await recarregar(); return formPlano(r.data); }
      fechar(); await recarregar();
    };
    const del = $('pp-del'); if (del) del.onclick = async () => {
      if (!(await GP.confirmar('Excluir este plano?', { texto: 'Os códigos que sobraram dele também são apagados.', ok: 'Excluir', perigo: true }))) return;
      const { error } = await sb.from('ff_assin_planos').delete().eq('id', p.id);
      if (error) return GP.toast(/foreign|violates|restrict/i.test(error.message || '') ? 'Este plano tem assinantes. Em vez de excluir, desligue "Disponível para novos assinantes".' : erroSQL(error), 'err');
      GP.toast('Plano excluído.', 'ok'); fechar(); await recarregar();
    };
  }

  async function recarregar() { if (await carregar()) { renderAssin(); renderPlanos(); } }
  let ligado = false;
  function ligar() {
    if (ligado) return; ligado = true;
    $('as-novo').innerHTML = ic('plus') + 'Novo assinante'; $('pl-novo').innerHTML = ic('plus') + 'Novo plano';
    $('as-novo').onclick = novoAssin; $('pl-novo').onclick = () => formPlano(null);
    $('as-link').onclick = () => GP.copy(linkLoja(), 'Link da página de assinaturas copiado!');
    $('as-filtro').onclick = (e) => { const b = e.target.closest('[data-f]'); if (b) { filtro = b.dataset.f; renderAssin(); } };
    $('as-busca').oninput = (e) => { busca = e.target.value; renderAssin(); };
    $('as-lista').onclick = (e) => { const c = e.target.closest('[data-a]'); if (c) acoesAssin(assin.find(a => a.id === c.dataset.a)); };
    $('pl-lista').onclick = (e) => { const c = e.target.closest('[data-p]'); if (c) formPlano(planos.find(p => p.id === c.dataset.p)); };
  }

  window.AssinPainel = {
    async abrir(cliente, l, c) { sb = cliente; loja = l; ctx = c || {}; filtro = 'ativos'; busca = ''; ligar(); $('as-busca').value = ''; await recarregar(); },
    mostrar(t) { if (!sb || !loja) return; if (t === 'assin' || t === 'planos') recarregar(); },
    uso() { if (sb && loja) renderUso(); }
  };
})();
