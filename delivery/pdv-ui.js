// GoPedido — peças comuns das telas de venda (caixa e garçom)
(function () {
  const { esc, brl } = GP;
  const r2 = (v) => Math.round((Number(v) || 0) * 100) / 100;
  // Peso da balança: "0,350" = 350 g; "350" (sem vírgula, 30 ou mais) também é entendido como gramas
  const gramas = (v) => { const t = String(v || '').trim().replace(/\s/g, ''); if (!t) return 0; if (/^\d+$/.test(t) && Number(t) >= 30) return Number(t); const n = parseFloat(t.replace(/\./g, '').replace(',', '.')); return isNaN(n) ? 0 : Math.round(n * 1000); };
  const fmtG = (g) => g >= 1000 ? (g / 1000).toLocaleString('pt-BR', { maximumFractionDigits: 3 }) + ' kg' : g + ' g';
  GP.pdvGramas = gramas; GP.pdvFmtG = fmtG;
  GP.pdvTemOpcoes = (p) => (p.variacoes || []).length > 0 || (p.grupos || []).some(g => (g.opcoes || []).length) || p.vende_por === 'kg';
  // Escolher variação, adicionais, peso, observação e quantidade. aoConfirmar(linha) recebe a linha pronta.
  GP.pdvOpcoes = ({ p, linha: linhaEdit, janela, aoConfirmar }) => {
    let qtd = linhaEdit ? linhaEdit.qtd : 1, v = linhaEdit ? linhaEdit.v : ((p.variacoes || [])[0] || {}).id || null;
    const sel = new Set((linhaEdit && linhaEdit.sel) || []);
    const kg = p.vende_por === 'kg';
    const grupos = (p.grupos || []).filter(g => (g.opcoes || []).length);
    const corpo = janela(p.nome, `
      ${kg ? `<label class="field"><span>Peso (da balança)</span><div class="row" style="gap:8px"><input class="input" id="op-peso" inputmode="decimal" placeholder="Ex.: 0,350" style="font-size:1.3rem;height:56px;flex:1" value="${linhaEdit && linhaEdit.g ? String(linhaEdit.g / 1000).replace('.', ',') : ''}"><span style="font-weight:800">kg</span></div><small id="op-pv"></small></label>` : ''}
      ${(p.variacoes || []).length ? `<div class="og"><h4>Escolha <small>obrigatório</small></h4>${p.variacoes.map(x => `<label class="oo ${x.id === v ? 'on' : ''}"><input type="radio" name="op-v" value="${esc(x.id)}" ${x.id === v ? 'checked' : ''}><span>${esc(x.nome)}</span><b>${brl(x.preco != null && x.preco !== '' ? x.preco : p.preco)}</b></label>`).join('')}</div>` : ''}
      ${grupos.map(g => `<div class="og" data-g="${esc(g.id)}"><h4>${esc(g.nome)} <small>${g.min ? 'escolha ' + (g.min === g.max ? g.min : 'de ' + g.min + ' a ' + g.max) : 'até ' + (g.max || 99)}</small></h4>
        ${(g.opcoes || []).map(o => `<label class="oo ${sel.has(g.id + ':' + o.id) ? 'on' : ''}"><input type="${g.max === 1 ? 'radio' : 'checkbox'}" name="og-${esc(g.id)}" value="${esc(o.id)}" ${sel.has(g.id + ':' + o.id) ? 'checked' : ''}><span>${esc(o.nome)}</span>${Number(o.preco) ? `<b>+ ${brl(o.preco)}</b>` : ''}</label>`).join('')}</div>`).join('')}
      <label class="field"><span>Observação <span class="muted">(opcional)</span></span><input class="input" id="op-obs" maxlength="200" value="${esc(linhaEdit ? linhaEdit.obs || '' : '')}"></label>
      ${!kg ? `<div class="row between" style="margin-top:6px"><b>Quantidade</b><div class="qstep"><button type="button" id="op-m">−</button><span id="op-q">${qtd}</span><button type="button" id="op-p">+</button></div></div>` : ''}`,
      `<button class="btn btn-primary btn-block" id="op-ok" style="height:54px">${linhaEdit ? 'Atualizar' : 'Adicionar'}</button>`);
    const preco = () => {
      const vv = (p.variacoes || []).find(x => x.id === v);
      let u = vv && vv.preco != null && vv.preco !== '' ? Number(vv.preco) : Number(p.preco);
      const base = u;
      const opc = [];
      grupos.forEach(g => (g.opcoes || []).forEach(o => { if (sel.has(g.id + ':' + o.id)) { u += Number(o.preco) || 0; opc.push({ g: g.id, o: o.id, nome: o.nome, preco: Number(o.preco) || 0 }); } }));
      let g = null;
      if (kg) { g = gramas((document.getElementById('op-peso') || {}).value); u = r2(base * g / 1000) + (u - base); }
      return { u: r2(u), opc, gramas: g, vv };
    };
    const atual = () => { const r = preco(); document.getElementById('op-ok').textContent = `${linhaEdit ? 'Atualizar' : 'Adicionar'} · ${brl(r.u * (kg ? 1 : qtd))}`; if (kg) document.getElementById('op-pv').textContent = r.gramas > 0 ? `${fmtG(r.gramas)} × ${brl(p.preco)}/kg` : ''; };
    corpo.addEventListener('change', (e) => {
      const t = e.target;
      if (t.name === 'op-v') v = t.value;
      const og = t.closest('[data-g]');
      if (og) {
        const gid = og.dataset.g, g = grupos.find(x => String(x.id) === gid);
        if (t.type === 'radio') [...sel].filter(k => k.startsWith(gid + ':')).forEach(k => sel.delete(k));
        const k = gid + ':' + t.value;
        if (t.checked) {
          const n = [...sel].filter(x => x.startsWith(gid + ':')).length;
          if (t.type === 'checkbox' && g.max && n >= g.max) { t.checked = false; return GP.toast(`Escolha no máximo ${g.max} em "${g.nome}".`, 'err'); }
          sel.add(k);
        } else sel.delete(k);
      }
      corpo.querySelectorAll('.oo').forEach(lb => lb.classList.toggle('on', lb.querySelector('input').checked));
      atual();
    });
    const pz = document.getElementById('op-peso'); if (pz) { pz.oninput = atual; pz.onkeydown = (e) => { if (e.key === 'Enter') document.getElementById('op-ok').click(); }; setTimeout(() => pz.focus(), 60); }
    const m = document.getElementById('op-m'); if (m) { m.onclick = () => { qtd = Math.max(1, qtd - 1); document.getElementById('op-q').textContent = qtd; atual(); }; document.getElementById('op-p').onclick = () => { qtd = Math.min(999, qtd + 1); document.getElementById('op-q').textContent = qtd; atual(); }; }
    atual();
    document.getElementById('op-ok').onclick = () => {
      const r = preco();
      if (kg && (!r.gramas || r.gramas < 1 || r.gramas > 100000)) return GP.toast('Digite o peso em kg (ex.: 0,350).', 'err');
      if ((p.variacoes || []).length && !v) return GP.toast('Escolha uma opção.', 'err');
      for (const g of grupos) {
        const n = [...sel].filter(x => x.startsWith(g.id + ':')).length;
        if (n < (g.min || 0)) return GP.toast(`Escolha ${g.min} em "${g.nome}".`, 'err');
        if (g.max && n > g.max) return GP.toast(`Escolha no máximo ${g.max} em "${g.nome}".`, 'err');
      }
      const nome = p.nome + (r.vv ? ` (${r.vv.nome})` : '') + (kg ? ` (${fmtG(r.gramas)})` : '');
      const linha = { p, qtd: kg ? 1 : qtd, unit: r.u, nome, v, g: kg ? r.gramas : null, opcoes: r.opc, sel: [...sel], obs: document.getElementById('op-obs').value.trim() };
      aoConfirmar(linha);
    };
  };

})();
