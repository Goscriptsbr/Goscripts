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
    $('fin-pdv').innerHTML = `<div class="fin-pdv-h"><div class="fic">${ic('cash')}</div><div class="grow" style="min-width:0"><b>Caixa no balcão</b>
        <div class="small muted">Opcional. Para vender no balcão com leitor de código de barras, desconto, troco e recibo. As vendas entram aqui no Financeiro.</div></div></div>
      <div style="margin-top:12px"><label class="switch"><input type="checkbox" id="fin-on" ${on ? 'checked' : ''}><i></i>Vender no balcão</label></div>
      <div class="${on ? '' : 'hide'}" style="margin-top:8px"><label class="switch"><input type="checkbox" id="fin-gav" ${gav ? 'checked' : ''}><i></i>Controlar a gaveta (abrir e fechar o caixa conferindo o dinheiro)</label></div>
      <p class="small muted ${on ? '' : 'hide'}" style="margin:8px 0 0">Na equipe (Minha loja → Equipe), escolha a função <b>Caixa</b> para quem só deve usar o caixa, sem mexer na loja.</p>
      ${on ? `<a class="btn btn-primary" style="margin-top:12px" href="caixa.html?loja=${loja.id}">${ic('cash')}Abrir a tela do caixa</a>` : ''}`;
    const salvar = async () => {
      const a = $('fin-on').checked, g = a && $('fin-gav').checked;
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
      ['Balcão (caixa)', d.balcao.total, `${d.balcao.qtd} venda${d.balcao.qtd == 1 ? '' : 's'}${d.balcao_cancelados ? ' · ' + d.balcao_cancelados + ' cancelada' + (d.balcao_cancelados > 1 ? 's' : '') : ''}`]];
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
      <div class="row" style="justify-content:flex-end;margin-top:12px"><button class="btn btn-ghost btn-sm" id="fin-csv">${ic('download')}Baixar planilha (CSV)</button></div>`;
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
    abrir(cliente, l, c) { sb = cliente; loja = l; ctx = c || {}; ligar(); renderPdv(); carregar(); },
    mostrar() { if (sb && loja) { renderPdv(); carregar(); } }
  };
})();
