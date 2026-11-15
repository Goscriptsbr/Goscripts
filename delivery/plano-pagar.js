// GoPedido — compra de plano dentro do painel (Pix ou cartão pelo Mercado Pago, liberação automática)
(function () {
  const { esc, brl, ic } = GP;
  const NOMES = { profissional: 'Profissional', premium: 'Premium' };
  const MSG = {
    nao_logado: 'Sua sessão expirou. Entre de novo.', so_dono: 'Só o dono da conta pode assinar um plano.',
    plano_invalido: 'Plano inválido.', limite_meses: 'Você já tem o máximo de 3 meses pagos neste plano.',
    plano_vitalicio: 'Sua conta tem um plano liberado sem vencimento. Fale com a gente pelo WhatsApp para mudar.',
    planos_nao_configurados: 'O pagamento automático dos planos ainda não foi ligado. Assine pelo WhatsApp.',
    cartao_invalido: 'Confira os dados do cartão.',
    extra_so_premium: 'Produtos extras são só para quem tem o plano Premium ativo.', extra_qtd: 'Escolha de 10 a 2.000 produtos extras.', extra_assin_qtd: 'Escolha de 5 a 2.000 assinantes extras.'
  };
  let sb = null, info = null, plano = 'profissional', meses = 1, aba = 'pix', poll = null, aoPagar = null, brick = null, qtd = 50;
  const dataBR = (d) => d ? String(d).slice(0, 10).split('-').reverse().join('/') : '';

  async function chamar(body) {
    const { data, error } = await sb.functions.invoke('ff-mercadopago', { body });
    if (error) {
      let j = null; try { j = error.context && await error.context.json(); } catch (_) {}
      const cod = (j && j.error) || '';
      const e = new Error(MSG[cod] || (cod === 'mp_erro' && j.detalhe ? 'Mercado Pago: ' + j.detalhe : '') || (j && (j.detalhe || j.error)) || GP.err(error));
      e.codigo = cod; throw e;
    }
    return data;
  }

  function fechar() {
    clearInterval(poll); poll = null;
    try { if (brick && brick.unmount) brick.unmount(); } catch (_) {}
    brick = null;
    const w = document.getElementById('pl-mod'); if (w) { w.classList.remove('on'); setTimeout(() => w.remove(), 180); }
  }

  function moldura() {
    fechar();
    const w = document.createElement('div');
    w.className = 'cfm-wrap'; w.id = 'pl-mod';
    w.innerHTML = `<div class="cfm plp" role="dialog" aria-modal="true"><button class="icon-btn pl-x" type="button">${ic('x')}</button><div id="plp-c"><p class="center" style="padding:30px 0"><span class="spin"></span></p></div></div>`;
    document.body.appendChild(w);
    requestAnimationFrame(() => w.classList.add('on'));
    w.addEventListener('click', (e) => { if (e.target === w || e.target.closest('.pl-x')) fechar(); });
    return w;
  }
  const $c = () => document.getElementById('plp-c');

  function renderExtra() {
    const A = plano === 'extra_assin', TIT = A ? 'Assinantes extras' : 'Produtos extras', UN = A ? 'assinante' : 'produto', UNS = A ? 'assinantes' : 'produtos', PASSO = A ? 5 : 10;
    const ex = info.tabela[plano] || (A ? { erro: 'extra_so_premium' } : {});
    if (ex.erro) { $c().innerHTML = `<h3 style="margin:0 0 6px">${TIT}</h3><p class="small">${esc(ex.erro === 'extra_so_premium' && A ? 'Assinantes extras são só para quem tem o plano Premium ativo.' : MSG[ex.erro] || ex.erro)}</p>`; return; }
    const preco = Number(ex.preco) || (A ? 1 : 0.2);
    const total = (m) => Math.round(qtd * preco * m * 100) / 100;
    const hoje = new Date(); const fim = (m) => { const d = new Date(hoje.getTime() + m * 30 * 86400e3); return d.toISOString().slice(0, 10); };
    const sel = { valor: total(meses), valido_ate: fim(meses) };
    const passa = ex.premium_ate && sel.valido_ate > ex.premium_ate;
    $c().innerHTML = `
      <h3 style="margin:0 0 4px">${TIT}</h3>
      <p class="small muted" style="margin:0 0 14px">Para o Premium: ${brl(preco)} por ${UN}, por mês. Liberado na hora para <b>${esc(info.email)}</b>.</p>
      <label class="field" style="margin-bottom:10px"><span>Quantos ${UNS} a mais?</span>
        <div class="plp-q"><button type="button" class="btn btn-ghost" data-q="-${PASSO}">−</button><input class="input" id="plp-qtd" inputmode="numeric" value="${qtd}"><button type="button" class="btn btn-ghost" data-q="${PASSO}">+</button></div></label>
      <div class="plp-qs">${(A ? [10, 25, 50, 100] : [20, 50, 100, 200]).map(n => `<button type="button" class="chip ${qtd === n ? 'on' : ''}" data-qn="${n}">+${n}</button>`).join('')}</div>
      <div class="plp-ms">${[1, 2, 3].map(m => `<button type="button" class="plp-m ${meses === m ? 'on' : ''}" data-m="${m}"><b>${m} ${m > 1 ? 'meses' : 'mês'}</b><span class="v">${brl(total(m))}</span><small>${brl(qtd * preco)}/mês</small></button>`).join('')}</div>
      <div class="plp-res"><span>+${qtd} ${UNS} válidos até</span><b>${dataBR(sel.valido_ate)}</b>
        ${passa ? `<small style="color:#9a3412">Os extras só valem enquanto o Premium estiver ativo (até ${dataBR(ex.premium_ate)}). Renove o Premium para aproveitar todo o período.</small>` : ''}</div>
      <div class="seg3 plp-ab" style="grid-template-columns:1fr 1fr"><button type="button" data-ab="pix" class="${aba === 'pix' ? 'on' : ''}">${ic('pix')}Pix</button><button type="button" data-ab="cartao" class="${aba === 'cartao' ? 'on' : ''}">${ic('card')}Cartão</button></div>
      <div id="plp-pg"></div>`;
    const setQ = (n) => { qtd = Math.max(PASSO, Math.min(2000, Math.round((Number(n) || PASSO) / PASSO) * PASSO)); renderExtra(); };
    $c().querySelector('.plp-q').onclick = (e) => { const b = e.target.closest('[data-q]'); if (b) setQ(qtd + Number(b.dataset.q)); };
    $c().querySelector('#plp-qtd').onchange = (e) => setQ(e.target.value);
    $c().querySelector('.plp-qs').onclick = (e) => { const b = e.target.closest('[data-qn]'); if (b) setQ(b.dataset.qn); };
    $c().querySelector('.plp-ms').onclick = (e) => { const b = e.target.closest('[data-m]'); if (b) { meses = Number(b.dataset.m); renderExtra(); } };
    $c().querySelector('.plp-ab').onclick = (e) => { const b = e.target.closest('[data-ab]'); if (b) { aba = b.dataset.ab; renderExtra(); } };
    (aba === 'pix' ? areaPix : areaCartao)(sel);
  }

  function render() {
    if (plano === 'extra' || plano === 'extra_assin') return renderExtra();
    const t = info.tabela[plano] || {};
    const p1 = Number((t[1] || {}).valor) || (plano === 'premium' ? 100 : 50);
    const sel = t[meses] || {};
    $c().innerHTML = `
      <h3 style="margin:0 0 4px">Assinar plano</h3>
      <p class="small muted" style="margin:0 0 14px">Pague pelo Pix ou cartão. O plano é liberado na hora para <b>${esc(info.email)}</b>.</p>
      <div class="seg3 plp-pl" style="grid-template-columns:1fr 1fr"><button type="button" data-pl="profissional" class="${plano === 'profissional' ? 'on' : ''}">Profissional</button><button type="button" data-pl="premium" class="${plano === 'premium' ? 'on' : ''}">Premium</button></div>
      <div class="plp-ms">${[1, 2, 3].map(m => {
        const o = t[m] || {}; const bloq = !!o.erro;
        const eco = !bloq && m > 1 ? Math.round(p1 * m - Number(o.valor)) : 0;
        return `<button type="button" class="plp-m ${meses === m ? 'on' : ''} ${bloq ? 'dis' : ''}" data-m="${m}" ${bloq ? 'disabled' : ''}>
          <b>${m} ${m > 1 ? 'meses' : 'mês'}</b>
          <span class="v">${bloq ? '—' : brl(o.valor)}</span>
          <small>${bloq ? (o.erro === 'limite_meses' ? 'passa de 3 meses' : 'indisponível') : eco ? `economize ${brl(eco)}` : `${brl(p1)}/mês`}</small>
        </button>`;
      }).join('')}</div>
      ${sel.erro ? `<div class="warnline" style="margin:10px 0">${esc(MSG[sel.erro] || sel.erro)}</div>` : `
      <div class="plp-res"><span>Plano ${NOMES[plano]} válido até</span><b>${dataBR(sel.valido_ate)}</b>
        ${sel.credito_dias ? `<small>Inclui ${sel.credito_dias} dias de crédito do seu plano atual.</small>` : sel.atual === plano && sel.atual_ate ? `<small>Soma depois do vencimento atual (${dataBR(sel.atual_ate)}).</small>` : ''}</div>
      <div class="seg3 plp-ab" style="grid-template-columns:1fr 1fr"><button type="button" data-ab="pix" class="${aba === 'pix' ? 'on' : ''}">${ic('pix')}Pix</button><button type="button" data-ab="cartao" class="${aba === 'cartao' ? 'on' : ''}">${ic('card')}Cartão</button></div>
      <div id="plp-pg"></div>`}
      ${info.historico && info.historico.length ? `<details class="plp-h"><summary>Pagamentos anteriores</summary>${info.historico.map(h => `<div><span>${dataBR(h.criado_em)} · ${h.plano === 'extra' ? '+' + h.qtd + ' produtos' : h.plano === 'extra_assin' ? '+' + h.qtd + ' assinantes' : NOMES[h.plano]} ${h.meses}m · ${brl(h.valor)}</span><b class="${GP.statusPag(h)[0]}">${GP.statusPag(h)[1]}</b></div>`).join('')}</details>` : ''}`;
    $c().querySelector('.plp-pl').onclick = (e) => { const b = e.target.closest('[data-pl]'); if (!b) return; plano = b.dataset.pl; if ((info.tabela[plano][meses] || {}).erro) meses = [1, 2, 3].find(m => !(info.tabela[plano][m] || {}).erro) || 1; render(); };
    $c().querySelector('.plp-ms').onclick = (e) => { const b = e.target.closest('[data-m]'); if (!b || b.disabled) return; meses = Number(b.dataset.m); render(); };
    const ab = $c().querySelector('.plp-ab'); if (ab) ab.onclick = (e) => { const b = e.target.closest('[data-ab]'); if (!b) return; aba = b.dataset.ab; render(); };
    if (!sel.erro) (aba === 'pix' ? areaPix : areaCartao)(sel);
  }

  function areaPix(sel) {
    clearInterval(poll);
    const el = document.getElementById('plp-pg');
    el.innerHTML = `<button type="button" class="btn btn-primary btn-block" id="plp-gerar">${ic('pix')}Gerar Pix de ${brl(sel.valor)}</button>`;
    el.querySelector('#plp-gerar').onclick = async (e) => {
      const b = e.currentTarget; b.disabled = true; b.innerHTML = '<span class="spin"></span>Gerando…';
      try {
        const r = await chamar({ acao: 'plano_pix', plano, meses, qtd });
        if (r.pago) return pago();
        el.innerHTML = `<div class="pixqr">${r.qr_img ? `<img alt="QR Code do Pix" src="data:image/png;base64,${r.qr_img}">` : ''}</div>
          <p class="small center" style="margin:8px 0">Abra o app do banco, escolha <b>Pix → Ler QR Code</b> ou use o copia e cola:</p>
          <div class="row" style="gap:6px"><input class="input" readonly value="${esc(r.qr)}" id="plp-cc"><button type="button" class="btn btn-dark btn-sm" id="plp-cp">${ic('copy')}Copiar</button></div>
          <p class="small muted center" style="margin-top:10px"><span class="dot-live"></span> Esperando o pagamento… o plano libera sozinho. O Pix vale 30 minutos.</p>`;
        el.querySelector('#plp-cp').onclick = () => { navigator.clipboard && navigator.clipboard.writeText(r.qr); GP.toast('Código Pix copiado', 'ok'); };
        poll = setInterval(async () => {
          try { const c = await chamar({ acao: 'plano_conferir', id: r.id }); if (c.status === 'aprovado') pago(c.valido_ate); } catch (_) {}
        }, 5000);
      } catch (er) { b.disabled = false; b.innerHTML = ic('pix') + 'Gerar Pix de ' + brl(sel.valor); GP.toast(er.message, 'err'); }
    };
  }

  function carregarSDK() {
    if (window.MercadoPago) return Promise.resolve();
    return new Promise((ok, falha) => { const s = document.createElement('script'); s.src = 'https://sdk.mercadopago.com/js/v2'; s.onload = ok; s.onerror = () => falha(new Error('sdk')); document.head.appendChild(s); });
  }
  async function areaCartao(sel) {
    clearInterval(poll);
    const el = document.getElementById('plp-pg');
    el.innerHTML = `<div id="plp-card"><p class="small muted center" style="padding:20px 0"><span class="spin"></span> Carregando o formulário seguro do Mercado Pago…</p></div>
      <p class="small muted center" style="margin-top:6px">${ic('lock')} Os dados do cartão vão direto para o Mercado Pago.</p>`;
    try {
      if (!info.public_key) throw new Error('chave');
      await carregarSDK();
      if (typeof window.MercadoPago !== 'function') throw new Error('sdk');
      const mpx = new window.MercadoPago(info.public_key, { locale: 'pt-BR' });
      try { if (brick && brick.unmount) brick.unmount(); } catch (_) {}
      document.getElementById('plp-card').innerHTML = '';
      brick = await mpx.bricks().create('cardPayment', 'plp-card', {
        initialization: { amount: Number(sel.valor), payer: { email: info.email } },
        customization: { paymentMethods: { maxInstallments: meses, types: { excluded: ['debit_card', 'prepaid_card'] } }, visual: { style: { customVariables: { baseColor: '#F2451C' } } } },
        callbacks: {
          onReady: () => {}, onError: () => {},
          onSubmit: async (dados) => {
            const r = await chamar({ acao: 'plano_cartao', plano, meses, qtd, dados }).catch(er => ({ erro: er.message }));
            if (r.status === 'aprovado') return pago(r.valido_ate);
            if (r.status === 'pendente') { GP.toast('Pagamento em análise. O plano libera assim que o Mercado Pago aprovar.'); return; }
            GP.toast(r.erro || 'O cartão não foi aprovado. Tente outro cartão ou o Pix.' + (r.detalhe ? ' (' + r.detalhe + ')' : ''), 'err');
            throw new Error('recusado');
          }
        }
      });
    } catch (er) {
      el.innerHTML = `<div class="warnline">Não foi possível abrir o cartão agora. Use o Pix ou tente de novo em instantes.</div>`;
    }
  }

  function pago(ate) {
    clearInterval(poll); poll = null;
    $c().innerHTML = `<div class="center" style="padding:10px 0 4px">
      <div class="cfm-ic" style="background:#e7f6ec;color:#166534;margin:0 auto 10px">${ic('check')}</div>
      <h3 style="margin:0 0 6px">${plano === 'extra' ? '+' + qtd + ' produtos liberados!' : plano === 'extra_assin' ? '+' + qtd + ' assinantes liberados!' : 'Plano ' + NOMES[plano] + ' liberado!'}</h3>
      <p class="small muted" style="margin:0 0 16px">${ate ? 'Válido até <b>' + dataBR(ate) + '</b>. ' : ''}Obrigado por assinar o GoPedido. Os limites novos já valem agora.</p>
      <button type="button" class="btn btn-primary btn-block" id="plp-ok">Continuar</button></div>`;
    document.getElementById('plp-ok').onclick = fechar;
    if (aoPagar) aoPagar();
  }

  window.PlanoPagar = {
    async abrir(cliente, o = {}) {
      sb = cliente; aoPagar = o.aoPagar || null;
      plano = ['premium', 'extra', 'extra_assin'].includes(o.plano) ? o.plano : 'profissional'; meses = 1; aba = 'pix'; qtd = plano === 'extra_assin' ? 25 : 50;
      moldura();
      try { info = await chamar({ acao: 'plano_info' }); }
      catch (er) { $c().innerHTML = `<h3 style="margin:0 0 6px">Assinar plano</h3><p class="small">${esc(er.message)}</p>${o.whats ? `<a class="btn btn-primary btn-block" target="_blank" rel="noopener" href="${o.whats}">${ic('chat')}Assinar pelo WhatsApp</a>` : ''}`; return; }
      if (!info.ativo) { $c().innerHTML = `<h3 style="margin:0 0 6px">Assinar plano</h3><p class="small">${MSG.planos_nao_configurados}</p>${o.whats ? `<a class="btn btn-primary btn-block" target="_blank" rel="noopener" href="${o.whats}">${ic('chat')}Assinar pelo WhatsApp</a>` : ''}`; return; }
      if (!plano.startsWith('extra') && (info.tabela[plano][meses] || {}).erro) meses = [1, 2, 3].find(m => !(info.tabela[plano][m] || {}).erro) || 1;
      render();
    }
  };
})();
