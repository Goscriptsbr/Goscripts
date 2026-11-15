// GoPedido — painel das lojas de Agendamentos (salão, barbearia, manicure…)
// Abas "Agenda" e "Serviços e equipe". Usado pelo painel.html quando a loja é do tipo "agenda".
(function () {
  const { $, esc, brl, ic } = GP;
  let sb = null, loja = null, servs = [], profs = [], ags = [], dia = GP.dataSP(), filtroProf = '', timer = null, conhecidos = null;
  const DIAS = ['Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado'];
  const dur = (m) => m >= 60 ? Math.floor(m / 60) + 'h' + (m % 60 ? String(m % 60).padStart(2, '0') : '') : m + ' min';
  const cap = (t) => t.charAt(0).toUpperCase() + t.slice(1);
  const somaDia = (d, n) => { const x = new Date(d + 'T12:00:00-03:00'); x.setUTCDate(x.getUTCDate() + n); return GP.dataSP(x); };
  const hm = (m) => String(Math.floor(m / 60)).padStart(2, '0') + ':' + String(m % 60).padStart(2, '0');
  const email = (token, tipo) => sb.functions.invoke('ff-email', { body: { agendamento: token, tipo } }).catch(() => {});

  // ---------- janela (modal) simples ----------
  function janela(titulo, corpo, rodape) {
    fecharJanela();
    const w = document.createElement('div');
    w.className = 'sheet modal on'; w.id = 'ag-mod'; w.setAttribute('role', 'dialog'); w.setAttribute('aria-modal', 'true');
    w.innerHTML = `<div class="sheet-head"><h3>${esc(titulo)}</h3><button class="icon-btn" type="button" data-x>${ic('x')}</button></div>
      <div class="sheet-body">${corpo}</div>${rodape ? `<div class="sheet-foot">${rodape}</div>` : ''}`;
    document.body.appendChild(w); $('ov').classList.add('on');
    w.querySelector('[data-x]').onclick = fecharJanela;
    return w;
  }
  function fecharJanela() { const w = $('ag-mod'); if (w) { w.remove(); $('ov').classList.remove('on'); } }
  document.addEventListener('click', (e) => { if (e.target && e.target.id === 'ov' && $('ag-mod')) fecharJanela(); });

  // ================= AGENDA DO DIA =================
  async function carregar() {
    const ini = GP.emSP(dia, 0).toISOString(), fim = GP.emSP(somaDia(dia, 1), 0).toISOString();
    const { data, error } = await sb.from('ff_agendamentos').select('*').eq('loja_id', loja.id).gte('inicio', ini).lt('inicio', fim).order('inicio');
    if (error) { $('ag-lista').innerHTML = `<div class="card empty"><h4>Não foi possível carregar a agenda</h4><p>${esc(/ff_agendamentos/.test(error.message || '') ? 'Falta rodar o SQL v25 no Supabase.' : GP.err(error))}</p></div>`; return; }
    ags = data || [];
    renderAgenda();
  }
  // Novos horários marcados pelo site: avisa com som (confere a cada 20 s)
  async function conferirNovos() {
    if (document.hidden) return;
    const { data } = await sb.from('ff_agendamentos').select('id, cliente_nome, inicio, servico_nome').eq('loja_id', loja.id).eq('origem', 'site')
      .gte('criado_em', new Date(Date.now() - 86400e3).toISOString()).order('criado_em', { ascending: false }).limit(30);
    const ids = (data || []).map(x => x.id);
    if (conhecidos) {
      const novos = (data || []).filter(x => !conhecidos.has(x.id));
      if (novos.length) {
        try { const a = new (window.AudioContext || window.webkitAudioContext)(); const o = a.createOscillator(), g = a.createGain(); o.connect(g); g.connect(a.destination); o.frequency.value = 880; g.gain.value = .15; o.start(); setTimeout(() => { o.frequency.value = 1320; }, 160); setTimeout(() => { o.stop(); a.close(); }, 380); } catch {}
        const n = novos[0];
        GP.toast(`Novo horário: ${n.cliente_nome}, ${GP.diaSP(n.inicio, { day: '2-digit', month: '2-digit' })} às ${GP.horaSP(n.inicio)} (${n.servico_nome})`, 'ok');
        carregar();
      }
    }
    conhecidos = new Set(ids);
  }

  function renderAgenda() {
    const hoje = GP.dataSP();
    const dt = new Date(dia + 'T12:00:00-03:00');
    $('ag-dia').innerHTML = `<b>${dia === hoje ? 'Hoje' : dia === somaDia(hoje, 1) ? 'Amanhã' : dia === somaDia(hoje, -1) ? 'Ontem' : cap(GP.diaSP(dt, { weekday: 'long' }))}</b><span>${GP.diaSP(dt, { day: 'numeric', month: 'long' })}</span>`;
    $('ag-profs').innerHTML = profs.length > 1 ? [['', 'Todos']].concat(profs.map(p => [p.id, p.nome])).map(([id, n]) => `<button type="button" class="chip ${filtroProf === id ? 'on' : ''}" data-fp="${id}">${esc(n)}</button>`).join('') : '';
    const lista = ags.filter(a => !filtroProf || a.profissional_id === filtroProf);
    const ativos = lista.filter(a => a.status !== 'cancelado');
    const previsto = ativos.filter(a => a.status !== 'faltou').reduce((s, a) => s + Number(a.preco || 0), 0);
    $('ag-kpi').innerHTML = `<div><span>Horários</span><b>${ativos.length}</b></div><div><span>Previsto</span><b>${brl(previsto)}</b></div><div><span>Concluídos</span><b>${lista.filter(a => a.status === 'concluido').length}</b></div><div><span>Cancelados</span><b>${lista.filter(a => a.status === 'cancelado').length}</b></div>`;
    if (!servs.length || !profs.length) {
      $('ag-lista').innerHTML = `<div class="card empty"><div class="big">${ic('calendar')}</div><h4>Monte sua agenda</h4><p>Cadastre pelo menos um <b>serviço</b> e um <b>profissional</b> com os horários de atendimento. Depois disso, seus clientes já conseguem marcar.</p><button class="btn btn-primary" style="margin-top:14px" onclick="window.__goTab('servicos')">${ic('plus')}Cadastrar serviços e equipe</button></div>`;
      return;
    }
    if (!lista.length) { $('ag-lista').innerHTML = `<div class="card empty"><div class="big">${ic('calendar')}</div><h4>Nenhum horário marcado</h4><p>Quando um cliente marcar pelo site, aparece aqui na hora.</p></div>`; return; }
    const agora = new Date();
    const ord = lista.slice().sort((a, b) => (a.status === 'cancelado') - (b.status === 'cancelado') || new Date(a.inicio) - new Date(b.inicio));
    $('ag-lista').innerHTML = ord.map(a => {
      const st = { agendado: ['ok', 'Marcado'], concluido: ['fim', 'Concluído'], cancelado: ['no', a.cancelado_por === 'cliente' ? 'Cliente cancelou' : 'Cancelado'], faltou: ['no', 'Faltou'] }[a.status];
      const agoraAqui = a.status === 'agendado' && new Date(a.inicio) <= agora && new Date(a.fim) > agora;
      return `<div class="card agi ${a.status} ${agoraAqui ? 'agora' : ''}">
        <div class="agi-h"><div class="agi-t">${GP.horaSP(a.inicio)}<small>até ${GP.horaSP(a.fim)}</small></div>
          <div class="grow" style="min-width:0"><b>${esc(a.cliente_nome)}</b><div class="small muted">${esc(a.servico_nome)} · ${esc(a.profissional_nome)}${Number(a.preco) ? ' · ' + brl(a.preco) : ''}</div></div>
          <span class="agst ${st[0]}">${agoraAqui ? 'Agora' : st[1]}</span></div>
        ${a.observacao ? `<div class="agi-obs">${ic('chat')}${esc(a.observacao)}</div>` : ''}
        <div class="agi-a">
          ${a.cliente_telefone ? `<a class="btn btn-ghost btn-sm" target="_blank" rel="noopener" href="${GP.wa(a.cliente_telefone, `Olá, ${a.cliente_nome.split(' ')[0]}! Aqui é da ${loja.nome}, sobre o seu horário de ${GP.diaSP(a.inicio, { day: '2-digit', month: '2-digit' })} às ${GP.horaSP(a.inicio)}.`)}">${ic('chat')}WhatsApp</a>` : ''}
          ${a.status === 'agendado' ? `<button class="btn btn-ok btn-sm" data-ac="concluido" data-id="${a.id}">${ic('check')}Concluir</button>
            <button class="btn btn-ghost btn-sm" data-ac="remarcar" data-id="${a.id}">${ic('calendar')}Remarcar</button>
            ${new Date(a.inicio) < agora ? `<button class="btn btn-ghost btn-sm" data-ac="faltou" data-id="${a.id}">Faltou</button>` : ''}
            <button class="btn btn-ghost btn-sm" data-ac="cancelar" data-id="${a.id}" style="color:var(--danger,#c0362c)">Cancelar</button>`
            : a.status !== 'cancelado' ? `<button class="btn btn-ghost btn-sm" data-ac="agendado" data-id="${a.id}">Desfazer</button>` : ''}
        </div></div>`;
    }).join('');
  }

  async function mudar(id, campos, emailTipo) {
    const { data, error } = await sb.from('ff_agendamentos').update(campos).eq('id', id).select().maybeSingle();
    if (error) { GP.toast(/ff_ag_sem_conflito|exclusion|conflict/i.test(error.message || '') ? 'Esse horário já está ocupado com essa pessoa.' : GP.err(error), 'err'); return null; }
    if (data && emailTipo) email(data.token, emailTipo);
    await carregar(); return data;
  }

  async function acao(ac, id) {
    const a = ags.find(x => x.id === id); if (!a) return;
    if (ac === 'concluido') return mudar(id, { status: 'concluido' });
    if (ac === 'faltou') return mudar(id, { status: 'faltou' });
    if (ac === 'agendado') return mudar(id, { status: 'agendado' });
    if (ac === 'cancelar') {
      if (!(await GP.confirmar('Cancelar este horário?', { texto: `${a.cliente_nome} · ${a.servico_nome}, ${GP.horaSP(a.inicio)}. ${a.cliente_email ? 'O cliente recebe um e-mail avisando.' : 'Avise o cliente pelo WhatsApp.'}`, ok: 'Cancelar horário', perigo: true }))) return;
      const r = await mudar(id, { status: 'cancelado', cancelado_por: 'loja' }, 'ag_cancelado');
      if (r) GP.toast('Horário cancelado.', 'ok');
      return;
    }
    if (ac === 'remarcar') return abrirHorario({ remarcar: a });
  }

  // ---------- Marcar / remarcar pela loja ----------
  async function abrirHorario({ remarcar = null } = {}) {
    if (!servs.length || !profs.length) return GP.toast('Cadastre um serviço e um profissional primeiro.', 'err');
    const sAtivos = servs.filter(s => s.ativo);
    let sv = remarcar ? (servs.find(s => s.id === remarcar.servico_id) || { id: remarcar.servico_id, nome: remarcar.servico_nome, duracao_min: remarcar.duracao_min }) : sAtivos[0];
    let pid = remarcar ? remarcar.profissional_id : '', d = remarcar ? GP.dataSP(new Date(remarcar.inicio)) : dia, sel = null, livre = true;
    const w = janela(remarcar ? 'Remarcar horário' : 'Marcar horário', `
      ${remarcar ? `<div class="agres"><b>${esc(remarcar.cliente_nome)}</b><span>${esc(remarcar.servico_nome)} · agora: ${GP.diaSP(remarcar.inicio, { day: '2-digit', month: '2-digit' })} às ${GP.horaSP(remarcar.inicio)}</span></div>`
        : `<label class="field"><span>Serviço</span><select class="input" id="mh-s">${sAtivos.map(s => `<option value="${s.id}">${esc(s.nome)} · ${dur(s.duracao_min)}${Number(s.preco) ? ' · ' + brl(s.preco) : ''}</option>`).join('')}</select></label>`}
      <div class="grid2">
        <label class="field"><span>Profissional</span><select class="input" id="mh-p"></select></label>
        <label class="field"><span>Dia</span><input class="input" type="date" id="mh-d" value="${d}"></label>
      </div>
      <div class="row between" style="margin:2px 0 8px"><b class="small">Horários livres</b><label class="check small" style="margin:0"><input type="checkbox" id="mh-livre" checked>Só livres</label></div>
      <div class="mh-horas" id="mh-h"></div>
      ${remarcar ? '' : `<div class="fsec" style="margin-top:14px">Cliente</div>
      <div class="grid2"><label class="field"><span>Nome</span><input class="input" id="mh-n" maxlength="80"></label>
        <label class="field"><span>WhatsApp</span><input class="input" id="mh-t" inputmode="tel" maxlength="16" placeholder="(19) 99999-9999"></label></div>
      <label class="field"><span>E-mail <span class="muted">(opcional, para confirmação e lembrete)</span></span><input class="input" id="mh-e" type="email" maxlength="120"></label>
      <label class="field" style="margin-bottom:0"><span>Observação <span class="muted">(opcional)</span></span><input class="input" id="mh-o" maxlength="300"></label>`}`,
      `<button class="btn btn-primary btn-block" id="mh-ok" disabled>${remarcar ? 'Salvar novo horário' : 'Marcar horário'}</button>`);
    if (!remarcar) GP.phoneMask(w.querySelector('#mh-t'));
    const fazem = () => profs.filter(p => p.ativo && (!(p.servicos || []).length || p.servicos.includes(sv.id)));
    const montaProfs = () => {
      const l = fazem(); if (!l.some(p => p.id === pid)) pid = (l[0] || {}).id || '';
      w.querySelector('#mh-p').innerHTML = l.map(p => `<option value="${p.id}" ${p.id === pid ? 'selected' : ''}>${esc(p.nome)}</option>`).join('') || '<option value="">Ninguém faz este serviço</option>';
    };
    let seq = 0;
    const montaHoras = async () => {
      sel = null; w.querySelector('#mh-ok').disabled = true;
      const p = profs.find(x => x.id === pid); const box = w.querySelector('#mh-h');
      if (!p || !d) { box.innerHTML = '<div class="small muted" style="grid-column:1/-1">Escolha o profissional e o dia.</div>'; return; }
      const my = ++seq; box.innerHTML = '<span class="spin"></span>';
      const { data: oc } = await sb.rpc('ff_agenda_ocupado', { p_loja: loja.id, p_de: d, p_dias: 1 });
      if (my !== seq) return;
      const ocup = (oc || []).filter(o => !remarcar || !(o.profissional_id === remarcar.profissional_id && new Date(o.inicio).getTime() === new Date(remarcar.inicio).getTime()));
      const passo = Number(loja.ag_intervalo) || 30;
      let slots = GP.slotsProf(p, d, sv.duracao_min, passo, livre ? ocup : [], null);
      if (!livre) slots = Array.from({ length: Math.floor(((24 * 60) - 6 * 60) / passo) }, (_, i) => 6 * 60 + i * passo).filter(m => m + sv.duracao_min <= 1440).map(m => ({ min: m, ini: GP.emSP(d, m) }));
      if (!slots.length) { box.innerHTML = `<div class="small muted" style="grid-column:1/-1">Sem horários livres para ${esc(p.nome)} neste dia. Desmarque "Só livres" para encaixar fora do expediente.</div>`; return; }
      box.innerHTML = slots.map(s => `<button type="button" class="hr" data-m="${s.min}">${hm(s.min)}</button>`).join('');
      box.onclick = (e) => { const b = e.target.closest('[data-m]'); if (!b) return; sel = GP.emSP(d, Number(b.dataset.m)); box.querySelectorAll('.hr').forEach(x => x.classList.toggle('on', x === b)); w.querySelector('#mh-ok').disabled = false; };
    };
    if (!remarcar) w.querySelector('#mh-s').onchange = (e) => { sv = servs.find(s => s.id === e.target.value); montaProfs(); montaHoras(); };
    w.querySelector('#mh-p').onchange = (e) => { pid = e.target.value; montaHoras(); };
    w.querySelector('#mh-d').onchange = (e) => { d = e.target.value; montaHoras(); };
    w.querySelector('#mh-livre').onchange = (e) => { livre = e.target.checked; montaHoras(); };
    montaProfs(); montaHoras();
    w.querySelector('#mh-ok').onclick = async (e) => {
      if (!sel) return;
      const b = e.currentTarget; b.disabled = true; b.innerHTML = '<span class="spin"></span>Salvando…';
      if (remarcar) {
        const r = await mudar(remarcar.id, { inicio: sel.toISOString(), profissional_id: pid }, 'ag_remarcado');
        if (r) { fecharJanela(); GP.toast('Horário remarcado.' + (r.cliente_email ? ' O cliente recebe um e-mail.' : ''), 'ok'); }
        else { b.disabled = false; b.textContent = 'Salvar novo horário'; }
        return;
      }
      const nome = w.querySelector('#mh-n').value.trim();
      if (nome.length < 2) { b.disabled = false; b.textContent = 'Marcar horário'; return GP.toast('Digite o nome do cliente.', 'err'); }
      const cliente = { nome, telefone: w.querySelector('#mh-t').value.trim(), email: w.querySelector('#mh-e').value.trim(), obs: w.querySelector('#mh-o').value.trim(), painel: true };
      const { data, error } = await sb.rpc('ff_agendar', { p_loja: loja.id, p_servico: sv.id, p_profissional: pid, p_inicio: sel.toISOString(), p_cliente: cliente });
      if (error) { b.disabled = false; b.textContent = 'Marcar horário'; return GP.toast(GP.err(error), 'err'); }
      if (cliente.email) email(data.token, 'ag_novo');
      fecharJanela(); GP.toast('Horário marcado.', 'ok');
      dia = d; carregar();
    };
  }

  // ================= SERVIÇOS E EQUIPE =================
  function renderServicos() {
    // configurações
    $('ag-cfg').innerHTML = `
      <div class="grid2">
        <label class="field"><span>Mostrar horários de</span><select class="input" id="cf-int">${[10, 15, 20, 30, 45, 60].map(v => `<option value="${v}" ${Number(loja.ag_intervalo) === v ? 'selected' : ''}>${v} em ${v} minutos</option>`).join('')}</select></label>
        <label class="field"><span>Antecedência mínima</span><select class="input" id="cf-ant">${[[0, 'Sem mínimo'], [30, '30 minutos'], [60, '1 hora'], [120, '2 horas'], [180, '3 horas'], [360, '6 horas'], [720, '12 horas'], [1440, '1 dia']].map(([v, t]) => `<option value="${v}" ${Number(loja.ag_antecedencia) === v ? 'selected' : ''}>${t}</option>`).join('')}</select></label>
        <label class="field"><span>Agenda aberta para os próximos</span><select class="input" id="cf-dias">${[7, 14, 21, 30, 60, 90].map(v => `<option value="${v}" ${Number(loja.ag_dias) === v ? 'selected' : ''}>${v} dias</option>`).join('')}</select></label>
        <label class="field"><span>Cliente pode cancelar sozinho até</span><select class="input" id="cf-can">${[[0, 'Até a hora do horário'], [1, '1 hora antes'], [2, '2 horas antes'], [3, '3 horas antes'], [6, '6 horas antes'], [12, '12 horas antes'], [24, '1 dia antes']].map(([v, t]) => `<option value="${v}" ${Number(loja.ag_cancelar_h) === v ? 'selected' : ''}>${t}</option>`).join('')}</select></label>
      </div>
      <button class="btn btn-dark btn-sm" id="cf-save">${ic('check')}Salvar regras</button>`;
    $('cf-save').onclick = async () => {
      const row = { ag_intervalo: +$('cf-int').value, ag_antecedencia: +$('cf-ant').value, ag_dias: +$('cf-dias').value, ag_cancelar_h: +$('cf-can').value };
      const { data, error } = await sb.from('ff_lojas').update(row).eq('id', loja.id).select().single();
      if (error) return GP.toast(GP.err(error), 'err');
      Object.assign(loja, data); GP.toast('Regras da agenda salvas.', 'ok');
    };
    // serviços
    $('sv-lista').innerHTML = servs.length ? servs.map(s => `<div class="svl ${s.ativo ? '' : 'off'}" data-sv="${s.id}">
        <div class="grow" style="min-width:0"><b>${esc(s.nome)}</b><div class="small muted">${dur(s.duracao_min)} · ${Number(s.preco) ? (s.preco_a_partir ? 'a partir de ' : '') + brl(s.preco) : 'a combinar'}${s.ativo ? '' : ' · pausado'}</div></div>
        <button class="btn btn-ghost btn-sm" type="button">Editar</button></div>`).join('')
      : '<div class="small muted" style="padding:6px 2px">Nenhum serviço ainda. Ex.: Corte masculino, 30 min, R$ 40.</div>';
    // profissionais
    $('pf-lista').innerHTML = profs.length ? profs.map(p => {
      const dias = DIAS.map((n, i) => { const h = (p.horarios || {})[i]; return h && h.aberto ? n.slice(0, 3) : null; }).filter(Boolean);
      const qs = (p.servicos || []).length ? p.servicos.map(id => (servs.find(s => s.id === id) || {}).nome).filter(Boolean).join(', ') : 'Todos os serviços';
      return `<div class="svl ${p.ativo ? '' : 'off'}" data-pf="${p.id}"><span class="pfav">${esc(p.nome.trim()[0].toUpperCase())}</span>
        <div class="grow" style="min-width:0"><b>${esc(p.nome)}</b><div class="small muted">${dias.length ? dias.join(', ') : 'Sem horários'} · ${esc(qs)}${p.ativo ? '' : ' · não está atendendo'}</div></div>
        <button class="btn btn-ghost btn-sm" type="button">Editar</button></div>`;
    }).join('') : '<div class="small muted" style="padding:6px 2px">Cadastre quem atende (pode ser só você). Cada pessoa tem os próprios horários.</div>';
  }

  function editarServico(s) {
    const novo = !s; s = s || { nome: '', descricao: '', preco: 0, duracao_min: 30, ativo: true, preco_a_partir: false };
    const w = janela(novo ? 'Novo serviço' : 'Editar serviço', `
      <label class="field"><span>Nome do serviço</span><input class="input" id="es-n" maxlength="80" value="${esc(s.nome)}" placeholder="Ex.: Corte masculino"></label>
      <div class="grid2">
        <label class="field"><span>Duração</span><select class="input" id="es-d">${[10, 15, 20, 30, 40, 45, 50, 60, 75, 90, 120, 150, 180, 240].concat([s.duracao_min]).filter((v, i, a) => a.indexOf(v) === i).sort((a, b) => a - b).map(v => `<option value="${v}" ${v === s.duracao_min ? 'selected' : ''}>${dur(v)}</option>`).join('')}</select></label>
        <label class="field"><span>Preço</span><div class="prefix"><i>R$</i><input class="input" id="es-p" inputmode="numeric" value="${Number(s.preco) ? Number(s.preco).toFixed(2).replace('.', ',') : ''}" placeholder="0,00"></div></label>
      </div>
      <label class="check" style="margin:-4px 0 12px"><input type="checkbox" id="es-a" ${s.preco_a_partir ? 'checked' : ''}>Mostrar como "a partir de"</label>
      <label class="field"><span>Descrição <span class="muted">(opcional)</span></span><input class="input" id="es-ds" maxlength="300" value="${esc(s.descricao)}" placeholder="Ex.: inclui lavagem"></label>
      <label class="switch"><input type="checkbox" id="es-on" ${s.ativo ? 'checked' : ''}><i></i>Disponível para agendar</label>`,
      `${novo ? '' : `<button class="btn btn-ghost" id="es-del" style="color:var(--danger,#c0362c)">Excluir</button>`}<button class="btn btn-primary btn-block" id="es-ok">Salvar serviço</button>`);
    GP.moneyMask && GP.moneyMask(w.querySelector('#es-p'));
    w.querySelector('#es-ok').onclick = async () => {
      const nome = w.querySelector('#es-n').value.trim(); if (nome.length < 2) return GP.toast('Digite o nome do serviço.', 'err');
      const preco = Number(String(w.querySelector('#es-p').value || '0').replace(/\./g, '').replace(',', '.')) || 0;
      const row = { loja_id: loja.id, nome, descricao: w.querySelector('#es-ds').value.trim(), preco, duracao_min: +w.querySelector('#es-d').value, preco_a_partir: w.querySelector('#es-a').checked, ativo: w.querySelector('#es-on').checked };
      const q = novo ? sb.from('ff_servicos').insert({ ...row, ordem: servs.length }) : sb.from('ff_servicos').update(row).eq('id', s.id);
      const { error } = await q; if (error) return GP.toast(GP.err(error), 'err');
      fecharJanela(); GP.toast('Serviço salvo.', 'ok'); await carregarCadastros();
    };
    if (!novo) w.querySelector('#es-del').onclick = async () => {
      if (!(await GP.confirmar('Excluir este serviço?', { texto: 'Os horários já marcados continuam na agenda. Se quiser só parar de oferecer, desligue "Disponível para agendar".', ok: 'Excluir', perigo: true }))) return;
      const { error } = await sb.from('ff_servicos').delete().eq('id', s.id); if (error) return GP.toast(GP.err(error), 'err');
      fecharJanela(); await carregarCadastros();
    };
  }

  function editarProf(p) {
    const novo = !p;
    const padrao = {}; for (let i = 0; i < 7; i++) padrao[i] = { aberto: i >= 1 && i <= 6, ini: '09:00', fim: i === 6 ? '14:00' : '18:00', pausa_ini: '', pausa_fim: '' };
    p = p || { nome: '', horarios: padrao, servicos: [], ativo: true };
    const H = (i) => ({ aberto: false, ini: '09:00', fim: '18:00', pausa_ini: '', pausa_fim: '', ...((p.horarios || {})[i] || {}) });
    const w = janela(novo ? 'Novo profissional' : 'Editar profissional', `
      <label class="field"><span>Nome</span><input class="input" id="ep-n" maxlength="60" value="${esc(p.nome)}" placeholder="Ex.: João"></label>
      <div class="fsec">Horários de atendimento</div>
      <div class="ep-hs">${DIAS.map((n, i) => { const h = H(i); return `<div class="ep-h ${h.aberto ? '' : 'off'}" data-d="${i}">
          <label class="ep-dia"><input type="checkbox" class="ep-on" ${h.aberto ? 'checked' : ''}><b>${n}</b></label>
          <div class="ep-t"><input class="input ep-i" type="time" value="${h.ini}"><span>às</span><input class="input ep-f" type="time" value="${h.fim}"></div>
          <div class="ep-t ep-pausa"><span class="small muted">Pausa</span><input class="input ep-pi" type="time" value="${h.pausa_ini || ''}"><span>às</span><input class="input ep-pf" type="time" value="${h.pausa_fim || ''}"></div>
        </div>`; }).join('')}</div>
      <button type="button" class="btn btn-ghost btn-sm" id="ep-copia" style="margin:6px 0 14px">${ic('copy')}Copiar o horário de segunda para todos os dias marcados</button>
      <div class="fsec">Serviços que faz</div>
      <p class="small muted" style="margin:-4px 0 8px">Deixe tudo desmarcado se a pessoa faz todos.</p>
      <div class="ep-sv">${servs.map(s => `<label class="check"><input type="checkbox" value="${s.id}" ${(p.servicos || []).includes(s.id) ? 'checked' : ''}>${esc(s.nome)}</label>`).join('') || '<span class="small muted">Cadastre os serviços primeiro.</span>'}</div>
      <label class="switch" style="margin-top:12px"><input type="checkbox" id="ep-on" ${p.ativo ? 'checked' : ''}><i></i>Está atendendo (aparece para os clientes)</label>`,
      `${novo ? '' : `<button class="btn btn-ghost" id="ep-del" style="color:var(--danger,#c0362c)">Excluir</button>`}<button class="btn btn-primary btn-block" id="ep-ok">Salvar</button>`);
    w.querySelectorAll('.ep-on').forEach(c => c.onchange = () => c.closest('.ep-h').classList.toggle('off', !c.checked));
    w.querySelector('#ep-copia').onclick = () => {
      const seg = w.querySelector('.ep-h[data-d="1"]');
      w.querySelectorAll('.ep-h').forEach(r => { if (r === seg || !r.querySelector('.ep-on').checked) return; ['.ep-i', '.ep-f', '.ep-pi', '.ep-pf'].forEach(k => r.querySelector(k).value = seg.querySelector(k).value); });
      GP.toast('Horário copiado.', 'ok');
    };
    w.querySelector('#ep-ok').onclick = async () => {
      const nome = w.querySelector('#ep-n').value.trim(); if (nome.length < 2) return GP.toast('Digite o nome.', 'err');
      const horarios = {}; let erro = '';
      w.querySelectorAll('.ep-h').forEach(r => {
        const i = r.dataset.d, on = r.querySelector('.ep-on').checked, ini = r.querySelector('.ep-i').value, fim = r.querySelector('.ep-f').value, pi = r.querySelector('.ep-pi').value, pf = r.querySelector('.ep-pf').value;
        if (on && (!ini || !fim || (GP.minDe(fim) || 1440) <= GP.minDe(ini))) erro = `Confira o horário de ${DIAS[i]}: o fim precisa ser depois do início.`;
        if (on && pi && pf && GP.minDe(pf) <= GP.minDe(pi)) erro = `Confira a pausa de ${DIAS[i]}.`;
        horarios[i] = { aberto: on, ini, fim, pausa_ini: pi && pf ? pi : '', pausa_fim: pi && pf ? pf : '' };
      });
      if (erro) return GP.toast(erro, 'err');
      const row = { loja_id: loja.id, nome, horarios, servicos: [...w.querySelectorAll('.ep-sv input:checked')].map(x => x.value), ativo: w.querySelector('#ep-on').checked };
      const q = novo ? sb.from('ff_profissionais').insert({ ...row, ordem: profs.length }) : sb.from('ff_profissionais').update(row).eq('id', p.id);
      const { error } = await q; if (error) return GP.toast(GP.err(error), 'err');
      fecharJanela(); GP.toast('Profissional salvo.', 'ok'); await carregarCadastros();
    };
    if (!novo) w.querySelector('#ep-del').onclick = async () => {
      if (!(await GP.confirmar('Excluir este profissional?', { ok: 'Excluir', perigo: true }))) return;
      const { error } = await sb.from('ff_profissionais').delete().eq('id', p.id);
      if (error) return GP.toast(/foreign key|violates/i.test(error.message || '') ? 'Essa pessoa tem horários na agenda. Desligue "Está atendendo" em vez de excluir.' : GP.err(error), 'err');
      fecharJanela(); await carregarCadastros();
    };
  }

  async function carregarCadastros() {
    const [{ data: s, error: e1 }, { data: p }] = await Promise.all([
      sb.from('ff_servicos').select('*').eq('loja_id', loja.id).order('ordem').order('nome'),
      sb.from('ff_profissionais').select('*').eq('loja_id', loja.id).order('ordem').order('nome')
    ]);
    if (e1 && /ff_servicos/.test(e1.message || '')) { $('sv-lista').innerHTML = '<div class="warnline">Falta rodar o SQL v25 no Supabase para ligar os agendamentos.</div>'; return; }
    servs = s || []; profs = p || [];
    renderServicos(); renderAgenda();
  }

  // ---------- ligar ----------
  let ligado = false;
  function ligarEventos() {
    if (ligado) return; ligado = true;
    $('ag-prev').innerHTML = ic('left'); $('ag-next').innerHTML = ic('right');
    $('ag-prev').onclick = () => { dia = somaDia(dia, -1); carregar(); };
    $('ag-next').onclick = () => { dia = somaDia(dia, 1); carregar(); };
    $('ag-hoje').onclick = () => { dia = GP.dataSP(); carregar(); };
    $('ag-cal').onchange = (e) => { if (e.target.value) { dia = e.target.value; carregar(); } };
    $('ag-novo').innerHTML = ic('plus') + 'Marcar horário'; $('ag-novo').onclick = () => abrirHorario();
    $('ag-profs').onclick = (e) => { const b = e.target.closest('[data-fp]'); if (!b) return; filtroProf = b.dataset.fp; renderAgenda(); };
    $('ag-lista').onclick = (e) => { const b = e.target.closest('[data-ac]'); if (b) acao(b.dataset.ac, b.dataset.id); };
    $('sv-novo').innerHTML = ic('plus') + 'Serviço'; $('sv-novo').onclick = () => editarServico(null);
    $('pf-novo').innerHTML = ic('plus') + 'Profissional'; $('pf-novo').onclick = () => editarProf(null);
    $('sv-lista').onclick = (e) => { const r = e.target.closest('[data-sv]'); if (r) editarServico(servs.find(s => s.id === r.dataset.sv)); };
    $('pf-lista').onclick = (e) => { const r = e.target.closest('[data-pf]'); if (r) editarProf(profs.find(p => p.id === r.dataset.pf)); };
    $('ag-link').onclick = () => { const u = location.href.replace(/painel\.html.*$/, 'agenda.html?l=' + encodeURIComponent(loja.slug)); navigator.clipboard && navigator.clipboard.writeText(u); GP.toast('Link da agenda copiado: ' + u, 'ok'); };
  }

  window.AgendaPainel = {
    async abrir(cliente, l) {
      sb = cliente; loja = l; dia = GP.dataSP(); filtroProf = ''; conhecidos = null;
      ligarEventos();
      $('ag-cal').value = dia;
      await carregarCadastros(); await carregar(); conferirNovos();
      clearInterval(timer); timer = setInterval(() => { conferirNovos(); if (!document.hidden && dia === GP.dataSP()) carregar(); }, 20000);
    },
    parar() { clearInterval(timer); timer = null; },
    mostrar(t) { if (!sb || !loja) return; if (t === 'agenda') carregar(); if (t === 'servicos') renderServicos(); }
  };
})();
