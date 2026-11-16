// GoPedido — Financeiro (caixa virtual) do painel: quanto entrou e saiu por período,
// juntando delivery/online, balcão (caixa), assinaturas e lançamentos (despesas e receitas avulsas).
// Também liga/desliga o caixa no balcão (PDV). Tudo é opcional. Precisa do SQL v35.
(function () {
  const { $, esc, brl, ic } = GP;
  let sb = null, loja = null, ctx = {}, dados = null, per = 'mes', de = '', ate = '';
  const FORMA = { dinheiro: 'Dinheiro', pix: 'Pix', credito: 'Crédito', debito: 'Débito', mp: 'Online (Mercado Pago)', outro: 'Outro' };
  const CATS = ['Fornecedor', 'Aluguel', 'Funcionários', 'Energia e água', 'Internet e telefone', 'Embalagens', 'Entregadores', 'Marketing', 'Impostos e taxas', 'Manutenção', 'Outros'];
  const r2 = (v) => Math.round((Number(v) || 0) * 100) / 100;
  const num = (v) => { const n = parseFloat(String(v || '').replace(/\./g, '').replace(',', '.')); return isNaN(n) ? 0 : r2(n); };
  const moeda = (el) => { const d = el.value.replace(/\D/g, '').replace(/^0+/, '').slice(0, 10); el.value = d ? GP.fmtMoeda(Number(d) / 100) : ''; };
  const dBR = (d) => String(d || '').slice(0, 10).split('-').reverse().join('/');
  const hoje = () => GP.dataSP();
  const somaDias = (d, n) => { const x = new Date(d + 'T12:00:00Z'); x.setUTCDate(x.getUTCDate() + n); return x.toISOString().slice(0, 10); };
  const erroMsg = (e) => /ff_financeiro|ff_pdv|ff_lancar|function .* does not exist|schema cache/i.test((e && e.message) || '') ? 'Falta rodar o SQL v35 no Supabase.' : GP.err(e);

  function periodo(p) {
    const h = hoje(), [y, m] = h.split('-').map(Number);
    if (p === 'hoje') return [h, h];
    if (p === 'ontem') return [somaDias(h, -1), somaDias(h, -1)];
    if (p === '7') return [somaDias(h, -6), h];
    if (p === '30') return [somaDias(h, -29), h];
    if (p === 'mes') return [`${y}-${String(m).padStart(2, '0')}-01`, h];
    if (p === 'mesp') { const pm = m === 1 ? 12 : m - 1, py = m === 1 ? y - 1 : y; const fim = new Date(Date.UTC(py, pm, 0)).toISOString().slice(0, 10); return [`${py}-${String(pm).padStart(2, '0')}-01`, fim]; }
    return [de || h, ate || h];
  }

  function janela(titulo, corpo, rodape) {
    fechar();
    const w = document.createElement('div');
    w.className = 'sheet modal on'; w.id = 'fin-mod'; w.setAttribute('role', 'dialog'); w.setAttribute('aria-modal', 'true');
    w.innerHTML = `<div class="sheet-head"><h3>${esc(titulo)}</h3><button class="icon-btn" type="button" data-x>${ic('x')}</button></div>
      <div class="sheet-body">${corpo}</div>${rodape ? `<div class="sheet-foot">${rodape}</div>` : ''}`;
    document.body.appendChild(w); $('ov').classList.add('on');
    w.querySelector('[data-x]').onclick = fechar;
    return w;
  }
  function fechar() { const w = $('fin-mod'); if (w) { w.remove(); $('ov').classList.remove('on'); } }
  document.addEventListener('click', (e) => { if (e.target && e.target.id === 'ov' && $('fin-mod')) fechar(); });

  // ---------- Caixa no balcão (liga/desliga) ----------
  function renderPdv() {
    const on = !!loja.pdv_ativo, gav = !!loja.pdv_gaveta;
    $('fin-pdv').innerHTML = `<div class="fin-pdv-h"><div class="fic">${ic('cash')}</div><div class="grow" style="min-width:0"><b>Caixa no balcão (venda presencial)</b>
        <div class="small muted">Opcional. Para quem também vende no balcão: leitor de código de barras, desconto, troco e recibo. As vendas entram no Financeiro junto com o delivery.</div></div></div>
      <div style="margin-top:12px"><label class="switch"><input type="checkbox" id="fin-on" ${on ? 'checked' : ''}><i></i>Usar o caixa no balcão</label></div>
      <div class="${on ? '' : 'hide'}" style="margin-top:8px"><label class="switch"><input type="checkbox" id="fin-gav" ${gav ? 'checked' : ''}><i></i>Tenho caixa físico (gaveta de dinheiro): abrir e fechar o caixa conferindo o dinheiro</label></div>
      <p class="small muted ${on ? '' : 'hide'}" style="margin:8px 0 0">Na equipe (Minha loja → Equipe), escolha a função <b>Caixa</b> para quem só deve usar o caixa, sem mexer na loja.</p>
      ${on ? `<a class="btn btn-primary" style="margin-top:12px" href="caixa.html?loja=${loja.id}">${ic('cash')}Abrir a tela do caixa</a>` : ''}`;
    const salvar = async () => {
      const a = $('fin-on').checked, g = a && $('fin-gav').checked;
      if (!a && loja.mesas_ativo) { GP.toast('Desligue as mesas antes: as contas das mesas fecham no caixa.', 'err'); return renderPdv(); }
      try {
        const { data, error } = await sb.rpc('ff_pdv_config', { p_loja: loja.id, p_ativo: a, p_gaveta: g });
        if (error) throw error;
        loja.pdv_ativo = data.pdv_ativo; loja.pdv_gaveta = data.pdv_gaveta;
        if (ctx.aoMudar) ctx.aoMudar(loja);
        GP.toast(a ? (g ? 'Caixa ligado, com controle da gaveta.' : 'Caixa ligado.') : 'Caixa desligado.', 'ok');
      } catch (e) { GP.toast(erroMsg(e), 'err'); }
      renderPdv();
    };
    $('fin-on').onchange = salvar; $('fin-gav').onchange = salvar;
  }

  // ---------- Mesas ----------
  let mesas = null, configurando = false;
  async function renderMesas() {
    const box = $('fin-mesas'); if (!box) return;
    if (mesas === null) {
      const { data, error } = await sb.from('ff_mesas').select('id, nome, ordem').eq('loja_id', loja.id).eq('ativa', true).order('ordem');
      if (error) { box.innerHTML = /ff_mesas|relation|schema/i.test(error.message || '') ? '<div class="small muted">Mesas: falta rodar o SQL v36 no Supabase.</div>' : ''; return; }
      mesas = data || [];
    }
    const on = !!loja.mesas_ativo || configurando;
    box.innerHTML = `<div class="fin-pdv-h"><div class="fic">${ic('users')}</div><div class="grow" style="min-width:0"><b>Mesas (restaurante, bar, lanchonete)</b>
        <div class="small muted">Opcional. O garçom abre a mesa e lança os pedidos pelo celular; a conta da mesa aparece em <b>Contas abertas</b> no caixa.</div></div></div>
      <div style="margin-top:12px"><label class="switch"><input type="checkbox" id="ms-on" ${on ? 'checked' : ''}><i></i>Usar mesas</label></div>
      <div class="${on ? '' : 'hide'}" id="ms-cfg">
        <div class="grid2" style="margin-top:12px">
          <label class="field" style="margin:0"><span>Taxa de serviço (%)</span><input class="input" id="ms-tx" inputmode="decimal" value="${String(Number(loja.taxa_servico || 0)).replace('.', ',')}" placeholder="0 = sem taxa"><small>O caixa pode tirar na hora, se o cliente pedir.</small></label>
          <label class="field" style="margin:0"><span>Criar mesas numeradas</span><div class="row" style="gap:6px"><input class="input" id="ms-n" inputmode="numeric" placeholder="Ex.: 12"><button type="button" class="btn btn-ghost" id="ms-gerar">Criar</button></div></label>
        </div>
        <div class="field" style="margin-top:12px"><span>Mesas (${mesas.length})</span>
          <div id="ms-lista" class="ms-lista">${mesas.map((m, i) => `<div class="ms-li"><input class="input" data-i="${i}" maxlength="30" value="${esc(m.nome)}"><button type="button" class="icon-btn" data-x="${i}" title="Tirar">${ic('x')}</button></div>`).join('')}</div>
          <button type="button" class="btn btn-ghost btn-sm" id="ms-add" style="margin-top:6px">${ic('plus')}Mesa</button></div>
        <div class="row" style="gap:8px;flex-wrap:wrap;margin-top:6px"><button type="button" class="btn btn-primary" id="ms-salvar">Salvar mesas</button>
          <a class="btn btn-ghost" href="garcom.html?loja=${loja.id}">${ic('list')}Abrir a tela do garçom</a></div>
        <p class="small muted" style="margin:10px 0 0">Na equipe, escolha a função <b>Garçom</b> para quem só lança pedidos nas mesas (cada um com o próprio login).</p>
      </div>`;
    const ler = () => { box.querySelectorAll('#ms-lista input').forEach(el => { mesas[+el.dataset.i].nome = el.value; }); };
    $('ms-on').onchange = async (e) => {
      if (e.target.checked) { configurando = true; if (!mesas.length) mesas = Array.from({ length: 10 }, (_, i) => ({ nome: 'Mesa ' + (i + 1) })); renderMesas(); GP.toast('Confira as mesas e toque em "Salvar mesas".'); return; }
      if (!loja.mesas_ativo) { configurando = false; return renderMesas(); }
      try {
        const { data, error } = await sb.rpc('ff_mesas_config', { p_loja: loja.id, p_ativo: false, p_taxa: Number(loja.taxa_servico || 0), p_mesas: null });
        if (error) throw error;
        loja.mesas_ativo = false; configurando = false; if (ctx.aoMudar) ctx.aoMudar(loja); GP.toast('Mesas desligadas.', 'ok');
      } catch (er) { e.target.checked = true; GP.toast(erroMsg(er), 'err'); }
      renderMesas();
    };
    $('ms-gerar').onclick = () => {
      ler(); const n = parseInt($('ms-n').value, 10);
      if (!(n >= 1 && n <= 200)) return GP.toast('Digite de 1 a 200 mesas.', 'err');
      const ja = new Set(mesas.map(m => m.nome.trim().toLowerCase()));
      for (let i = 1; i <= n; i++) { const nm = 'Mesa ' + i; if (!ja.has(nm.toLowerCase())) mesas.push({ nome: nm }); }
      renderMesas();
    };
    $('ms-add').onclick = () => { ler(); mesas.push({ nome: 'Mesa ' + (mesas.length + 1) }); renderMesas().then(() => { const ins = box.querySelectorAll('#ms-lista input'); if (ins.length) ins[ins.length - 1].select(); }); };
    box.querySelector('#ms-lista').onclick = (e) => { const b = e.target.closest('[data-x]'); if (!b) return; ler(); mesas.splice(+b.dataset.x, 1); renderMesas(); };
    $('ms-salvar').onclick = async (e) => {
      ler();
      const lista = mesas.map(m => ({ id: m.id || null, nome: m.nome.trim() })).filter(m => m.nome);
      const nomes = lista.map(m => m.nome.toLowerCase());
      if (new Set(nomes).size !== nomes.length) return GP.toast('Tem mesas com o mesmo nome.', 'err');
      if (!lista.length) return GP.toast('Cadastre pelo menos uma mesa.', 'err');
      const tx = num($('ms-tx').value);
      if (tx < 0 || tx > 30) return GP.toast('A taxa de serviço vai de 0 a 30%.', 'err');
      const b = e.currentTarget; b.disabled = true;
      try {
        const { data, error } = await sb.rpc('ff_mesas_config', { p_loja: loja.id, p_ativo: true, p_taxa: tx, p_mesas: lista });
        if (error) throw error;
        configurando = false; loja.mesas_ativo = true; loja.taxa_servico = data.taxa_servico; loja.pdv_ativo = data.pdv_ativo; mesas = data.mesas;
        if (ctx.aoMudar) ctx.aoMudar(loja);
        GP.toast(`Mesas salvas (${mesas.length}).`, 'ok'); renderPdv();
      } catch (er) { GP.toast(erroMsg(er), 'err'); }
      b.disabled = false; renderMesas();
    };
  }

  function dica() {
    const el = $('fin-dica'); if (!el) return;
    el.innerHTML = loja.pdv_ativo ? `<div class="row" style="gap:8px;flex-wrap:wrap;margin-bottom:12px"><a class="btn btn-primary btn-sm" href="caixa.html?loja=${loja.id}">${ic('cash')}Abrir o caixa</a>${loja.mesas_ativo ? `<a class="btn btn-ghost btn-sm" href="garcom.html?loja=${loja.id}">${ic('users')}Mesas</a>` : ''}</div>`
      : `<p class="small muted" style="margin:0 0 12px">Vende também no balcão ou tem mesas? Ligue em <b>Minha loja → Caixa e mesas</b>.</p>`;
  }

  // ---------- Relatório ----------
  async function carregar() {
    [de, ate] = periodo(per);
    $('fin-dados').innerHTML = '<div class="sk" style="height:180px;border-radius:20px"></div>';
    const { data, error } = await sb.rpc('ff_financeiro', { p_loja: loja.id, p_de: de, p_ate: ate });
    if (error) { $('fin-dados').innerHTML = `<div class="card empty"><h4>Não foi possível carregar</h4><p>${esc(erroMsg(error))}</p></div>`; return; }
    dados = data; render();
  }
  function totais() {
    const d = dados, ass = d.assinaturas ? Number(d.assinaturas.total) : 0;
    const ent = r2(Number(d.delivery.total) + Number(d.balcao.total) + ass + Number(d.receitas));
    return { ent, sai: r2(d.despesas), saldo: r2(ent - Number(d.despesas)), ass };
  }
  function formas() {
    const d = dados, f = {};
    const add = (k, v) => { v = r2(v); if (v) f[k] = r2((f[k] || 0) + v); };
    Object.entries(d.delivery.formas || {}).forEach(([k, v]) => add(k, v));
    Object.entries(d.balcao_formas || {}).forEach(([k, v]) => add(k, v));
    if (Number(d.balcao_troco)) add('dinheiro', -Number(d.balcao_troco));
    return Object.entries(f).sort((a, b) => b[1] - a[1]);
  }
  function render() {
    const d = dados, t = totais();
    const dias = d.por_dia || [];
    const assDia = {}; (d.assinaturas_dia || []).forEach(x => { assDia[x.dia] = Number(x.total); });
    const serie = dias.map(x => ({ dia: x.dia, ent: r2(Number(x.delivery) + Number(x.balcao) + Number(x.receitas) + (assDia[x.dia] || 0)), sai: Number(x.despesas) }));
    const max = Math.max(1, ...serie.map(x => Math.max(x.ent, x.sai)));
    const fs = formas(), fsT = fs.reduce((s, x) => s + x[1], 0) || 1;
    const qtdV = Number(d.delivery.qtd) + Number(d.balcao.qtd);
    const origem = [['Delivery e retirada (site)', d.delivery.total, `${d.delivery.qtd} pedido${d.delivery.qtd == 1 ? '' : 's'} entregue${d.delivery.qtd == 1 ? '' : 's'}${Number(d.delivery.taxas) ? ' · ' + brl(d.delivery.taxas) + ' de taxa de entrega' : ''}`],
      ['Balcão e mesas (caixa)', d.balcao.total, `${d.balcao.qtd} venda${d.balcao.qtd == 1 ? '' : 's'}${d.balcao_cancelados ? ' · ' + d.balcao_cancelados + ' cancelada' + (d.balcao_cancelados > 1 ? 's' : '') : ''}`]];
    if (d.assinaturas) origem.push(['Assinaturas', d.assinaturas.total, `${d.assinaturas.qtd} pagamento${d.assinaturas.qtd == 1 ? '' : 's'}`]);
    origem.push(['Outras receitas (lançadas)', d.receitas, '']);
    $('fin-dados').innerHTML = `
      <div class="fin-kpis">
        <div class="card fk"><span>Entradas</span><b>${brl(t.ent)}</b><small>${qtdV} venda${qtdV === 1 ? '' : 's'}${qtdV ? ' · ticket médio ' + brl((Number(d.delivery.total) + Number(d.balcao.total)) / qtdV) : ''}</small></div>
        <div class="card fk"><span>Saídas (despesas)</span><b style="color:var(--bad)">${brl(t.sai)}</b><small>${(d.despesas_cat || []).length} categoria${(d.despesas_cat || []).length === 1 ? '' : 's'}</small></div>
        <div class="card fk"><span>Saldo do período</span><b style="color:${t.saldo >= 0 ? 'var(--ok)' : 'var(--bad)'}">${brl(t.saldo)}</b><small>${dBR(d.de)}${d.de !== d.ate ? ' a ' + dBR(d.ate) : ''}</small></div>
      </div>
      ${serie.length > 1 ? `<div class="card pad fin-graf"><div class="row between" style="margin-bottom:10px"><b>Por dia</b><span class="small muted"><i class="lg-e"></i>entradas <i class="lg-s"></i>saídas</span></div>
        <div class="bars">${serie.map(x => `<div class="bar" title="${dBR(x.dia)}: entradas ${brl(x.ent)} · saídas ${brl(x.sai)}"><i class="e" style="height:${Math.round(100 * x.ent / max)}%"></i><i class="s" style="height:${Math.round(100 * x.sai / max)}%"></i></div>`).join('')}</div>
        <div class="row between small muted" style="margin-top:6px"><span>${dBR(serie[0].dia)}</span><span>${dBR(serie[serie.length - 1].dia)}</span></div></div>` : ''}
      <div class="fin-2">
        <div class="card pad"><b>De onde veio</b><div class="fin-lst">${origem.map(([n, v, s]) => `<div><span>${esc(n)}${s ? `<small>${esc(s)}</small>` : ''}</span><b>${brl(v)}</b></div>`).join('')}</div></div>
        <div class="card pad"><b>Por forma de pagamento</b>${fs.length ? `<div class="fin-lst">${fs.map(([k, v]) => `<div><span>${esc(FORMA[k] || k)}<i class="fin-pct" style="width:${Math.round(100 * v / fsT)}%"></i></span><b>${brl(v)}</b></div>`).join('')}</div>` : '<p class="small muted">Nada no período.</p>'}
          <p class="small muted" style="margin:8px 0 0">Dinheiro do balcão já sem o troco. Delivery conta os pedidos entregues.</p></div>
      </div>
      <div class="card pad" style="margin-top:12px">
        <div class="row between" style="gap:8px;flex-wrap:wrap"><b>Despesas e receitas lançadas</b><div class="row" style="gap:6px"><button class="btn btn-soft btn-sm" id="fin-desp">${ic('plus')}Despesa</button><button class="btn btn-ghost btn-sm" id="fin-rec">${ic('plus')}Receita</button></div></div>
        ${(d.despesas_cat || []).length ? `<div class="fin-cats">${d.despesas_cat.map(c => `<span>${esc(c.categoria)} <b>${brl(c.total)}</b></span>`).join('')}</div>` : ''}
        ${(d.lancamentos || []).length ? `<div class="fin-lanc">${d.lancamentos.map(l => `<div class="${l.cancelado ? 'canc' : ''}"><span class="dt">${dBR(l.data)}</span>
            <span class="grow" style="min-width:0"><b>${esc(l.descricao)}</b><small>${esc(l.categoria || (l.tipo === 'receita' ? 'Receita' : 'Despesa'))} · ${esc(FORMA[l.forma] || l.forma)} · ${esc(l.usuario_nome)}${l.cancelado ? ' · cancelado' : ''}</small></span>
            <b style="color:${l.tipo === 'despesa' ? 'var(--bad)' : 'var(--ok)'}">${l.tipo === 'despesa' ? '−' : '+'} ${brl(l.valor)}</b>
            ${l.cancelado ? '<span style="width:32px"></span>' : `<button class="icon-btn" data-cl="${l.id}" title="Cancelar lançamento">${ic('x')}</button>`}</div>`).join('')}</div>`
          : '<p class="small muted" style="margin:10px 0 0">Lance aqui as despesas (fornecedor, aluguel, funcionários…) para ver o lucro de verdade.</p>'}
      </div>
      ${(d.caixas || []).length ? `<div class="card pad" style="margin-top:12px"><b>Caixas do período</b><div class="fin-lanc">${d.caixas.map(c => {
          const df = c.diferenca == null ? null : Number(c.diferenca);
          return `<div><span class="dt">nº ${c.numero}</span><span class="grow" style="min-width:0"><b>${c.status === 'aberto' ? 'Aberto agora' : 'Fechado'} · ${brl(c.esperado.vendas_total)} em ${c.esperado.vendas_qtd} venda${c.esperado.vendas_qtd == 1 ? '' : 's'}</b>
            <small>${new Date(c.aberto_em).toLocaleString('pt-BR', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' })} · ${esc(c.aberto_por_nome)}${c.fechado_em ? ' → ' + new Date(c.fechado_em).toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' }) + ' · ' + esc(c.fechado_por_nome) : ''}${c.obs ? ' · ' + esc(c.obs) : ''}</small></span>
            ${df == null ? '' : `<b style="color:${Math.abs(df) < 0.005 ? 'var(--ok)' : df > 0 ? '#1e40af' : 'var(--bad)'}">${Math.abs(df) < 0.005 ? 'bateu' : (df > 0 ? 'sobrou ' : 'faltou ') + brl(Math.abs(df))}</b>`}</div>`;
        }).join('')}</div></div>` : ''}
      <div class="card pad" style="margin-top:12px" id="fin-vendas"></div>
      <div class="row" style="justify-content:flex-end;margin-top:12px"><button class="btn btn-ghost btn-sm" id="fin-csv">${ic('download')}Baixar planilha (CSV)</button></div>`;
    vendas(true);
    $('fin-desp').onclick = () => lancar('despesa');
    $('fin-rec').onclick = () => lancar('receita');
    $('fin-csv').onclick = csv;
    $('fin-dados').querySelectorAll('[data-cl]').forEach(b => { b.onclick = async () => {
      if (!(await GP.confirmar('Cancelar este lançamento?', { texto: 'Ele deixa de contar no saldo, mas fica no histórico como cancelado.', ok: 'Cancelar lançamento', perigo: true }))) return;
      const { error } = await sb.rpc('ff_lanc_cancelar', { p_id: b.dataset.cl });
      if (error) return GP.toast(erroMsg(error), 'err');
      GP.toast('Lançamento cancelado.', 'ok'); carregar();
    }; });
  }
  // ---------- Vendas e recibos (site + caixa) ----------
  let vOrig = 'todas', vBusca = '', vLista = [], vQtd = 0, vValor = 0, vTimer = null;
  const ORIG = { site: ['Site', 'b-ok'], balcao: ['Balcão', 'b-warn'], mesa: ['Conta/mesa', 'b-warn'] };
  const ST = { entregue: 'Entregue', cancelado: 'Cancelado', novo: 'Novo', preparando: 'Preparando', saiu: 'Saiu', concluida: 'Paga', cancelada: 'Cancelada' };
  const hm = (d) => new Date(d).toLocaleString('pt-BR', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit', timeZone: 'America/Sao_Paulo' });
  async function vendas(reset) {
    const box = $('fin-vendas'); if (!box) return;
    if (reset) {
      vLista = [];
      box.innerHTML = `<div class="row between" style="gap:8px;flex-wrap:wrap"><b>Vendas e recibos</b><span class="small muted" id="fv-res"></span></div>
        <div class="cx-chips" id="fv-o" style="margin-top:10px">${[['todas', 'Todas'], ['site', 'Site (delivery e retirada)'], ['balcao', 'Balcão'], ['mesa', 'Contas e mesas']].map(([k, t]) => `<button data-o="${k}" class="${vOrig === k ? 'on' : ''}">${t}</button>`).join('')}</div>
        <input class="input" id="fv-b" placeholder="Buscar por cliente, número ou quem vendeu…" value="${esc(vBusca)}" style="margin-top:8px">
        <div id="fv-l" class="fv-l"><p class="small muted"><span class="spin"></span> Carregando…</p></div>
        <button class="btn btn-ghost btn-block btn-sm hide" id="fv-mais" style="margin-top:8px">Carregar mais</button>`;
      $('fv-o').onclick = (e) => { const b = e.target.closest('[data-o]'); if (!b) return; vOrig = b.dataset.o; vendas(true); };
      $('fv-b').oninput = (e) => { vBusca = e.target.value; clearTimeout(vTimer); vTimer = setTimeout(() => vendas(true).then(() => { const i = $('fv-b'); if (i) { i.focus(); i.setSelectionRange(i.value.length, i.value.length); } }), 400); };
      $('fv-mais').onclick = () => vendas(false);
      $('fv-l').onclick = (e) => { const r = e.target.closest('[data-v]'); if (r) detalhe(r.dataset.o, r.dataset.v); };
    }
    const { data, error } = await sb.rpc('ff_fin_vendas', { p_loja: loja.id, p_de: de, p_ate: ate, p_origem: vOrig, p_busca: vBusca, p_limite: 50, p_offset: vLista.length });
    if (!$('fv-l')) return;
    if (error) { $('fv-l').innerHTML = `<p class="small muted">${/ff_fin_vendas|function|schema cache/i.test(error.message || '') ? 'Para ver o histórico de vendas, falta rodar o SQL v39 no Supabase.' : esc(GP.err(error))}</p>`; return; }
    vQtd = data.qtd; vValor = data.valor; vLista = vLista.concat(data.itens || []);
    $('fv-res').textContent = `${vQtd} venda${vQtd == 1 ? '' : 's'} · ${brl(vValor)} pagos/entregues`;
    $('fv-l').innerHTML = vLista.length ? vLista.map(v => {
      const canc = v.status === 'cancelado' || v.status === 'cancelada';
      return `<button type="button" class="fv-it ${canc ? 'canc' : ''}" data-v="${v.id}" data-o="${v.origem}">
        <span class="dt">${hm(v.quando)}</span>
        <span class="grow" style="min-width:0"><b>nº ${v.numero}${v.cliente ? ' · ' + esc(v.cliente) : ''}</b>
          <small><span class="badge ${ORIG[v.origem][1]}" style="font-size:.66rem;padding:1px 6px">${ORIG[v.origem][0]}</span> ${(v.pagamentos || []).map(p => esc(FORMA[p.forma] || p.forma)).join(' + ')}${v.usuario ? ' · ' + esc(v.usuario) : ''}${v.tem_nf ? ' · NF anexada' : ''}</small></span>
        <span style="text-align:right"><b>${brl(v.total)}</b><small style="display:block;color:${canc ? 'var(--bad)' : 'var(--muted)'}">${ST[v.status] || v.status}</small></span></button>`;
    }).join('') : '<p class="small muted" style="margin:10px 0 0">Nenhuma venda nesse período.</p>';
    $('fv-mais').classList.toggle('hide', vLista.length >= vQtd);
  }
  async function detalhe(origem, id) {
    const w = janela('Venda', '<p class="small muted"><span class="spin"></span> Carregando…</p>');
    const { data: v, error } = await sb.rpc('ff_fin_venda', { p_origem: origem === 'site' ? 'site' : 'caixa', p_id: id });
    if (error) { w.querySelector('.sheet-body').innerHTML = `<div class="warnline">${esc(GP.err(error))}</div>`; return; }
    const canc = v.status === 'cancelado' || v.status === 'cancelada';
    const pags = v.origem === 'site' ? [{ forma: v.pagamento, valor: v.total }] : (v.pagamentos || []);
    w.querySelector('.sheet-head h3').textContent = `${ORIG[v.origem][0]} · venda nº ${v.numero}`;
    w.querySelector('.sheet-body').innerHTML = `
      <p class="small muted" style="margin:0 0 10px">${hm(v.criado_em)}${v.cliente ? ' · ' + esc(v.cliente) : ''}${v.telefone ? ' · ' + esc(v.telefone) : ''}${v.usuario_nome ? ' · vendido por ' + esc(v.usuario_nome) : ''}${v.caixa ? ' · caixa nº ' + v.caixa : ''}${v.obs ? ' · ' + esc(v.obs) : ''}</p>
      ${canc ? `<div class="warnline" style="margin-bottom:10px">Cancelada${v.cancelada_por_nome ? ' por ' + esc(v.cancelada_por_nome) : ''}${v.cancel_motivo ? ': ' + esc(v.cancel_motivo) : ''}</div>` : ''}
      ${v.endereco ? `<p class="small" style="margin:0 0 10px">${v.tipo_entrega === 'retirada' ? 'Retirada na loja' : 'Entrega: ' + esc(v.endereco)}${v.entregador ? ' · motoboy ' + esc(v.entregador) : ''}</p>` : ''}
      <div class="fin-lst">${(v.itens || []).map(i => `<div><span>${i.qtd > 1 ? i.qtd + '× ' : ''}${esc(i.nome)}${(i.opcoes || []).length ? `<small>${esc(i.opcoes.map(o => o.nome).join(', '))}</small>` : ''}${i.obs ? `<small>Obs: ${esc(i.obs)}</small>` : ''}</span><b>${brl(i.preco * i.qtd)}</b></div>`).join('')}</div>
      <div class="fin-lst" style="margin-top:6px;border-top:2px solid var(--line)">
        <div><span>Subtotal</span><b>${brl(v.subtotal)}</b></div>
        ${Number(v.desconto) ? `<div><span>Desconto</span><b>− ${brl(v.desconto)}</b></div>` : ''}
        ${Number(v.taxa_entrega) ? `<div><span>Entrega</span><b>${brl(v.taxa_entrega)}</b></div>` : ''}
        ${Number(v.taxa_servico) ? `<div><span>Taxa de serviço</span><b>${brl(v.taxa_servico)}</b></div>` : ''}
        <div><span><b>Total</b></span><b>${brl(v.total)}</b></div>
        ${pags.map(p => `<div><span>${esc(FORMA[p.forma] || p.forma)}</span><b>${brl(p.valor)}</b></div>`).join('')}
        ${Number(v.troco) ? `<div><span>Troco</span><b>${brl(v.troco)}</b></div>` : ''}${v.troco_para ? `<div><span>Troco para</span><b>${brl(v.troco_para)}</b></div>` : ''}
      </div>
      ${v.observacao ? `<p class="small" style="margin:10px 0 0">Obs. do cliente: ${esc(v.observacao)}</p>` : ''}`;
    const pode = v.origem !== 'site' && !canc && v.caixa_status !== 'fechado';
    w.insertAdjacentHTML('beforeend', `<div class="sheet-foot"><div class="row" style="gap:8px;flex-wrap:wrap">
      <button class="btn btn-primary" id="fv-imp">${ic('print')}Imprimir recibo</button>
      ${v.origem === 'site' && v.token ? `<a class="btn btn-ghost" target="_blank" rel="noopener" href="pedido.html?t=${encodeURIComponent(v.token)}">${ic('ext')}Ver pedido</a>` : ''}
      ${pode ? `<button class="btn btn-ghost" id="fv-canc" style="color:var(--bad)">Cancelar venda</button>` : ''}</div></div>`);
    $('fv-imp').onclick = () => recibo(v, pags);
    const cn = $('fv-canc'); if (cn) cn.onclick = () => {
      w.querySelector('.sheet-foot').innerHTML = `<label class="field" style="margin:0 0 8px"><span>Motivo do cancelamento (o estoque volta)</span><input class="input" id="fv-mot" maxlength="200" placeholder="Ex.: cliente desistiu"></label>
        <div class="row" style="gap:8px"><button class="btn btn-ghost" id="fv-voltar">Voltar</button><button class="btn grow" id="fv-sim" style="background:var(--bad);color:#fff">Cancelar venda</button></div>`;
      setTimeout(() => $('fv-mot').focus(), 50);
      $('fv-voltar').onclick = () => detalhe(origem, id);
      $('fv-sim').onclick = async (e) => {
        const motivo = $('fv-mot').value.trim(); if (motivo.length < 3) return GP.toast('Escreva o motivo.', 'err');
        const bt = e.currentTarget; bt.disabled = true;
        const { error: e2 } = await sb.rpc('ff_venda_cancelar', { p_venda: v.id, p_motivo: motivo });
        if (e2) { bt.disabled = false; return GP.toast(GP.err(e2), 'err'); }
        GP.toast('Venda cancelada. O estoque voltou.', 'ok'); fechar(); carregar();
      };
    };
  }
  function recibo(v, pags) {
    const f = document.createElement('iframe'); f.style.cssText = 'position:fixed;width:0;height:0;border:0;left:-9999px'; document.body.appendChild(f);
    const m = (x) => GP.fmtMoeda(x), d = f.contentWindow.document;
    d.open(); d.write(`<!DOCTYPE html><html><head><meta charset="utf-8"><style>@page{size:80mm auto;margin:3mm}body{font-family:Menlo,Consolas,monospace;font-size:12px;width:74mm;margin:0}
      h1{font-size:15px;text-align:center;margin:0}.c{text-align:center}.r{display:flex;justify-content:space-between;gap:6px}hr{border:0;border-top:1px dashed #000;margin:6px 0}.b{font-weight:700}.s{font-size:11px}</style></head><body>
      <h1>${esc(loja.nome)}</h1>${loja.endereco ? `<div class="c s">${esc(loja.endereco)}</div>` : ''}
      <div class="c s">${hm(v.criado_em)} · ${ORIG[v.origem][0]} · venda nº ${v.numero}</div>${v.cliente ? `<div class="c s">Cliente: ${esc(v.cliente)}</div>` : ''}<hr>
      ${(v.itens || []).map(i => `<div>${esc(i.nome)}</div><div class="r s"><span>${i.qtd} x ${m(i.preco)}</span><span>${m(i.preco * i.qtd)}</span></div>${(i.opcoes || []).length ? `<div class="s">  ${esc(i.opcoes.map(o => o.nome).join(', '))}</div>` : ''}`).join('')}
      <hr><div class="r"><span>Subtotal</span><span>${m(v.subtotal)}</span></div>${Number(v.desconto) ? `<div class="r"><span>Desconto</span><span>-${m(v.desconto)}</span></div>` : ''}
      ${Number(v.taxa_entrega) ? `<div class="r"><span>Entrega</span><span>${m(v.taxa_entrega)}</span></div>` : ''}${Number(v.taxa_servico) ? `<div class="r"><span>Serviço</span><span>${m(v.taxa_servico)}</span></div>` : ''}
      <div class="r b"><span>TOTAL</span><span>${brl(v.total)}</span></div><hr>
      ${pags.map(p => `<div class="r"><span>${esc(FORMA[p.forma] || p.forma)}</span><span>${m(p.valor)}</span></div>`).join('')}${Number(v.troco) ? `<div class="r"><span>Troco</span><span>${m(v.troco)}</span></div>` : ''}
      ${v.status === 'cancelado' || v.status === 'cancelada' ? '<hr><div class="c b">VENDA CANCELADA</div>' : ''}
      <hr><div class="c s b">SEGUNDA VIA · NÃO É DOCUMENTO FISCAL</div><div class="c s">GoPedido</div></body></html>`);
    d.close();
    setTimeout(() => { try { f.contentWindow.focus(); f.contentWindow.print(); } catch (_) {} setTimeout(() => f.remove(), 3000); }, 250);
  }

  function lancar(tipo) {
    const desp = tipo === 'despesa';
    janela(desp ? 'Lançar despesa' : 'Lançar receita', `
      <label class="field"><span>Valor</span><div class="prefix"><i>R$</i><input class="input" id="lc-v" inputmode="numeric" style="font-size:1.2rem;height:52px"></div></label>
      <label class="field"><span>Descrição</span><input class="input" id="lc-d" maxlength="200" placeholder="${desp ? 'Ex.: compra de pão no fornecedor' : 'Ex.: venda de sucata, evento'}"></label>
      <div class="grid2">
        <label class="field"><span>Categoria</span><input class="input" id="lc-c" maxlength="40" list="lc-cats" placeholder="${desp ? 'Ex.: Fornecedor' : 'Ex.: Outros'}"><datalist id="lc-cats">${CATS.map(c => `<option value="${esc(c)}">`).join('')}</datalist></label>
        <label class="field"><span>Data</span><input class="input" id="lc-dt" type="date" value="${hoje()}"></label>
      </div>
      <label class="field"><span>Forma</span><select class="input" id="lc-f">${['dinheiro', 'pix', 'debito', 'credito', 'outro'].map(k => `<option value="${k}">${FORMA[k]}</option>`).join('')}</select></label>
      <p class="small muted" style="margin:0">Lançamentos não mexem na gaveta do caixa. Para tirar dinheiro da gaveta, use "Retirada" na tela do caixa.</p>`,
      `<button class="btn btn-primary btn-block" id="lc-ok">${desp ? 'Lançar despesa' : 'Lançar receita'}</button>`);
    $('lc-v').oninput = (e) => moeda(e.target); setTimeout(() => $('lc-v').focus(), 60);
    $('lc-ok').onclick = async (e) => {
      const v = num($('lc-v').value), ds = $('lc-d').value.trim();
      if (v <= 0) return GP.toast('Digite o valor.', 'err');
      if (ds.length < 2) return GP.toast('Escreva uma descrição.', 'err');
      const b = e.currentTarget; b.disabled = true;
      const { error } = await sb.rpc('ff_lancar', { p_loja: loja.id, p_tipo: tipo, p_valor: v, p_desc: ds, p_categoria: $('lc-c').value.trim(), p_forma: $('lc-f').value, p_data: $('lc-dt').value || hoje() });
      b.disabled = false;
      if (error) return GP.toast(erroMsg(error), 'err');
      GP.toast(desp ? 'Despesa lançada.' : 'Receita lançada.', 'ok'); fechar(); carregar();
    };
  }
  function csv() {
    if (!dados) return;
    const q = (v) => '"' + String(v == null ? '' : v).replace(/"/g, '""') + '"';
    const n = (v) => GP.fmtMoeda(v);
    const L = [['Dia', 'Delivery', 'Balcão', 'Assinaturas', 'Receitas lançadas', 'Despesas', 'Saldo'].map(q).join(';')];
    const assDia = {}; (dados.assinaturas_dia || []).forEach(x => { assDia[x.dia] = Number(x.total); });
    (dados.por_dia || []).forEach(x => { const a = assDia[x.dia] || 0; L.push([dBR(x.dia), n(x.delivery), n(x.balcao), n(a), n(x.receitas), n(x.despesas), n(Number(x.delivery) + Number(x.balcao) + a + Number(x.receitas) - Number(x.despesas))].map(q).join(';')); });
    L.push(''); L.push(['Lançamentos'].map(q).join(';')); L.push(['Data', 'Tipo', 'Descrição', 'Categoria', 'Forma', 'Valor', 'Quem lançou', 'Situação'].map(q).join(';'));
    (dados.lancamentos || []).forEach(l => L.push([dBR(l.data), l.tipo, l.descricao, l.categoria, FORMA[l.forma] || l.forma, n(l.valor), l.usuario_nome, l.cancelado ? 'cancelado' : 'ok'].map(q).join(';')));
    const blob = new Blob(['﻿' + L.join('\r\n')], { type: 'text/csv;charset=utf-8' });
    const a = document.createElement('a'); a.href = URL.createObjectURL(blob); a.download = `financeiro-${loja.slug || 'loja'}-${dados.de}-a-${dados.ate}.csv`; a.click();
    setTimeout(() => URL.revokeObjectURL(a.href), 2000);
  }

  let ligado = false;
  function ligar() {
    if (ligado) return; ligado = true;
    $('fin-per').onclick = (e) => {
      const b = e.target.closest('[data-p]'); if (!b) return;
      per = b.dataset.p;
      $('fin-per').querySelectorAll('[data-p]').forEach(x => x.classList.toggle('on', x === b));
      $('fin-datas').classList.toggle('hide', per !== 'outro');
      if (per === 'outro') { $('fin-de').value = de || hoje(); $('fin-ate').value = ate || hoje(); return; }
      carregar();
    };
    $('fin-ir').onclick = () => {
      de = $('fin-de').value; ate = $('fin-ate').value;
      if (!de || !ate || ate < de) return GP.toast('Escolha as datas (a final depois da inicial).', 'err');
      carregar();
    };
  }
  window.FinPainel = {
    // aba Financeiro: só os números
    abrir(cliente, l, c) { if (!loja || loja.id !== l.id) { mesas = null; configurando = false; } sb = cliente; loja = l; ctx = c || {}; ligar(); dica(); carregar(); },
    // Minha loja → Caixa e mesas: as configurações
    config(cliente, l, c) { if (!loja || loja.id !== l.id) { mesas = null; configurando = false; } sb = cliente; loja = l; ctx = c || {}; renderPdv(); renderMesas(); },
    mostrar() { if (sb && loja) { dica(); carregar(); } }
  };
})();
