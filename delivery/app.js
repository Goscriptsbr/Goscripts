/* GoPedido — funções compartilhadas */
(function () {
  const cfg = window.GP_CONFIG;
  const GP = (window.GP = { cfg });

  // ---------- Supabase ----------
  // modo: true/'loja' = painel do lojista · 'cliente' = conta do cliente · false = sem login
  GP.client = (modo) => {
    const key = modo === 'cliente' ? 'gopedido-cliente' : modo === 'moto' ? 'gopedido-moto' : modo ? 'gopedido-auth' : 'gopedido-pub';
    return window.supabase.createClient(cfg.supabaseUrl, cfg.supabaseKey, {
      auth: modo ? { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true, storageKey: key } : { persistSession: false, storageKey: key }
    });
  };
  GP.publicUrl = (sb, path) => (path ? sb.storage.from('ff-imagens').getPublicUrl(path).data.publicUrl : '');

  // ---------- Ícones ----------
  const ICONS = {
    bag: '<path d="M6 7h12l1 13H5L6 7Z"/><path d="M9 7a3 3 0 0 1 6 0"/>',
    pin: '<path d="M12 21s-7-6.2-7-11.5A7 7 0 0 1 19 9.5C19 14.8 12 21 12 21Z"/><circle cx="12" cy="9.5" r="2.5"/>',
    clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
    calendar: '<rect x="3.5" y="5" width="17" height="15.5" rx="2.5"/><path d="M3.5 10h17M8 3v4M16 3v4"/>',
    scissors: '<circle cx="6" cy="6" r="2.6"/><circle cx="6" cy="18" r="2.6"/><path d="M8.2 7.4 20 18M8.2 16.6 20 6"/>',
    bike: '<circle cx="6" cy="17" r="3"/><circle cx="18" cy="17" r="3"/><path d="M6 17l4-8h4l4 8M10 9 8 5H6m8 4 1-3h2"/>',
    search: '<circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/>',
    x: '<path d="M6 6l12 12M18 6 6 18"/>',
    plus: '<path d="M12 5v14M5 12h14"/>',
    minus: '<path d="M5 12h14"/>',
    copy: '<rect x="9" y="9" width="11" height="11" rx="2"/><path d="M5 15V6a2 2 0 0 1 2-2h8"/>',
    upload: '<path d="M12 15V4m0 0-4 4m4-4 4 4"/><path d="M4 15v3a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-3"/>',
    check: '<path d="m5 12 5 5 9-10"/>',
    more: '<circle cx="5" cy="12" r="1.6"/><circle cx="12" cy="12" r="1.6"/><circle cx="19" cy="12" r="1.6"/>',
    camera: '<path d="M4 8h3l2-3h6l2 3h3a1 1 0 0 1 1 1v9a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V9a1 1 0 0 1 1-1z"/><circle cx="12" cy="13" r="3.5"/>',
    print: '<path d="M7 9V4h10v5"/><rect x="3" y="9" width="18" height="8" rx="2"/><path d="M7 14h10v6H7z"/>',
    barcode: '<path d="M4 5v14M7 5v14M10 5v14M14 5v14M16 5v14M20 5v14"/>',
    chart: '<path d="M4 20V10M10 20V4M16 20v-7M22 20H2"/>',
    wallet: '<rect x="3" y="6" width="18" height="13" rx="2"/><path d="M16 12.5h2M3 9h15a3 3 0 0 0 3-3"/>',
    mail: '<rect x="3" y="5" width="18" height="14" rx="2"/><path d="m3 7 9 6 9-6"/>',
    users: '<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20c.6-3.5 3.2-5.5 6.5-5.5s5.9 2 6.5 5.5"/><path d="M16 4.6a3.5 3.5 0 0 1 0 6.8M18 14.8c2 .7 3.2 2.5 3.5 5.2"/>',
    download: '<path d="M12 4v11m0 0-4-4m4 4 4-4"/><path d="M4 15v3a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-3"/>',
    monitor: '<rect x="3" y="4" width="18" height="12" rx="2"/><path d="M8 20h8M12 16v4"/>',
    store: '<path d="M4 9 5.5 4h13L20 9M4 9v11h16V9M4 9a2.7 2.7 0 0 0 5.3 0 2.7 2.7 0 0 0 5.4 0 2.7 2.7 0 0 0 5.3 0"/><path d="M10 20v-5h4v5"/>',
    phone: '<path d="M5 4h4l2 5-2.5 1.5a11 11 0 0 0 5 5L15 13l5 2v4a2 2 0 0 1-2 2A16 16 0 0 1 3 6a2 2 0 0 1 2-2Z"/>',
    chat: '<path d="M21 12a8 8 0 0 1-11.7 7.1L4 20l1-4.6A8 8 0 1 1 21 12Z"/>',
    card: '<rect x="3" y="5" width="18" height="14" rx="2.5"/><path d="M3 10h18M7 15h4"/>',
    pix: '<path d="m12 3 4.2 4.2-4.2 4.2-4.2-4.2L12 3Z"/><path d="m12 12.6 4.2 4.2L12 21l-4.2-4.2 4.2-4.2Z"/><path d="m3 12 4.2-4.2 4.2 4.2-4.2 4.2L3 12Z" opacity=".55"/><path d="m12.6 12 4.2-4.2L21 12l-4.2 4.2-4.2-4.2Z" opacity=".55"/>',
    left: '<path d="m15 18-6-6 6-6"/>',
    right: '<path d="m9 18 6-6-6-6"/>',
    logout: '<path d="M15 4h3a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2h-3M10 17l5-5-5-5M15 12H3"/>',
    image: '<rect x="3" y="4" width="18" height="16" rx="2.5"/><circle cx="9" cy="10" r="2"/><path d="m21 16-5-5-9 9"/>',
    trash: '<path d="M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3"/>',
    edit: '<path d="M4 20h4L19 9l-4-4L4 16v4Z"/><path d="m13.5 6.5 4 4"/>',
    locate: '<circle cx="12" cy="12" r="3"/><circle cx="12" cy="12" r="8"/><path d="M12 2v2M12 20v2M2 12h2M20 12h2"/>',
    receipt: '<path d="M6 3h12v18l-3-2-3 2-3-2-3 2V3Z"/><path d="M9 8h6M9 12h6"/>',
    list: '<path d="M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01"/>',
    menu: '<path d="M4 6h16M4 12h16M4 18h10"/>',
    star: '<path d="m12 3 2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1-4.4-4.3 6.1-.9L12 3Z"/>',
    eye: '<path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12Z"/><circle cx="12" cy="12" r="3"/>',
    eyeoff: '<path d="M3 3l18 18M10.6 5.1A10 10 0 0 1 12 5c6.4 0 10 7 10 7a17 17 0 0 1-3.2 4M6.6 6.6C3.8 8.4 2 12 2 12s3.6 7 10 7a9.6 9.6 0 0 0 5.4-1.6"/><path d="M9.9 9.9a3 3 0 0 0 4.2 4.2"/>',
    cart: '<circle cx="9" cy="20" r="1.5"/><circle cx="18" cy="20" r="1.5"/><path d="M2 3h3l2.6 12.4a2 2 0 0 0 2 1.6h7.8a2 2 0 0 0 2-1.6L21 7H6"/>',
    pill: '<path d="m10.5 20.5 10-10a4.95 4.95 0 1 0-7-7l-10 10a4.95 4.95 0 1 0 7 7Z"/><path d="m8.5 8.5 7 7"/>',
    paw: '<circle cx="11" cy="4" r="2"/><circle cx="18" cy="8" r="2"/><circle cx="20" cy="16" r="2"/><path d="M9 10a5 5 0 0 1 5 5v3.5a3.5 3.5 0 0 1-6.84 1.05Q6.52 17.48 4.46 16.84A3.5 3.5 0 0 1 5.5 10Z"/>',
    wine: '<path d="M8 22h8M12 15v7M12 15a5 5 0 0 0 5-5c0-2-.5-4-2-8H9c-1.5 4-2 6-2 8a5 5 0 0 0 5 5Z"/><path d="M7.2 9h9.6"/>',
    box: '<path d="M21 8 12 3 3 8v8l9 5 9-5V8Z"/><path d="m3 8 9 5 9-5M12 13v8"/>',
    grid: '<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/>',
        bell: '<path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9"/><path d="M10.3 21a1.94 1.94 0 0 0 3.4 0"/>',
    tag: '<path d="M12.6 2.6A2 2 0 0 0 11.2 2H4a2 2 0 0 0-2 2v7.2a2 2 0 0 0 .6 1.4l8.7 8.7a2.4 2.4 0 0 0 3.4 0l6.6-6.6a2.4 2.4 0 0 0 0-3.4z"/><circle cx="7.5" cy="7.5" r="1.5"/>',
    fire: '<path d="M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.38-.5-2-1-3-1.07-2.14-.22-4.05 2-6 .5 2.5 2 4.9 4 6.5 2 1.6 3 3.5 3 5.5a7 7 0 1 1-14 0c0-1.15.43-2.29 1-3a2.5 2.5 0 0 0 2.5 2.5z"/>',
    lock: '<rect x="4" y="11" width="16" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/>',
    gift: '<rect x="3" y="8" width="18" height="4" rx="1"/><path d="M12 8v13M19 12v7a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2v-7"/><path d="M7.5 8a2.5 2.5 0 0 1 0-5C10 3 12 8 12 8s2-5 4.5-5a2.5 2.5 0 0 1 0 5"/>',
    sparkle: '<path d="M12 3l1.9 5.1L19 10l-5.1 1.9L12 17l-1.9-5.1L5 10l5.1-1.9z"/><path d="M19 15l.8 2.2L22 18l-2.2.8L19 21l-.8-2.2L16 18l2.2-.8z"/>',
        shield: '<path d="M12 3 4 6v6c0 5 3.4 8 8 9 4.6-1 8-4 8-9V6l-8-3Z"/><path d="m9 12 2 2 4-4"/>',
    bolt: '<path d="M13 2 4 14h7l-1 8 9-12h-7l1-8Z"/>',
    cash: '<rect x="2" y="6" width="20" height="12" rx="2"/><circle cx="12" cy="12" r="2.5"/><path d="M6 10v4M18 10v4"/>',
    user: '<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>',
    home: '<path d="M3 11 12 4l9 7"/><path d="M5 10v10h14V10"/>',
    key: '<circle cx="8" cy="15" r="4"/><path d="m11 12 9-9m-4 4 3 3"/>',
    refresh: '<path d="M20 11a8 8 0 1 0-2.3 5.7M20 4v7h-7"/>',
    ext: '<path d="M14 4h6v6M20 4l-9 9M18 14v5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1h5"/>'
  };
  GP.ic = (n, extra = '') => `<svg class="i" viewBox="0 0 24 24" ${extra}>${ICONS[n] || ''}</svg>`;

  // ---------- Utilidades ----------
  GP.$ = (id) => document.getElementById(id);
  GP.esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const fmt = new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' });
  GP.brl = (v) => fmt.format(Number(v) || 0);
  GP.km = (v) => (Number(v) < 1 ? Math.round(Number(v) * 1000) + ' m' : Number(v).toFixed(1).replace('.', ',') + ' km');
  GP.num = (s) => {
    if (typeof s === 'number') return s;
    const t = String(s || '').trim().replace(/[^\d,.-]/g, '');
    if (!t) return 0;
    const n = t.includes(',') ? t.replace(/\./g, '').replace(',', '.') : t;
    return Number(n) || 0;
  };
  // Campo de dinheiro: digita só números e vai preenchendo os centavos (2 → 0,02 → 0,20 → 2,00)
  GP.fmtMoeda = (v) => (Number(v) || 0).toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  GP.moneyMask = (el) => {
    el.setAttribute('inputmode', 'numeric');
    const apply = () => {
      const d = el.value.replace(/\D/g, '').replace(/^0+/, '').slice(0, 9);
      el.value = d ? GP.fmtMoeda(Number(d) / 100) : '';
    };
    el.addEventListener('input', () => { apply(); el.setSelectionRange && el.setSelectionRange(el.value.length, el.value.length); });
    el.addEventListener('focus', () => { setTimeout(() => el.setSelectionRange && el.setSelectionRange(el.value.length, el.value.length), 0); });
    if (el.value) el.value = GP.fmtMoeda(GP.num(el.value));
  };
  GP.digits = (s) => String(s || '').replace(/\D/g, '');
  GP.slugify = (s) =>
    String(s || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase()
      .replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 40) || 'loja';
  GP.phoneMask = (el) => el.addEventListener('input', () => {
    const d = GP.digits(el.value).slice(0, 11);
    el.value = d.length > 10 ? `(${d.slice(0, 2)}) ${d.slice(2, 7)}-${d.slice(7)}`
      : d.length > 6 ? `(${d.slice(0, 2)}) ${d.slice(2, 6)}-${d.slice(6)}`
      : d.length > 2 ? `(${d.slice(0, 2)}) ${d.slice(2)}` : d;
  });
  GP.wa = (tel, msg = '') => {
    let d = GP.digits(tel);
    if (d.length <= 11) d = '55' + d;
    return `https://wa.me/${d}${msg ? '?text=' + encodeURIComponent(msg) : ''}`;
  };
  GP.ls = {
    get(k, d = null) { try { const v = localStorage.getItem(k); return v ? JSON.parse(v) : d; } catch { return d; } },
    set(k, v) { try { localStorage.setItem(k, JSON.stringify(v)); } catch {} },
    del(k) { try { localStorage.removeItem(k); } catch {} }
  };
  GP.ago = (d) => {
    const s = Math.floor((Date.now() - new Date(d)) / 1000);
    if (s < 60) return 'agora';
    if (s < 3600) return Math.floor(s / 60) + ' min';
    if (s < 86400) return Math.floor(s / 3600) + ' h';
    return new Date(d).toLocaleDateString('pt-BR');
  };
  GP.hora = (d) => new Date(d).toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' });

  // ---------- Toast ----------
  GP.toast = (msg, type = '') => {
    let box = GP.$('toasts');
    if (!box) { box = document.createElement('div'); box.id = 'toasts'; document.body.appendChild(box); }
    [...box.children].forEach(x => { if (x.dataset.tipo === (type || 'n') || box.children.length > 2) x.remove(); });
    const t = document.createElement('div');
    t.dataset.tipo = type || 'n';
    t.className = 'toast ' + type;
    t.innerHTML = (type === 'ok' ? GP.ic('check') : '') + '<span>' + GP.esc(msg) + '</span>';
    box.appendChild(t);
    setTimeout(() => { t.style.transition = 'opacity .3s'; t.style.opacity = '0'; setTimeout(() => t.remove(), 300); }, 3200);
  };

  // ---------- Planos ----------
  GP.WHATS = '5519988283178';
  GP.PLANOS = [
    { id: 'gratis', nome: 'Grátis', desc: 'Para começar a vender', preco: 0, lojas: 1, produtos: 30, ex: '', itens: ['Pedidos ilimitados, sem comissão', '1 pessoa na equipe além de você (administrador, caixa ou garçom)', 'Pix, cartão e dinheiro', 'Motoboys e impressão', 'Cupons e promoções', 'Loja de assinaturas: até 10 assinantes'] },
    { id: 'profissional', nome: 'Profissional', desc: 'Para quem tem mais produtos ou uma segunda loja', preco: 50, lojas: 2, produtos: 150, destaque: true, ex: 'Ex.: 100 produtos numa loja e 50 na outra', itens: ['Tudo do plano Grátis', '4 pessoas na equipe além de você (administradores, caixa ou garçons)', 'Loja de assinaturas: até 50 assinantes', 'Suporte pelo WhatsApp'] },
    { id: 'premium', nome: 'Premium', desc: 'Para redes com várias lojas', preco: 100, lojas: 5, produtos: 350, ex: 'Ex.: 5 lojas com 70 produtos cada', itens: ['Tudo do Profissional', '8 pessoas na equipe além de você (administradores, caixa ou garçons)', 'Produtos extras quando precisar: R$ 0,20 por produto/mês', 'Loja de assinaturas: até 150 assinantes (+ extras a R$ 1,00 por assinante/mês)', 'Ideal para redes e franquias', 'Atendimento prioritário'] }
  ];
  GP.planoNome = (id) => (GP.PLANOS.find(p => p.id === id) || GP.PLANOS[0]).nome;
  GP.NOTA_PLANOS = 'Como contam as quantidades: o número de lojas é quantas lojas você pode criar na sua conta. O número de produtos é o total da conta, somando todas as suas lojas. Pedidos não têm limite em nenhum plano. Só no Premium dá para comprar produtos a mais quando precisar (R$ 0,20 por produto por mês). Nas lojas de assinaturas, o limite é de assinantes ativos (10, 50 ou 150), somando todas as lojas; no Premium dá para comprar assinantes a mais (R$ 1,00 por assinante por mês).';
  GP.planosHtml = (atual, email, publico, comprar) => GP.PLANOS.map(p => {
    const msg = `Olá! Quero assinar o plano ${p.nome} (R$ ${p.preco}/mês) do GoPedido.${email ? ' Meu e-mail no painel: ' + email : ''}`;
    return `<div class="plano ${p.destaque ? 'dest' : ''} ${p.id === atual ? 'atual' : ''}">
      ${p.destaque ? '<span class="pl-tag">Mais escolhido</span>' : ''}
      <b class="pl-nome">${p.nome}</b>
      <p class="pl-desc">${p.desc || ''}</p>
      <div class="pl-preco">R$ ${p.preco}<small>/mês</small></div>
      <div class="pl-qtd"><div><b>${p.lojas}</b><span>loja${p.lojas > 1 ? 's' : ''}</span></div><div><b>${p.produtos}</b><span>produtos no total</span></div></div>
      <div class="pl-ex">${p.ex || ''}</div>
      <ul>${p.itens.map(i => `<li>${GP.ic('check')}${i}</li>`).join('')}</ul>
      ${publico && !p.preco ? '<a class="btn btn-ghost btn-sm btn-block" href="painel.html?criar=1">Começar grátis</a>'
        : publico && p.preco ? `<a class="btn ${p.destaque ? 'btn-primary' : 'btn-dark'} btn-sm btn-block" href="painel.html?planos=1">${GP.ic('star')}Assinar</a>`
        : comprar && p.preco ? `<button type="button" class="btn ${p.id === atual ? 'btn-ghost' : p.destaque ? 'btn-primary' : 'btn-dark'} btn-sm btn-block" data-assinar="${p.id}">${p.id === atual ? GP.ic('calendar') + 'Renovar' : GP.ic('star') + 'Assinar'}</button>`
        : p.id === atual ? '<span class="btn btn-ghost btn-sm btn-block" style="pointer-events:none">Seu plano atual</span>'
        : p.preco ? '<span class="btn btn-ghost btn-sm btn-block" style="pointer-events:none">Só o dono da conta assina</span>' : ''}
    </div>`;
  }).join('');
  GP.mostrarPlanos = (o = {}) => {
    const wrap = document.createElement('div');
    wrap.className = 'cfm-wrap';
    wrap.innerHTML = `<div class="cfm planos-modal" role="dialog" aria-modal="true">
      <button class="icon-btn pl-x" type="button">${GP.ic('x')}</button>
      <div class="cfm-ic">${GP.ic('star')}</div>
      <h3>${GP.esc(o.titulo || 'Planos do GoPedido')}</h3>
      <p>${GP.esc(o.texto || (o.comprar ? 'Escolha o plano ideal para o tamanho do seu negócio. Pague por Pix ou cartão e o plano libera na hora.' : 'Escolha o plano ideal para o tamanho do seu negócio. O dono da conta assina pelo painel, com Pix ou cartão, e o plano libera na hora.'))}</p>
      ${o.comprar ? '<p class="small" style="margin:-4px 0 10px"><b>Pagando 2 ou 3 meses de uma vez, sai mais barato.</b></p>' : ''}
      <div class="planos">${GP.planosHtml(o.atual, o.email, false, !!o.comprar)}</div>
      <p class="pl-nota">${GP.NOTA_PLANOS}</p>
      <p class="small" style="margin-top:12px">Dúvidas? Chame no WhatsApp <a href="https://wa.me/${GP.WHATS}" target="_blank" rel="noopener" style="font-weight:700;color:var(--brand-2)">(19) 98828-3178</a></p>
    </div>`;
    document.body.appendChild(wrap);
    requestAnimationFrame(() => wrap.classList.add('on'));
    const fim = () => { wrap.classList.remove('on'); setTimeout(() => wrap.remove(), 180); document.removeEventListener('keydown', key, true); };
    const key = (e) => { if (e.key === 'Escape') { e.stopPropagation(); fim(); } };
    document.addEventListener('keydown', key, true);
    wrap.addEventListener('click', (e) => {
      const a = e.target.closest('[data-assinar]');
      if (a && o.comprar) { fim(); o.comprar(a.dataset.assinar); return; }
      if (e.target === wrap || e.target.closest('.pl-x')) fim();
    });
  };

  // ---------- Confirmação bonita (no lugar do confirm do navegador) ----------
  // await GP.confirmar('Excluir produto?', { texto: '...', ok: 'Excluir', perigo: true })
  GP.confirmar = (titulo, o = {}) => new Promise((resolve) => {
    const perigo = o.perigo !== false && /excluir|apagar|cancelar|remover|sair/i.test(o.ok || titulo) ? true : !!o.perigo;
    const icon = o.icone || (perigo ? 'trash' : 'check');
    const wrap = document.createElement('div');
    wrap.className = 'cfm-wrap';
    wrap.innerHTML = `<div class="cfm" role="alertdialog" aria-modal="true" aria-labelledby="cfm-t">
      <div class="cfm-ic ${perigo ? 'bad' : ''}">${GP.ic(icon)}</div>
      <h3 id="cfm-t">${GP.esc(titulo)}</h3>
      ${o.texto ? `<p>${GP.esc(o.texto)}</p>` : ''}
      <div class="cfm-acts">
        <button type="button" class="btn btn-ghost" data-r="0">${GP.esc(o.cancelar || 'Voltar')}</button>
        <button type="button" class="btn ${perigo ? 'btn-danger' : 'btn-primary'}" data-r="1">${GP.esc(o.ok || 'Confirmar')}</button>
      </div></div>`;
    document.body.appendChild(wrap);
    requestAnimationFrame(() => wrap.classList.add('on'));
    const fim = (v) => {
      document.removeEventListener('keydown', key, true);
      wrap.classList.remove('on'); setTimeout(() => wrap.remove(), 180); resolve(v);
    };
    const key = (e) => { if (e.key === 'Escape') { e.stopPropagation(); fim(false); } if (e.key === 'Enter') { e.preventDefault(); fim(true); } };
    document.addEventListener('keydown', key, true);
    wrap.addEventListener('click', (e) => { const b = e.target.closest('[data-r]'); if (b) fim(b.dataset.r === '1'); else if (e.target === wrap) fim(false); });
    setTimeout(() => wrap.querySelector('[data-r="1"]').focus(), 50);
  });

  // ---------- Erros do banco em português ----------
  const ERROS = {
    loja_invalida: 'Loja não encontrada.',
    loja_fechada: 'A loja está fechada no momento.',
    loja_sem_localizacao: 'A loja ainda não configurou a localização.',
    pagamento_invalido: 'Forma de pagamento não aceita por esta loja.',
    pagamento_pendente: 'Este pedido ainda não foi pago online. Aguarde a aprovação do pagamento para aceitar.',
    opcoes_invalidas: 'Revise as opções escolhidas no produto (algum item obrigatório ficou sem escolher).',
    cupom_invalido: 'Cupom não encontrado para esta loja.',
    cupom_vencido: 'Este cupom já venceu.',
    cupom_esgotado: 'Este cupom já foi usado o máximo de vezes.',
    limite_lojas: 'Você chegou no limite de lojas do seu plano.',
    limite_produtos: 'Você chegou no limite de produtos do seu plano.',
    confirmacao_errada: 'O nome digitado não confere com o nome da loja.', so_dono_exclui: 'Só o dono da conta pode excluir a loja.',
    loja_com_pedidos_abertos: 'A loja tem pedidos em andamento. Entregue ou cancele antes de excluir.', loja_com_agendamentos: 'A loja tem horários marcados. Cancele antes de excluir.',
    loja_com_assinantes: 'A loja tem assinantes com assinatura paga. Cancele antes de excluir.', loja_excluida: 'Esta loja foi excluída.', loja_nao_encontrada: 'Loja não encontrada.',
    sem_permissao: 'Você não tem permissão para isso.', pdv_desligado: 'O caixa desta loja está desligado. Ligue em Minha loja → Caixa e mesas.',
    gaveta_desligada: 'O controle de abrir e fechar o caixa está desligado.', caixa_ja_aberto: 'Já existe um caixa aberto nesta loja.',
    caixa_fechado: 'Abra o caixa antes de vender.', sangria_maior: 'A retirada é maior que o dinheiro que deveria ter na gaveta.',
    carrinho_vazio: 'Adicione pelo menos um produto.', venda_grande: 'Venda com itens demais. Divida em duas.', quantidade_invalida: 'Quantidade inválida.',
    produto_codigo_digital: 'Produto de código digital é vendido só pelo site.', desconto_invalido: 'O desconto não pode ser maior que o total.',
    pagamento_menor: 'O valor pago é menor que o total.', pagamento_maior: 'Cartão, Pix e outros não podem passar do total. O troco sai só do dinheiro.',
    venda_invalida: 'Venda inválida. Tente de novo.', venda_nao_encontrada: 'Venda não encontrada.', venda_ja_cancelada: 'Esta venda já foi cancelada.',
    motivo_obrigatorio: 'Escreva o motivo.', caixa_ja_fechado: 'Esta venda é de um caixa já fechado e não pode mais ser cancelada.',
    conte_o_dinheiro: 'Informe quanto dinheiro tem na gaveta.', valor_invalido: 'Valor inválido.', tipo_invalido: 'Tipo inválido.',
    descricao_obrigatoria: 'Escreva uma descrição.', data_invalida: 'Data inválida.', lancamento_invalido: 'Lançamento inválido.',
    periodo_longo: 'Escolha um período de até 400 dias.', feche_o_caixa: 'Feche o caixa aberto antes de desligar.', funcao_invalida: 'Função inválida.',
    membro_invalido: 'Pessoa não encontrada na equipe.',
    mesas_desligadas: 'As mesas desta loja estão desligadas.', mesa_invalida: 'Mesa não encontrada.', identifique_comanda: 'Digite o nome do cliente ou o número do cartão.',
    comanda_nao_encontrada: 'Conta não encontrada.', comanda_na_conta: 'A conta já foi pedida. Reabra para lançar mais itens.',
    comanda_fechada: 'Esta conta já foi fechada ou cancelada.', item_nao_encontrado: 'Item não encontrado.', item_ja_cancelado: 'Este item já foi cancelado.',
    cancelar_so_gerente: 'Só o caixa ou o gerente pode cancelar este item (o garçom cancela só o que lançou, até 5 minutos depois).',
    comanda_vazia: 'A conta não tem itens.', taxa_invalida: 'A taxa de serviço vai de 0 a 30%.', feche_as_comandas: 'Ainda tem contas abertas. Receba ou cancele antes.',
    mesas_invalidas: 'Confira os nomes das mesas.', mesa_com_comanda: 'Não dá para tirar uma mesa que está com conta aberta.',
    desligue_as_mesas: 'Desligue as mesas antes: as contas das mesas fecham no caixa.',
    nome_pessoa: 'Digite o nome da pessoa (não o e-mail). Ex.: Ana Souza.',
    limite_assinantes: 'Você chegou no limite de assinantes do seu plano do GoPedido.',
    sem_vagas: 'Esta loja não está aceitando novos assinantes no momento. Fale com ela pelo WhatsApp.',
    assinante_invalido: 'Assinatura não encontrada. Confira o link do e-mail.', assinante_cancelado: 'Esta assinatura foi cancelada. Fale com a loja.',
    periodo_invalido: 'Escolha um período disponível.', loja_indisponivel: 'Esta loja não está disponível no momento.',
    nome_obrigatorio: 'Digite seu nome.', extra_assin_qtd: 'Escolha de 5 a 2.000 assinantes extras.',
    peso_invalido: 'Um produto por peso está com uma quantidade inválida. Remova da sacola e escolha de novo.',
    loja_bloqueada_plano: 'Esta loja está temporariamente indisponível. Tente mais tarde.',
    push_negado: 'Os avisos foram bloqueados. Libere as notificações deste site nas configurações do navegador e tente de novo.',
    push_ios: 'No iPhone, os avisos só funcionam com o GoPedido instalado na tela de início. Instale e abra pelo ícone.',
    push_sem_suporte: 'Este navegador não recebe avisos. Use o Google Chrome, o Edge ou o Safari atualizado.',
    push_servidor: 'Não deu para ligar os avisos agora. Confira se a função ff-email está publicada e tente de novo.',
    aparelho_invalido: 'Não deu para cadastrar este aparelho. Tente de novo.',
    loja_em_analise: 'Esta loja ainda está em análise e não recebe pedidos.',
    retirada_indisponivel: 'Esta loja não aceita retirada no local.',
    envio_indisponivel: 'Esta loja não está enviando para outras cidades no momento.',
    pagamento_envio: 'Pedidos enviados por transportadora são pagos por Pix.',
    cotacao_vencida: 'O frete mudou. Escolha o frete de novo.',
    cpf_obrigatorio: 'Digite um CPF (ou CNPJ) válido de quem vai receber.',
    cpf_invalido: 'Esse CPF não é válido. Confira os números.',
    email_obrigatorio: 'Digite seu e-mail para receber o código de rastreio.',
    email_invalido: 'Confira o e-mail: parece que falta alguma parte.',
    avaliacao_cedo: 'Você pode avaliar depois que o pedido for entregue.',
    avaliacao_feita: 'Este pedido já foi avaliado. Obrigado!',
    avaliacao_expirada: 'O prazo para avaliar este pedido acabou.',
    sem_permissao: 'Você não tem permissão para isso.', comprovante_invalido: 'Não conseguimos conferir o comprovante. Anexe de novo.',
    cupom_ja_usado: 'Você já usou este cupom o máximo de vezes permitido.',
    cupom_minimo: 'O pedido não atingiu o valor mínimo para este cupom.',
    troco_invalido: 'O valor do troco precisa ser maior que o total do pedido.',
    codigo_invalido: 'Código inválido ou vencido. Peça o código atual para a loja.',
    status_invalido: 'Este pedido já mudou de situação. Atualize a lista.',
    pedido_invalido: 'Pedido não encontrado.',
    sem_estoque: 'Um dos produtos acabou ou não tem essa quantidade em estoque. Ajuste a sacola e tente de novo.',
    escolha_variacao: 'Escolha a opção (tamanho, cor ou sabor) de cada produto.',
    so_dono: 'Só o dono da conta pode gerenciar a equipe.', nao_logado: 'Sua sessão expirou. Entre de novo.',
    nome_invalido: 'Digite o nome da pessoa.', email_invalido: 'Digite um e-mail válido.', senha_curta: 'A senha precisa ter pelo menos 6 caracteres.',
    senha_fraca: 'Escolha uma senha mais forte.', email_existe: 'Este e-mail já tem uma conta no GoPedido. Use outro e-mail.',
    escolha_lojas: 'Marque pelo menos uma das suas lojas.', limite_equipe: 'Você atingiu o limite de pessoas na equipe do seu plano.',
    membro_invalido: 'Essa pessoa não está mais na sua equipe.', erro_conta: 'Não foi possível salvar a conta. Tente de novo.',
    ja_e_lojista: 'Essa pessoa já é dona de uma loja.', acao_invalida: 'Ação inválida.',
    ja_pegou: 'Outro motoboy já pegou este pedido.', pedido_de_outro: 'Esta entrega está com outro motoboy.',
    sem_loja: 'Cadastre sua loja primeiro.',
    comprovante_obrigatorio: 'Anexe o comprovante do Pix para enviar o pedido.',
    dados_incompletos: 'Preencha nome, telefone e endereço.',
    localizacao_obrigatoria: 'Informe sua localização no mapa.',
    fora_da_area: 'Seu endereço está fora da área de entrega da loja.',
    produto_indisponivel: 'Um dos produtos ficou indisponível. Revise a sacola.',
    carrinho_vazio: 'Sua sacola está vazia.',
    abaixo_do_minimo: 'O pedido não atingiu o valor mínimo da loja.',
    horario_ocupado: 'Esse horário acabou de ser ocupado. Escolha outro.',
    horario_passou: 'Esse horário já passou ou está muito em cima. Escolha outro.',
    horario_longe: 'Esse dia ainda não está aberto para agendamento.',
    horario_invalido: 'Horário inválido. Escolha de novo.',
    fora_do_horario: 'Esse horário está fora do expediente do profissional.',
    servico_invalido: 'Esse serviço não está mais disponível.',
    profissional_invalido: 'Esse profissional não faz esse serviço ou não está atendendo.',
    email_obrigatorio_agenda: 'Digite seu e-mail: é por ele que vão a confirmação e o lembrete do horário.',
    nome_obrigatorio: 'Digite seu nome.', telefone_invalido: 'Digite um WhatsApp válido, com DDD.',
    limite_agendamentos: 'Você já tem muitos horários marcados aqui. Cancele algum antes de marcar outro.',
    agendamento_invalido: 'Agendamento não encontrado.', agendamento_encerrado: 'Este horário já foi cancelado ou concluído.',
    cancelar_tarde: 'Está muito em cima da hora para cancelar por aqui. Fale com o estabelecimento pelo WhatsApp.',
    'Invalid login credentials': 'E-mail ou senha incorretos.',
    'Auth session missing': 'Este link de senha expirou ou já foi usado. Peça um novo em "Esqueci minha senha".',
    'Email link is invalid or has expired': 'Este link expirou ou já foi usado. Peça um novo.',
    'should be different from the old password': 'A nova senha precisa ser diferente da senha atual.',
    'Email not confirmed': 'Confirme seu e-mail antes de entrar (veja sua caixa de entrada).',
    'User already registered': 'Este e-mail já tem conta. Faça login.'
  };
  GP.err = (e) => {
    const m = (e && (e.message || e.error_description || e.msg)) || String(e || 'Erro');
    for (const k in ERROS) if (m.includes(k)) return ERROS[k];
    if (/duplicate key.*slug/i.test(m)) return 'Já existe uma loja com esse endereço de link.';
    if (/Password should be/i.test(m)) return 'A senha precisa ter pelo menos 6 caracteres.';
    if (/fetch|network/i.test(m)) return 'Sem conexão. Verifique a internet e tente de novo.';
    return m;
  };

  // ---------- Distância e taxa (mesma conta do servidor) ----------
  GP.dist = (lat1, lng1, lat2, lng2) => {
    const R = 6371, rad = (x) => (x * Math.PI) / 180;
    const a = Math.sin(rad(lat2 - lat1) / 2) ** 2 + Math.cos(rad(lat1)) * Math.cos(rad(lat2)) * Math.sin(rad(lng2 - lng1) / 2) ** 2;
    return Math.round(2 * R * Math.asin(Math.sqrt(a)) * 100) / 100;
  };
  // Taxa de entrega: modo "km" (com ou sem arredondar para cima) ou "tabela" por faixas. null = não entrega.
  GP.faixas = (loja) => (Array.isArray(loja.taxa_tabela) ? loja.taxa_tabela : []).filter(f => Number(f.ate) > 0).sort((a, b) => Number(a.ate) - Number(b.ate));
  GP.taxaOuNada = (loja, dist) => {
    if (Number(loja.raio_km) > 0 && dist > Number(loja.raio_km)) return null;
    if (loja.taxa_modo === 'tabela') { const f = GP.faixas(loja).find(x => dist <= Number(x.ate)); return f ? Math.round(Number(f.valor) * 100) / 100 : null; }
    // arredondamento normal: só sobe se passar de ,5 (4,3 = 4 · 4,6 = 5); mínimo 1 km
    const d = loja.km_arredonda === false ? dist : Math.max(1, (dist - Math.floor(dist)) > 0.5 + 1e-9 ? Math.ceil(dist) : Math.floor(dist));
    return Math.max(Number(loja.taxa_minima) || 0, Math.round(d * (Number(loja.taxa_km) || 0) * 100) / 100);
  };
  GP.taxa = (loja, dist) => { const t = GP.taxaOuNada(loja, dist); return t == null ? 0 : t; };
  GP.foraArea = (loja, dist) => GP.taxaOuNada(loja, dist) == null;
  // texto curto da regra de entrega da loja
  GP.regraEntrega = (loja) => {
    if (loja.taxa_modo === 'tabela') { const f = GP.faixas(loja); if (!f.length) return 'Entrega a combinar'; const mn = Math.min(...f.map(x => Number(x.valor))); return mn ? `Entrega a partir de ${GP.brl(mn)}` : 'Entrega grátis perto'; }
    return Number(loja.taxa_km) ? `${GP.brl(loja.taxa_km)}/km${Number(loja.taxa_minima) ? ' · mín. ' + GP.brl(loja.taxa_minima) : ''}` : 'Entrega grátis';
  };

  // Distância pelas ruas (rota de carro) usando OSRM/OpenStreetMap. Devolve km ou null.
  const rotaCache = {};
  GP.rota = async (lat1, lng1, lat2, lng2) => {
    const k = [lat1, lng1, lat2, lng2].map(v => Number(v).toFixed(5)).join(',');
    if (rotaCache[k] !== undefined) return rotaCache[k];
    const ctrl = new AbortController(); const t = setTimeout(() => ctrl.abort(), 7000);
    try {
      const r = await fetch(`https://router.project-osrm.org/route/v1/driving/${lng1},${lat1};${lng2},${lat2}?overview=false&alternatives=false`, { signal: ctrl.signal });
      const j = await r.json();
      const m = j && j.code === 'Ok' && j.routes && j.routes[0] && j.routes[0].distance;
      rotaCache[k] = m ? Math.round(m / 10) / 100 : null;
    } catch { rotaCache[k] = null; }
    clearTimeout(t);
    return rotaCache[k];
  };
  // mesma regra do servidor: rota válida entre a linha reta e 3x a linha reta + 1 km; senão linha reta + 30%
  GP.distEntrega = (reta, rota) => rota != null && rota >= reta && rota <= reta * 3 + 1 ? Math.round(rota * 100) / 100 : Math.round(reta * 1.3 * 100) / 100;

  // Celular/tablet com tela de toque = tem GPS. Computador só sabe a região pela internet.
  GP.temGps = () => {
    try {
      if (navigator.userAgentData && typeof navigator.userAgentData.mobile === 'boolean' && navigator.userAgentData.mobile) return true;
      return /Android|iPhone|iPad|iPod|Mobile/i.test(navigator.userAgent) || (matchMedia('(pointer: coarse)').matches && navigator.maxTouchPoints > 0);
    } catch { return true; }
  };

  // Localização de alta precisão: escuta o GPS por alguns segundos e fica com a leitura mais precisa
  GP.geo = (opts = {}) => new Promise((ok, fail) => {
    if (!navigator.geolocation) return fail(new Error('Seu navegador não permite localização.'));
    const alvo = opts.alvo || 15, limite = opts.limite || 12000;
    let best = null, fim = false, wid = null, tm = null; const t0 = Date.now();
    const acabar = () => {
      if (fim) return; fim = true;
      if (wid != null) navigator.geolocation.clearWatch(wid);
      clearTimeout(tm);
      best ? ok(best) : fail(new Error('Não foi possível obter sua localização. Ligue o GPS do celular e tente de novo.'));
    };
    wid = navigator.geolocation.watchPosition(
      (p) => {
        const acc = Math.round(p.coords.accuracy || 9999);
        if (!best || acc < best.acc) best = { lat: p.coords.latitude, lng: p.coords.longitude, acc };
        if (opts.onProgress) opts.onProgress(best);
        // computador sem GPS: a posição vem pela internet (±km) e não melhora — não adianta esperar
        if (best.acc <= alvo || (best.acc > 3000 && Date.now() - t0 > 2500)) acabar();
      },
      (e) => {
        if (best) return acabar();
        fim = true; if (wid != null) navigator.geolocation.clearWatch(wid); clearTimeout(tm);
        fail(new Error(e.code === 1 ? 'Permita o acesso à localização para calcular a entrega.' : 'Não foi possível obter sua localização. Ligue o GPS do celular e tente de novo.'));
      },
      { enableHighAccuracy: true, timeout: limite, maximumAge: 0 }
    );
    tm = setTimeout(acabar, limite);
  });

  // Mapa com pino arrastável (Leaflet + OpenStreetMap)
  GP.mapPicker = (el, start, onChange) => {
    const c = start && start.lat != null ? [start.lat, start.lng] : cfg.centro;
    const map = L.map(el, { zoomControl: true, attributionControl: true }).setView(c, start && start.lat != null ? 16 : 13);
    const ruas = L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', { maxZoom: 19, attribution: '© OpenStreetMap' }).addTo(map);
    const sat = L.layerGroup([
      L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', { maxZoom: 19, attribution: 'Imagens © Esri' }),
      L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}', { maxZoom: 19 }),
      L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Transportation/MapServer/tile/{z}/{y}/{x}', { maxZoom: 19 })
    ]);
    L.control.layers({ 'Mapa': ruas, 'Satélite': sat }, null, { position: 'topright', collapsed: false }).addTo(map);
    let circ = null;
    const icon = L.divIcon({
      className: '', iconSize: [36, 46], iconAnchor: [18, 44],
      html: '<svg width="36" height="46" viewBox="0 0 36 46"><path d="M18 45s15-14.2 15-27A15 15 0 0 0 3 18c0 12.8 15 27 15 27Z" fill="#F2451C" stroke="#fff" stroke-width="3"/><circle cx="18" cy="18" r="5.5" fill="#fff"/></svg>'
    });
    let marker = null;
    const put = (lat, lng, fire = true) => {
      if (!marker) {
        marker = L.marker([lat, lng], { draggable: true, icon }).addTo(map);
        marker.on('dragend', () => { const p = marker.getLatLng(); onChange && onChange(p.lat, p.lng); });
      } else marker.setLatLng([lat, lng]);
      if (fire && onChange) onChange(lat, lng);
    };
    if (start && start.lat != null) put(start.lat, start.lng, false);
    map.on('click', (e) => put(e.latlng.lat, e.latlng.lng));
    setTimeout(() => map.invalidateSize(), 250);
    return {
      map,
      set(lat, lng, silent, zoom) { put(lat, lng, !silent); map.setView([lat, lng], zoom || 18); },
      precisao(lat, lng, acc) {
        if (circ) { map.removeLayer(circ); circ = null; }
        if (acc && acc > 8) circ = L.circle([lat, lng], { radius: acc, color: '#2563eb', weight: 1, fillOpacity: 0.08, interactive: false }).addTo(map);
      },
      refresh() { setTimeout(() => map.invalidateSize(), 60); }
    };
  };

  // ---------- Imagens: reduz antes de enviar ----------
  GP.compress = (file, max = 1280, q = 0.82) => new Promise((ok) => {
    if (!file.type.startsWith('image/') || file.type === 'image/gif') return ok(file);
    const img = new Image();
    const url = URL.createObjectURL(file);
    img.onload = () => {
      const s = Math.min(1, max / Math.max(img.width, img.height));
      const c = document.createElement('canvas');
      c.width = Math.round(img.width * s); c.height = Math.round(img.height * s);
      c.getContext('2d').drawImage(img, 0, 0, c.width, c.height);
      URL.revokeObjectURL(url);
      c.toBlob((b) => ok(b && b.size < file.size ? new File([b], 'img.jpg', { type: 'image/jpeg' }) : file), 'image/jpeg', q);
    };
    img.onerror = () => { URL.revokeObjectURL(url); ok(file); };
    img.src = url;
  });
  GP.ext = (f) => (f.type === 'application/pdf' ? 'pdf' : f.type === 'image/png' ? 'png' : f.type === 'image/webp' ? 'webp' : 'jpg');
  // UUID v4 de verdade (o banco exige esse formato), mesmo em navegador antigo
  GP.uuid = () => {
    if (crypto.randomUUID) return crypto.randomUUID();
    const b = crypto.getRandomValues(new Uint8Array(16)); b[6] = (b[6] & 15) | 64; b[8] = (b[8] & 63) | 128;
    const h = [...b].map(x => x.toString(16).padStart(2, '0')).join('');
    return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20)}`;
  };
  // Ler código de barras pela câmera (Chrome/Android). Devolve o código ou '' se cancelar. Leitor USB não precisa disto.
  GP.temCamCodigo = () => 'BarcodeDetector' in window && !!(navigator.mediaDevices && navigator.mediaDevices.getUserMedia);
  GP.lerCodigo = () => new Promise(async (resolve) => {
    let stream = null, parar = false;
    const w = document.createElement('div');
    w.style.cssText = 'position:fixed;inset:0;z-index:200;background:#000;display:flex;flex-direction:column;align-items:center;justify-content:center';
    w.innerHTML = `<video playsinline muted style="width:100%;max-width:640px;max-height:70vh;object-fit:cover"></video>
      <div style="position:absolute;left:12%;right:12%;top:calc(50% - 60px);height:120px;border:3px solid #F2451C;border-radius:16px;pointer-events:none"></div>
      <p style="color:#fff;margin:14px 0 10px;font-weight:600">Aponte para o código de barras</p>
      <button type="button" class="btn btn-ghost" style="background:#fff">Cancelar</button>`;
    document.body.appendChild(w);
    const fim = (v) => { parar = true; try { stream && stream.getTracks().forEach(t => t.stop()); } catch (_) {} w.remove(); resolve(v || ''); };
    w.querySelector('button').onclick = () => fim('');
    try {
      const det = new window.BarcodeDetector({ formats: ['ean_13', 'ean_8', 'upc_a', 'upc_e', 'code_128', 'code_39', 'itf', 'qr_code'] });
      stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: 'environment' }, audio: false });
      const v = w.querySelector('video'); v.srcObject = stream; await v.play();
      const passo = async () => {
        if (parar) return;
        try { const r = await det.detect(v); if (r && r[0] && r[0].rawValue) { if (navigator.vibrate) navigator.vibrate(60); return fim(String(r[0].rawValue).trim()); } } catch (_) {}
        setTimeout(passo, 180);
      };
      passo();
    } catch (_) { GP.toast('Não foi possível abrir a câmera. Confira a permissão do navegador.', 'err'); fim(''); }
  });
  GP.uid = () => (crypto.randomUUID ? crypto.randomUUID() : Date.now().toString(36) + Math.random().toString(36).slice(2));

  // ---------- Pix "copia e cola" (padrão BR Code do Banco Central) ----------
  const ascii = (s, n) => String(s || '').normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^A-Za-z0-9 .-]/g, '').trim().toUpperCase().slice(0, n);
  const tlv = (id, v) => id + String(v.length).padStart(2, '0') + v;
  const crc16 = (s) => {
    let c = 0xffff;
    for (let i = 0; i < s.length; i++) {
      c ^= s.charCodeAt(i) << 8;
      for (let j = 0; j < 8; j++) c = c & 0x8000 ? (c << 1) ^ 0x1021 : c << 1;
      c &= 0xffff;
    }
    return c.toString(16).toUpperCase().padStart(4, '0');
  };
  const cpfValido = (d) => {
    if (!/^\d{11}$/.test(d) || /^(\d)\1+$/.test(d)) return false;
    const dv = (n) => { let t = 0; for (let k = 0; k < n; k++) t += +d[k] * (n + 1 - k); const r = (t * 10) % 11; return r === 10 ? 0 : r; };
    return dv(9) === +d[9] && dv(10) === +d[10];
  };
  // Descobre o tipo da chave pelo que foi digitado (não depende da opção escolhida)
  GP.pixTipo = (chave, tipoEscolhido) => {
    const k = String(chave || '').trim(), d = GP.digits(k);
    if (!k) return tipoEscolhido;
    if (k.includes('@')) return 'email';
    if (/^[0-9a-f]{8}-?[0-9a-f]{4}-?[0-9a-f]{4}-?[0-9a-f]{4}-?[0-9a-f]{12}$/i.test(k)) return 'aleatoria';
    if (k.startsWith('+')) return 'telefone';
    if (d.length === 14) return 'cnpj';
    if (d.length === 11) return cpfValido(d) && tipoEscolhido !== 'telefone' ? 'cpf' : 'telefone';
    if (d.length === 10 || ((d.length === 12 || d.length === 13) && d.startsWith('55'))) return 'telefone';
    return tipoEscolhido;
  };
  const cnpjValido = (d) => {
    if (!/^\d{14}$/.test(d) || /^(\d)\1+$/.test(d)) return false;
    const calc = (n) => { const w = n === 12 ? [5,4,3,2,9,8,7,6,5,4,3,2] : [6,5,4,3,2,9,8,7,6,5,4,3,2]; let t = 0; for (let k = 0; k < n; k++) t += +d[k] * w[k]; const r = t % 11; return r < 2 ? 0 : 11 - r; };
    return calc(12) === +d[12] && calc(13) === +d[13];
  };
  GP.cnpjValido = (v) => cnpjValido(GP.digits(v));
  GP.cpfValido = (v) => cpfValido(GP.digits(v));
  GP.docValido = (v) => { const d = GP.digits(v); return d.length === 11 ? cpfValido(d) : d.length === 14 ? cnpjValido(d) : false; };
  GP.fmtCnpj = (v) => { const d = GP.digits(v).slice(0, 14); return d.replace(/^(\d{2})(\d)/, '$1.$2').replace(/^(\d{2})\.(\d{3})(\d)/, '$1.$2.$3').replace(/\.(\d{3})(\d)/, '.$1/$2').replace(/(\d{4})(\d)/, '$1-$2'); };
  // Confere se a chave combina com o tipo escolhido
  GP.pixValida = (tipo, chave) => {
    const k = String(chave || '').trim(), d = GP.digits(k);
    if (!k) return { ok: false, msg: 'Digite a chave Pix.' };
    if (tipo === 'cpf') {
      if (d.length !== 11 || /[a-z@]/i.test(k)) return { ok: false, msg: 'CPF precisa ter 11 números.' };
      if (!cpfValido(d)) return { ok: false, msg: 'Esse CPF não é válido. Confira os números.' };
      return { ok: true, chave: d };
    }
    if (tipo === 'cnpj') {
      if (d.length !== 14 || /[a-z@]/i.test(k)) return { ok: false, msg: 'CNPJ precisa ter 14 números.' };
      if (!cnpjValido(d)) return { ok: false, msg: 'Esse CNPJ não é válido. Confira os números.' };
      return { ok: true, chave: d };
    }
    if (tipo === 'telefone') {
      if (/[a-z@]/i.test(k)) return { ok: false, msg: 'Telefone só pode ter números.' };
      let n = d;
      if ((n.length === 12 || n.length === 13) && n.startsWith('55')) n = n.slice(2);
      if (n.length !== 10 && n.length !== 11) return { ok: false, msg: 'Telefone precisa ter DDD + número. Ex.: (19) 99999-9999.' };
      if (+n.slice(0, 2) < 11) return { ok: false, msg: 'DDD inválido.' };
      if (n.length === 11 && n[2] !== '9') return { ok: false, msg: 'Celular com 11 números deve começar com 9 depois do DDD.' };
      return { ok: true, chave: '+55' + n };
    }
    if (tipo === 'email') {
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(k)) return { ok: false, msg: 'E-mail inválido. Ex.: nome@gmail.com' };
      return { ok: true, chave: k.toLowerCase() };
    }
    if (tipo === 'aleatoria') {
      const h = k.toLowerCase().replace(/[^0-9a-f]/g, '');
      if (h.length !== 32 || !/^[0-9a-f-]+$/i.test(k)) return { ok: false, msg: 'Chave aleatória tem 32 letras/números no formato xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx.' };
      return { ok: true, chave: h.replace(/(.{8})(.{4})(.{4})(.{4})(.{12})/, '$1-$2-$3-$4-$5') };
    }
    return { ok: false, msg: 'Escolha o tipo da chave.' };
  };
  // Chave final usada no QR Code (se uma loja antiga salvou com o tipo errado, tenta o tipo certo)
  GP.pixChave = (tipo, chave) => {
    let v = GP.pixValida(tipo, chave);
    if (!v.ok) v = GP.pixValida(GP.pixTipo(chave, tipo), chave);
    return v.ok ? v.chave : String(chave || '').trim();
  };
  GP.pixPayload = (loja, valor) => {
    const chave = GP.pixChave(loja.pix_tipo, loja.pix_chave);
    if (!chave) return '';
    const p = tlv('00', '01') +
      tlv('26', tlv('00', 'br.gov.bcb.pix') + tlv('01', chave)) +
      tlv('52', '0000') + tlv('53', '986') +
      (valor > 0 ? tlv('54', Number(valor).toFixed(2)) : '') +
      tlv('58', 'BR') +
      tlv('59', ascii(loja.pix_nome || loja.nome, 25) || 'RECEBEDOR') +
      tlv('60', ascii(loja.pix_cidade, 15) || 'BRASIL') +
      tlv('62', tlv('05', '***')) + '6304';
    return p + crc16(p);
  };
  GP.qr = (text) => {
    if (!window.qrcode || !text) return '';
    const q = window.qrcode(0, 'M'); q.addData(text); q.make();
    return q.createSvgTag({ cellSize: 5, margin: 2, scalable: true });
  };
  GP.copy = async (text, msg = 'Copiado!') => {
    try { await navigator.clipboard.writeText(text); }
    catch {
      const t = document.createElement('textarea'); t.value = text; document.body.appendChild(t);
      t.select(); document.execCommand('copy'); t.remove();
    }
    GP.toast(msg, 'ok');
  };

  // ---------- Endereço: CEP (ViaCEP) e mapa (OpenStreetMap / Nominatim) ----------
  GP.viacep = async (cep) => {
    const d = GP.digits(cep);
    if (d.length !== 8) throw new Error('CEP precisa ter 8 números.');
    const r = await fetch(`https://viacep.com.br/ws/${d}/json/`);
    const j = await r.json();
    if (j.erro) throw new Error('CEP não encontrado.');
    return { cep: d.replace(/(\d{5})(\d{3})/, '$1-$2'), rua: j.logradouro || '', bairro: j.bairro || '', cidade: j.localidade || '', uf: j.uf || '' };
  };
  // Busca na base dos Correios todos os CEPs de uma rua (para acertar bairro e CEP)
  GP.viacepRua = async (uf, cidade, rua) => {
    const limpa = (t) => String(t || '').replace(/^(rua|r\.|avenida|av\.?|travessa|alameda|estrada|rodovia)\s+/i, '').trim();
    const nome = limpa(rua);
    if (!uf || !cidade || nome.length < 3) return [];
    const r = await fetch(`https://viacep.com.br/ws/${encodeURIComponent(uf)}/${encodeURIComponent(cidade)}/${encodeURIComponent(nome)}/json/`);
    const j = await r.json();
    return Array.isArray(j) ? j : [];
  };
  // Escolhe o CEP certo quando a rua tem vários (por faixa de número)
  GP.escolheCep = (lista, numero, cepMapa, ruaMapa) => {
    if (!lista.length) return null;
    const norm = (t) => String(t || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().trim();
    let l = lista.filter(x => norm(x.logradouro) === norm(ruaMapa));
    if (!l.length) l = lista;
    if (l.length === 1) return l[0];
    const n = parseInt(String(numero || '').replace(/\D/g, ''), 10);
    if (n) {
      const imp = n % 2 === 1;
      const ok = l.filter(x => {
        const c = norm(x.complemento);
        if (!c) return false;
        if (c.includes('lado impar') && !imp) return false;
        if (c.includes('lado par') && imp) return false;
        let m = c.match(/de (\d+)(?:\/\d+)? ao fim/); if (m) return n >= +m[1];
        m = c.match(/de (\d+)(?:\/\d+)? a (\d+)/); if (m) return n >= +m[1] && n <= +m[2];
        m = c.match(/ate (\d+)/); if (m) return n <= +m[1];
        return true;
      });
      if (ok.length) return ok[0];
    }
    const d = String(cepMapa || '').replace(/\D/g, '');
    return l.find(x => x.cep.replace(/\D/g, '') === d) || l.find(x => !x.complemento) || l[0];
  };
  const NOM = 'https://nominatim.openstreetmap.org';
  GP.reverse = async (lat, lng) => {
    const r = await fetch(`${NOM}/reverse?format=jsonv2&addressdetails=1&accept-language=pt-BR&zoom=18&lat=${lat}&lon=${lng}`);
    const a = (await r.json()).address || {};
    const UFS = { 'Acre': 'AC', 'Alagoas': 'AL', 'Amapá': 'AP', 'Amazonas': 'AM', 'Bahia': 'BA', 'Ceará': 'CE', 'Distrito Federal': 'DF', 'Espírito Santo': 'ES', 'Goiás': 'GO', 'Maranhão': 'MA', 'Mato Grosso': 'MT', 'Mato Grosso do Sul': 'MS', 'Minas Gerais': 'MG', 'Pará': 'PA', 'Paraíba': 'PB', 'Paraná': 'PR', 'Pernambuco': 'PE', 'Piauí': 'PI', 'Rio de Janeiro': 'RJ', 'Rio Grande do Norte': 'RN', 'Rio Grande do Sul': 'RS', 'Rondônia': 'RO', 'Roraima': 'RR', 'Santa Catarina': 'SC', 'São Paulo': 'SP', 'Sergipe': 'SE', 'Tocantins': 'TO' };
    const iso = (a['ISO3166-2-lvl4'] || '').split('-')[1];
    const cep = GP.digits(a.postcode || '');
    return {
      cep: cep.length === 8 ? cep.replace(/(\d{5})(\d{3})/, '$1-$2') : '',
      rua: a.road || a.pedestrian || a.footway || a.residential || '',
      numero: a.house_number || '',
      bairro: a.suburb || a.neighbourhood || a.quarter || a.city_district || a.hamlet || '',
      cidade: a.city || a.town || a.village || a.municipality || '',
      uf: iso || UFS[a.state] || ''
    };
  };
  // Procura o endereço no mapa. Diz se achou o número exato ou só a rua/região.
  GP.geocode = async (e) => {
    const sem = (t) => String(t || '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().trim();
    const num = String(e.numero || '').replace(/\D.*$/, '');
    const tries = [
      `street=${encodeURIComponent((num + ' ' + (e.rua || '')).trim())}&city=${encodeURIComponent(e.cidade || '')}&state=${encodeURIComponent(e.uf || '')}&country=Brasil`,
      `q=${encodeURIComponent([(e.rua || '') + (num ? ', ' + num : ''), e.bairro, e.cidade, e.uf, 'Brasil'].filter(Boolean).join(', '))}`,
      `q=${encodeURIComponent([e.rua, e.bairro, e.cidade, e.uf, 'Brasil'].filter(Boolean).join(', '))}`,
      e.cep ? `postalcode=${GP.digits(e.cep)}&country=Brasil` : ''
    ].filter(Boolean);
    let reserva = null;
    for (const q of tries) {
      try {
        const r = await fetch(`${NOM}/search?format=jsonv2&addressdetails=1&limit=5&countrycodes=br&${q}`);
        const j = await r.json();
        if (!Array.isArray(j) || !j.length) continue;
        const naCidade = j.filter(x => { const a = x.address || {}; const c = sem(a.city || a.town || a.village || a.municipality); return !e.cidade || !c || c === sem(e.cidade); });
        const lista = naCidade.length ? naCidade : j;
        const exato = num && lista.find(x => x.address && String(x.address.house_number || '').replace(/\D.*$/, '') === num);
        if (exato) return { lat: +exato.lat, lng: +exato.lon, prec: 'numero' };
        const rua = lista.find(x => x.address && x.address.road && sem(x.address.road) === sem(e.rua));
        if (rua && (!reserva || reserva.prec !== 'rua')) reserva = { lat: +rua.lat, lng: +rua.lon, prec: 'rua' };
        if (!reserva) reserva = { lat: +lista[0].lat, lng: +lista[0].lon, prec: 'aprox' };
      } catch {}
    }
    return reserva;
  };
  GP.fmtEnd = (e) => {
    const l1 = [e.rua, e.numero].filter(Boolean).join(', ');
    const l2 = [e.bairro, [e.cidade, e.uf].filter(Boolean).join('/')].filter(Boolean).join(', ');
    return [l1, l2].filter(Boolean).join(' - ') + (e.cep ? ' - CEP ' + e.cep : '');
  };

  // Desfaz o texto de GP.fmtEnd ("Rua, 123 - Bairro, Cidade/UF - CEP 00000-000") em campos
  GP.parseEnd = (t) => {
    const o = {}; let s = String(t || '').trim();
    const mc = s.match(/\s*-\s*CEP\s*(\d{5}-?\d{3})\s*$/i);
    if (mc) { o.cep = mc[1]; s = s.slice(0, mc.index); }
    const i = s.indexOf(' - '), l1 = i >= 0 ? s.slice(0, i) : s, l2 = i >= 0 ? s.slice(i + 3) : '';
    const m1 = l1.match(/^(.*),\s*([^,]{1,12})$/);
    if (m1) { o.rua = m1[1].trim(); o.numero = m1[2].trim(); } else o.rua = l1.trim();
    if (l2) {
      const j = l2.lastIndexOf(','), bairro = j >= 0 ? l2.slice(0, j).trim() : '', resto = (j >= 0 ? l2.slice(j + 1) : l2).trim();
      const m3 = resto.match(/^(.*?)(?:\/([A-Za-z]{2}))?$/);
      o.bairro = bairro; o.cidade = (m3 ? m3[1] : resto).trim(); o.uf = m3 && m3[2] ? m3[2].toUpperCase() : '';
    }
    return o;
  };

  // Formulário de endereço completo: CEP + campos + mapa que se preenchem sozinhos
  GP.addressForm = (root, opts = {}) => {
    const id = 'af' + Math.random().toString(36).slice(2, 7);
    root.innerHTML = `
      <div class="grid2">
        <label class="field"><span>CEP</span><div class="prefix-r"><input class="input" id="${id}-cep" inputmode="numeric" maxlength="9" placeholder="00000-000" autocomplete="postal-code"><i id="${id}-cepst"></i></div><small><a href="https://buscacepinter.correios.com.br/" target="_blank" rel="noopener" style="text-decoration:underline">Não sei meu CEP</a></small></label>
        ${GP.temGps() ? `<div class="field"><span>&nbsp;</span><button type="button" class="btn btn-soft btn-block" id="${id}-geo">${GP.ic('locate')}Minha localização</button></div>`
          : `<div class="field"><span>&nbsp;</span><p class="small muted geo-pc">No computador, digite o CEP e o número. Depois, clique em <b>Satélite</b> no mapa e clique na porta exata.</p></div>`}
      </div>
      <div class="grid-rua">
        <label class="field"><span>Rua</span><input class="input" id="${id}-rua" maxlength="120" autocomplete="address-line1" placeholder="Nome da rua"></label>
        <label class="field"><span>Número</span><input class="input" id="${id}-numero" maxlength="12" inputmode="numeric" placeholder="123"></label>
      </div>
      <label class="field"><span>Bairro</span><input class="input" id="${id}-bairro" maxlength="80"></label>
      <div class="grid-rua">
        <label class="field"><span>Cidade</span><input class="input" id="${id}-cidade" maxlength="80" autocomplete="address-level2"></label>
        <label class="field"><span>UF</span><input class="input" id="${id}-uf" maxlength="2" style="text-transform:uppercase" autocomplete="address-level1"></label>
      </div>
      ${opts.complemento === false ? '' : `<label class="field"><span>Complemento <span class="muted">(opcional)</span></span><input class="input" id="${id}-complemento" maxlength="120" placeholder="Apto, bloco, ponto de referência"></label>`}
      <div class="row between" style="margin:2px 0 8px"><b class="small">${opts.mapaTitulo || 'Confirme no mapa'}</b><span class="small muted" id="${id}-st"></span></div>
      <div class="map" id="${id}-map" style="height:${opts.altura || 220}px"></div>
      <p class="small muted" style="margin-top:6px">Toque no mapa ou arraste o pino até a porta. Os campos se preenchem sozinhos.</p>`;
    const $f = (k) => document.getElementById(`${id}-${k}`);
    const KEYS = ['cep', 'rua', 'numero', 'bairro', 'cidade', 'uf', 'complemento'];
    let pos = opts.inicio && opts.inicio.lat != null ? { lat: opts.inicio.lat, lng: opts.inicio.lng } : null;
    // pino confirmado = colocado à mão, GPS preciso ou número achado no mapa. Rua/região aproximada pede ajuste.
    let pinoOk = !!pos, aviso = '';
    let seq = 0;
    const status = (t) => { $f('st').innerHTML = t; };
    const fire = () => opts.onChange && opts.onChange(api);
    const fill = (e) => {
      const ruaMudou = e.rua && e.rua.toLowerCase() !== $f('rua').value.trim().toLowerCase();
      if (ruaMudou) $f('numero').value = e.numero || '';
      else if (e.numero && !$f('numero').value) $f('numero').value = e.numero;
      ['cep', 'rua', 'bairro', 'cidade', 'uf'].forEach(k => { if (e[k]) $f(k).value = e[k]; });
      if (ruaMudou && !e.numero) $f('numero').focus();
    };
    const map = GP.mapPicker($f('map'), pos, async (lat, lng) => {
      pos = { lat, lng }; pinoOk = true; map.precisao(); fire();
      const my = ++seq; status('<span class="spin" style="width:12px;height:12px;border-width:2px"></span> buscando endereço…');
      try {
        const e = await GP.reverse(lat, lng);
        if (my !== seq) return;
        fill(e); status(pinoOk ? '✓ pino marcado — confira se está na porta' : aviso); fire();
        corrigeCorreios(my, e.cep);
      } catch { if (my === seq) status('preencha os campos manualmente'); }
    });

    // Confere rua/cidade nos Correios para pegar o bairro e o CEP oficiais
    let ceps = [], cepsRua = '';
    async function corrigeCorreios(my, cepMapa) {
      const e = api.get();
      const chave = (e.uf + '|' + e.cidade + '|' + e.rua).toLowerCase();
      try {
        if (chave !== cepsRua) { ceps = await GP.viacepRua(e.uf, e.cidade, e.rua); cepsRua = chave; }
        if (my != null && my !== seq) return;
        const x = GP.escolheCep(ceps, e.numero, cepMapa || e.cep, e.rua);
        if (!x) return;
        $f('cep').value = x.cep;
        if (x.bairro) $f('bairro').value = x.bairro;
        if (x.logradouro) $f('rua').value = x.logradouro;
        status(pinoOk ? '✓ endereço conferido nos Correios' : aviso); fire();
      } catch {}
    }
    // centro pode vir como {lat, lng} ou [lat, lng]
    const ctr = Array.isArray(opts.centro) ? { lat: opts.centro[0], lng: opts.centro[1] } : opts.centro;
    if (!pos && ctr && isFinite(ctr.lat) && isFinite(ctr.lng)) map.map.setView([ctr.lat, ctr.lng], 14);

    async function locateFromFields() {
      const e = api.get(); if (!e.rua || !e.cidade) return;
      const my = ++seq; status('<span class="spin" style="width:12px;height:12px;border-width:2px"></span> localizando no mapa…');
      const p = await GP.geocode(e);
      if (my !== seq) return;
      if (p) {
        pos = { lat: p.lat, lng: p.lng }; map.precisao();
        map.set(p.lat, p.lng, true, p.prec === 'aprox' ? 16 : 18);
        pinoOk = p.prec === 'numero';
        status(p.prec === 'numero' ? '✓ número achado — confira o pino na porta'
          : '<b style="color:var(--brand)">⚠ Achei só a rua. Toque no mapa na sua casa (use "Satélite").</b>');
        fire();
      } else { pinoOk = false; status('<b style="color:var(--brand)">⚠ Não achei no mapa. Toque nele na sua casa.</b>'); }
    }
    $f('cep').addEventListener('input', async (ev) => {
      let d = GP.digits(ev.target.value).slice(0, 8);
      ev.target.value = d.length > 5 ? d.slice(0, 5) + '-' + d.slice(5) : d;
      fire();
      if (d.length !== 8) return;
      $f('cepst').innerHTML = '<span class="spin" style="width:14px;height:14px;border-width:2px"></span>';
      try {
        const e = await GP.viacep(d);
        $f('rua').value = e.rua || $f('rua').value; $f('bairro').value = e.bairro || $f('bairro').value;
        $f('cidade').value = e.cidade; $f('uf').value = e.uf;
        $f('cepst').innerHTML = GP.ic('check', 'style="color:var(--ok)"');
        (e.rua ? $f('numero') : $f('rua')).focus();
        fire(); locateFromFields();
      } catch (er) { $f('cepst').innerHTML = ''; GP.toast(er.message, 'err'); }
    });
    $f('numero').addEventListener('change', () => { if (ceps.length > 1) corrigeCorreios(null); locateFromFields(); });
    $f('rua').addEventListener('change', () => { if (!pos) locateFromFields(); });
    KEYS.forEach(k => $f(k) && $f(k).addEventListener('input', fire));
    if ($f('geo')) $f('geo').onclick = async () => {
      const b = $f('geo'), o = b.innerHTML; b.innerHTML = '<span class="spin"></span>Localizando…'; b.disabled = true;
      try {
        const p = await GP.geo({ onProgress: (x) => { b.innerHTML = '<span class="spin"></span>Precisão ±' + x.acc + ' m…'; } });
        if (p.acc > 1000) {
          // sem GPS (computador): é só a região da internet — não mexe no pino nem nos campos
          GP.toast('Este aparelho não tem GPS: a localização veio aproximada pela internet (±' + (p.acc >= 1000 ? Math.round(p.acc / 1000) + ' km' : p.acc + ' m') + '). Digite o CEP e o número ou toque no mapa.', 'err');
          return;
        }
        if (p.acc > 30) {
          // GPS fraco: coloca o pino sem preencher os campos e pede para ajustar
          pos = { lat: p.lat, lng: p.lng }; map.set(p.lat, p.lng, true, 17); map.precisao(p.lat, p.lng, p.acc);
          pinoOk = false; status(aviso = '<b style="color:var(--brand)">⚠ GPS com precisão de ±' + p.acc + ' m. Arraste o pino até a porta.</b>'); fire();
        } else { map.set(p.lat, p.lng); map.precisao(p.lat, p.lng, p.acc); status('✓ localização precisa (±' + p.acc + ' m) — confira o pino'); }
      } catch (e) { GP.toast(e.message, 'err'); }
      b.innerHTML = o; b.disabled = false;
    };
    const api = {
      get() { const o = {}; KEYS.forEach(k => o[k] = $f(k) ? $f(k).value.trim() : ''); o.uf = o.uf.toUpperCase(); o.lat = pos && pos.lat; o.lng = pos && pos.lng; return o; },
      set(e) { KEYS.forEach(k => { if ($f(k)) $f(k).value = e[k] || ''; }); if (e.lat != null) { pos = { lat: e.lat, lng: e.lng }; pinoOk = true; map.set(e.lat, e.lng, true); } fire(); },
      get pos() { return pos; },
      valid() { const e = api.get(); return e.rua.length >= 3 && e.numero.length >= 1 && e.cidade.length >= 2 && !!pos && pinoOk; },
      precisaPino() { return !pos || !pinoOk; },
      camposOk() { const e = api.get(); return e.rua.length >= 3 && e.numero.length >= 1 && e.cidade.length >= 2 && !!pos; },
      texto() { return GP.fmtEnd(api.get()); },
      refresh() { map.refresh(); },
      focus() { $f('cep').focus(); }
    };
    return api;
  };

  // ---------- Horário de funcionamento (horário de Brasília) ----------
  GP.DIAS = ['Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado'];
  GP.DIAS_C = ['dom', 'seg', 'ter', 'qua', 'qui', 'sex', 'sáb'];
  const hm = (t) => { const [h, m] = String(t || '').split(':').map(Number); return isNaN(h) ? null : h * 60 + (m || 0); };
  const fmtHm = (min) => { min = ((min % 1440) + 1440) % 1440; return String(Math.floor(min / 60)).padStart(2, '0') + ':' + String(min % 60).padStart(2, '0'); };
  GP.agoraSP = (d = new Date()) => {
    const f = new Intl.DateTimeFormat('en-US', { timeZone: 'America/Sao_Paulo', weekday: 'short', hour: '2-digit', minute: '2-digit', hour12: false }).formatToParts(d);
    const g = (t) => (f.find(x => x.type === t) || {}).value;
    const dow = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].indexOf(g('weekday'));
    return { dow, min: (Number(g('hour')) % 24) * 60 + Number(g('minute')) };
  };
  GP.intervalos = (h) => {
    const out = [];
    for (let d = 0; d < 7; d++) {
      const x = h && h[d];
      if (!x || !x.aberto) continue;
      const i = hm(x.ini), f = hm(x.fim);
      if (i == null || f == null) continue;
      const s = d * 1440 + i, e = f > i ? d * 1440 + f : (d + 1) * 1440 + f;
      [-10080, 0, 10080].forEach(k => out.push([s + k, e + k]));
    }
    return out.sort((a, b) => a[0] - b[0]);
  };
  // { aberta, texto, curto, cls }
  GP.statusLoja = (l, quando) => {
    if (!l.horario_auto) return l.aberta ? { aberta: true, texto: 'Aberta agora', curto: 'Aberta', cls: 'b-ok' } : { aberta: false, texto: 'Fechada no momento', curto: 'Fechada', cls: 'b-off' };
    if (!l.aberta) return { aberta: false, texto: 'Pedidos pausados pela loja', curto: 'Pausada', cls: 'b-off' };
    const a = GP.agoraSP(quando), W = a.dow * 1440 + a.min, iv = GP.intervalos(l.horarios);
    const cur = iv.find(([s, e]) => s <= W && W < e);
    if (cur) {
      const falta = cur[1] - W;
      return { aberta: true, curto: 'Aberta', cls: falta <= 30 ? 'b-warn' : 'b-ok', texto: falta <= 60 ? `Aberta · fecha em ${falta} min` : `Aberta · fecha às ${fmtHm(cur[1])}`, fechaEm: falta };
    }
    const prox = iv.find(([s]) => s > W);
    if (!prox) return { aberta: false, texto: 'Fechada · sem horário definido', curto: 'Fechada', cls: 'b-off' };
    const diaProx = Math.floor((((prox[0] % 10080) + 10080) % 10080) / 1440), dif = prox[0] - W;
    const quandoTxt = dif < 1440 && diaProx === a.dow ? 'hoje' : diaProx === (a.dow + 1) % 7 && dif < 2880 ? 'amanhã' : GP.DIAS[diaProx].toLowerCase();
    return { aberta: false, curto: 'Fechada', cls: 'b-off', texto: dif <= 60 ? `Fechada · abre em ${dif} min` : `Fechada · abre ${quandoTxt} às ${fmtHm(prox[0])}` };
  };
  // Lista "Seg a Sex 18:00–23:00" para mostrar ao cliente
  GP.resumoHorarios = (h) => {
    const linhas = [];
    for (let d = 0; d < 7; d++) { const x = h && h[d]; linhas.push(x && x.aberto && x.ini && x.fim ? `${x.ini}–${x.fim}` : 'Fechado'); }
    return linhas;
  };

  // ---------- Preço promocional e montagem ----------
  GP.hojeSP = () => new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Sao_Paulo' }).format(new Date());
  GP.emPromo = (p) => p.preco_promo != null && Number(p.preco_promo) < Number(p.preco) && (!p.promo_ate || p.promo_ate >= GP.hojeSP());
  GP.precoAtual = (p) => GP.emPromo(p) ? Number(p.preco_promo) : Number(p.preco);
  GP.descPct = (p) => Math.round((1 - Number(p.preco_promo) / Number(p.preco)) * 100);
  GP.grupos = (p) => Array.isArray(p.grupos) ? p.grupos : [];
  GP.regraGrupo = (g) => {
    const min = Number(g.min) || 0, max = Number(g.max) || 1;
    if (min && min === max) return `Escolha ${min}`;
    if (min) return `Escolha de ${min} a ${max}`;
    return max === 1 ? 'Escolha até 1' : `Escolha até ${max}`;
  };
  // opções escolhidas [{g,o}] -> [{grupo,nome,preco}]
  GP.opcoesEscolhidas = (p, sel) => (sel || []).map(s => {
    const g = GP.grupos(p).find(x => x.id === s.g), o = g && (g.opcoes || []).find(x => x.id === s.o);
    return g && o ? { grupo: g.nome, nome: o.nome, preco: Number(o.preco) || 0 } : null;
  }).filter(Boolean);
  // ---- variações (tamanho, cor, sabor…) e estoque ----
  GP.variacoes = (p) => (p && Array.isArray(p.variacoes)) ? p.variacoes : [];
  GP.varDe = (p, vid) => GP.variacoes(p).find(v => v.id === vid) || null;
  const temNum = (x) => x !== null && x !== undefined && x !== '';
  GP.estoqueDe = (p, vid) => { const vs = GP.variacoes(p); if (vs.length) { const v = GP.varDe(p, vid); return v && temNum(v.estoque) ? Number(v.estoque) : null; } return temNum(p.estoque) ? Number(p.estoque) : null; };
  GP.esgotado = (p) => { const vs = GP.variacoes(p); return vs.length ? vs.every(v => temNum(v.estoque) && Number(v.estoque) <= 0) : temNum(p.estoque) && Number(p.estoque) <= 0; };
  GP.precoBase = (p, vid) => { const v = GP.varDe(p, vid); return v && temNum(v.preco) ? Number(v.preco) : GP.precoAtual(p); };
  GP.precoMinVar = (p) => { const vs = GP.variacoes(p).filter(v => !(temNum(v.estoque) && Number(v.estoque) <= 0)); return vs.length ? Math.min(...vs.map(v => GP.precoBase(p, v.id))) : GP.precoAtual(p); };
  GP.precoItem = (p, sel, vid) => GP.precoBase(p, vid) + GP.opcoesEscolhidas(p, sel).reduce((t, o) => t + o.preco, 0);
  // Vendido por peso (SQL v32): preço do quilo × gramas, arredondado ao centavo mais próximo (igual ao servidor)
  GP.porPeso = (p) => !!p && p.vende_por === 'kg';
  GP.pesoMin = (p) => Math.max(10, Number(p && p.peso_min) || 100);
  GP.pesoPasso = (p) => Math.max(10, Number(p && p.peso_passo) || 100);
  GP.fmtPeso = (g) => g >= 1000 ? (g / 1000).toLocaleString('pt-BR', { maximumFractionDigits: 3 }) + ' kg' : g + ' g';
  GP.precoPeso = (p, g, sel) => {
    const base = GP.precoBase(p), cents = Math.round(Math.round(base * 100) * g / 1000);
    return cents / 100 + GP.opcoesEscolhidas(p, sel).reduce((t, o) => t + o.preco, 0);
  };
  GP.txtOpcoes = (ops) => (ops || []).map(o => o.nome + (Number(o.preco) ? ` (+${GP.brl(o.preco)})` : '')).join(', ');

  GP.descCupom = (c) => c.tipo === 'frete' ? 'Entrega grátis' : c.tipo === 'percentual' ? `${Number(c.valor)}% OFF` : `${GP.brl(c.valor)} OFF`;
  GP.regrasCupom = (c) => [Number(c.minimo) ? 'pedidos a partir de ' + GP.brl(c.minimo) : 'em qualquer pedido', c.validade ? 'até ' + c.validade.split('-').reverse().join('/') : '', c.por_cliente === 1 ? '1 por cliente' : '', c.restantes != null && c.restantes <= 20 ? `restam ${c.restantes}` : ''].filter(Boolean).join(' · ');

  GP.STATUS = {
    novo: { t: 'Recebido', c: 'b-brand', d: 'A loja recebeu seu pedido' },
    preparando: { t: 'Em preparo', c: 'b-warn', d: 'Seu pedido está sendo preparado' },
    saiu: { t: 'Saiu para entrega', c: 'b-ok', d: 'O entregador está a caminho' },
    entregue: { t: 'Entregue', c: 'b-off', d: 'Pedido entregue. Bom apetite!' },
    cancelado: { t: 'Cancelado', c: 'b-bad', d: 'Este pedido foi cancelado' }
  };
  // status com texto certo para retirada
  GP.statusTxt = (p, s) => {
    s = s || p.status;
    if (p.tipo_entrega === 'retirada') {
      if (s === 'saiu') return { t: 'Pronto para retirar', c: 'b-ok', d: 'Pode vir buscar na loja' };
      if (s === 'entregue') return { t: 'Retirado', c: 'b-off', d: 'Pedido retirado. Bom apetite!' };
    }
    if (p.tipo_entrega === 'envio') {
      if (s === 'preparando') return { t: 'Separando', c: 'b-warn', d: 'A loja está separando e embalando' };
      if (s === 'saiu') return { t: 'Enviado', c: 'b-brand', d: 'Postado na transportadora' };
      if (s === 'entregue') return { t: 'Entregue', c: 'b-off', d: 'Pedido entregue' };
    }
    return GP.STATUS[s];
  };
  GP.estrelas = (n, tam) => { const v = Math.round(Number(n) || 0); return `<span class="stars" style="${tam ? 'font-size:' + tam : ''}">${'★'.repeat(v)}<span class="off">${'★'.repeat(5 - v)}</span></span>`; };
  GP.mapsLink = (lat, lng) => `https://www.google.com/maps/search/?api=1&query=${lat},${lng}`;
  GP.PAG = { mp: 'Online (Mercado Pago)', pix: 'Pix', debito: 'Cartão de débito (na entrega)', credito: 'Cartão de crédito (na entrega)', dinheiro: 'Dinheiro (na entrega)' };

  // ---------- Comprovante para impressora térmica ----------
  GP.cupom = (p, L, pcfg = {}) => {
    pcfg = Object.assign({ largura: '80', vias: 'entrega' }, pcfg);
    const e = GP.esc, brl = GP.brl, km = GP.km, dt = new Date(p.criado_em);
    const itensArr = p.itens || p.ff_pedido_itens || [];
    const data = dt.toLocaleDateString('pt-BR') + ' ' + GP.hora(dt);
    const linha = '<div class="hr"></div>';
    const rota = `https://www.google.com/maps/dir/?api=1&destination=${p.lat},${p.lng}`;
    const qr = GP.qr(rota);
    const troco = p.pagamento === 'dinheiro' && Number(p.troco_para) > 0 ? Number(p.troco_para) - Number(p.total) : 0;
    const pag = p.pagamento === 'mp'
      ? `<div class="box">PAGO ONLINE — MERCADO PAGO<br><small>NÃO COBRAR</small></div>`
      : p.pagamento === 'pix'
      ? `<div class="box">PIX — JÁ PAGO<br><small>comprovante anexado · NÃO COBRAR</small></div>`
      : p.pagamento === 'dinheiro'
        ? `<div class="box">COBRAR EM DINHEIRO<br><span class="big">${brl(p.total)}</span><br>${troco > 0 ? `Cliente paga com ${brl(p.troco_para)}<br><span class="big">LEVAR TROCO: ${brl(troco)}</span>` : 'Sem troco (valor certo)'}</div>`
        : `<div class="box">COBRAR NA ENTREGA<br>${p.pagamento === 'debito' ? 'CARTÃO DE DÉBITO' : 'CARTÃO DE CRÉDITO'}<br><span class="big">${brl(p.total)}</span><br><small>levar maquininha</small></div>`;
    const ops = (i) => (i.opcoes || []).map(o => `<div class="obs">+ ${e(o.nome)}${Number(o.preco) ? ' ' + brl(o.preco) : ''}</div>`).join('');
    const itens = itensArr.map(i => `<div class="it"><span><b>${i.qtd}x</b> ${e(i.nome)}</span><span>${brl(i.preco * i.qtd)}</span></div>${ops(i)}${i.obs ? `<div class="obs">&gt; ${e(i.obs)}</div>` : ''}`).join('');
    const viaEntrega = `<section class="via">
      <div class="c"><div class="loja">${e(L.nome)}</div>${L.cnpj ? `<div>CNPJ ${e(GP.fmtCnpj(L.cnpj))}</div>` : ''}${L.telefone ? `<div>${e(L.telefone)}</div>` : ''}</div>
      ${linha}<div class="c"><div class="big">PEDIDO #${p.numero}</div><div>${data}</div><div class="tag">VIA DA ENTREGA</div></div>${linha}
      <div><b>CLIENTE:</b> ${e(p.cliente_nome)}</div><div><b>TEL:</b> ${e(p.cliente_telefone)}</div>
      ${p.tipo_entrega === 'retirada' ? `${linha}<div class="box">RETIRADA NO LOCAL<br><small>o cliente vem buscar</small></div>` : `${linha}<div><b>ENTREGAR EM:</b></div><div class="end">${e(p.endereco)}</div>${p.complemento ? `<div class="end">${e(p.complemento)}</div>` : ''}
      <div>Distância: ${km(p.distancia_km)}${p.entregador_nome ? ` · Entregador: ${e(p.entregador_nome)}` : ''}</div>`}
      ${linha}${itens}${linha}
      <div class="it"><span>Subtotal</span><span>${brl(p.subtotal)}</span></div>
      <div class="it"><span>Taxa de entrega</span><span>${brl(p.taxa_entrega)}</span></div>
      ${Number(p.desconto) ? `<div class="it"><span>Desconto${p.cupom ? ' (' + e(p.cupom) + ')' : ''}</span><span>-${brl(p.desconto)}</span></div>` : ''}
      <div class="it tot"><span>TOTAL</span><span>${brl(p.total)}</span></div>
      ${linha}${pag}
      ${p.observacao ? `${linha}<div><b>OBS:</b> ${e(p.observacao)}</div>` : ''}
      ${qr && p.tipo_entrega !== 'retirada' ? `${linha}<div class="c"><div class="qr">${qr}</div><small>Aponte a câmera para abrir a rota</small></div>` : ''}
      ${linha}<div class="c"><small>GoPedido · goscripts.com.br/delivery</small></div>
    </section>`;
    const viaCozinha = `<section class="via">
      <div class="c"><div class="tag">COZINHA${p.tipo_entrega === 'retirada' ? ' · RETIRADA' : ''}</div><div class="big">PEDIDO #${p.numero}</div><div>${data}</div><div>${e(p.cliente_nome)}</div></div>${linha}
      ${itensArr.map(i => `<div class="kit"><b>${i.qtd}x</b> ${e(i.nome)}</div>${(i.opcoes || []).map(o => `<div class="kobs">+ ${e(o.nome)}</div>`).join('')}${i.obs ? `<div class="kobs">&gt; ${e(i.obs)}</div>` : ''}`).join('')}
      ${p.observacao ? `${linha}<div class="kobs">OBS: ${e(p.observacao)}</div>` : ''}${linha}
      <div class="box">${p.pagamento === 'mp' ? 'PAGO ONLINE' : p.pagamento === 'pix' ? 'PIX — JÁ PAGO' : p.pagamento === 'dinheiro' ? `DINHEIRO · ${brl(p.total)}${troco > 0 ? ` · TROCO ${brl(troco)}` : ''}` : `COBRAR NA ENTREGA · ${p.pagamento === 'debito' ? 'DÉBITO' : 'CRÉDITO'} · ${brl(p.total)}`}</div>
    </section>`;
    const vias = pcfg.vias === 'entrega' ? viaEntrega : pcfg.vias === 'cozinha' ? viaCozinha : viaEntrega + viaCozinha;
    const W = pcfg.largura === '58' ? 48 : 72, F = pcfg.largura === '58' ? 11 : 12.5;
    const html = `<!DOCTYPE html><html><head><meta charset="utf-8"><title>Pedido #${p.numero}</title><style>
      @page{size:${pcfg.largura}mm auto;margin:0}
      *{box-sizing:border-box;margin:0;padding:0}
      body{width:${W}mm;margin:0 auto;padding:3mm 0;font-family:'Courier New',ui-monospace,monospace;font-size:${F}px;line-height:1.3;color:#000;font-weight:600}
      .via{page-break-after:always;break-after:page;padding-bottom:6mm}
      .via:last-child{page-break-after:auto;break-after:auto}
      .c{text-align:center}.loja{font-size:1.35em;font-weight:900}
      .big{font-size:1.5em;font-weight:900}
      .tag{display:inline-block;border:2px solid #000;padding:1px 8px;margin-top:3px;font-weight:900;letter-spacing:.08em}
      .hr{border-top:1px dashed #000;margin:5px 0}
      .it{display:flex;justify-content:space-between;gap:6px}.it span:last-child{white-space:nowrap}
      .tot{font-size:1.3em;font-weight:900;margin-top:2px}
      .obs{padding-left:10px;font-style:italic}
      .end{font-size:1.1em;font-weight:800}
      .box{border:2px solid #000;padding:5px;text-align:center;font-weight:900}
      .qr{width:30mm;height:30mm;margin:4px auto}.qr svg{width:100%;height:100%}
      .kit{font-size:1.45em;font-weight:900;margin:4px 0}.kobs{font-size:1.2em;padding-left:10px;font-weight:800}
      small{font-size:.85em;font-weight:500}
      @media screen{body{background:#fff;box-shadow:0 0 0 1px #ddd;margin:10px auto;padding:3mm}}
    </style></head><body>${vias}<script>window.onload=function(){setTimeout(function(){window.print()},250)};window.onafterprint=function(){window.close()};<\/script></body></html>`;
    return html;
  };
  GP.imprimirCupom = (html, janela) => {
    const w = janela || window.open('', '_blank');
    if (!w) return GP.toast('Libere as janelas pop-up para imprimir.', 'err');
    w.document.open(); w.document.write(html); w.document.close();
  };
  GP.troco = (p) => p.pagamento === 'dinheiro' && Number(p.troco_para) > 0 ? Number(p.troco_para) - Number(p.total) : 0;
  GP.pagTexto = (p) => {
    if (p.pagamento === 'pix') return 'Pix · já pago';
    if (p.pagamento === 'mp') return { aprovado: 'Pago online (Mercado Pago)', estornado: 'Online · valor devolvido', recusado: 'Online · pagamento recusado' }[p.mp_status] || 'Online · aguardando pagamento';
    if (p.pagamento === 'dinheiro') { const t = GP.troco(p); return `Dinheiro · ${t > 0 ? `troco para ${GP.brl(p.troco_para)} (levar ${GP.brl(t)})` : 'sem troco'}`; }
    return p.pagamento === 'debito' ? 'Débito na entrega' : 'Crédito na entrega';
  };


  // ---------- tipos de loja ----------
  GP.TIPOS = [
    { id: 'restaurante', nome: 'Restaurante e lanchonete', curto: 'Restaurantes', ex: ['Burger do Zé', 'Hambúrgueres artesanais, porções e milkshakes.'], ic: 'bag', obsItem: 'Ex.: sem cebola, ponto da carne…', obsPedido: 'Ex.: troco, interfone quebrado…', desc: 'Lanches, pizzas, açaí, marmitas, doces' },
    { id: 'mercado', nome: 'Mercado e conveniência', curto: 'Mercados', ex: ['Mercadinho Bom Preço', 'Mercearia, hortifrúti, frios e bebidas geladas.'], ic: 'cart', obsItem: 'Ex.: banana mais verde, marca preferida…', obsPedido: 'Ex.: pode trocar por similar se faltar, interfone…', desc: 'Mercearia, hortifrúti, padaria, conveniência' },
    { id: 'farmacia', nome: 'Farmácia', curto: 'Farmácias', ex: ['Farmácia Saúde', 'Medicamentos, higiene, beleza e perfumaria.'], ic: 'pill', obsItem: 'Ex.: prefiro genérico, apresentação em gotas…', obsPedido: 'Ex.: troco, portão azul…', desc: 'Farmácia, drogaria, perfumaria' },
    { id: 'pet', nome: 'Pet shop', curto: 'Pet shops', ex: ['Pet Feliz', 'Rações, petiscos, brinquedos e acessórios.'], ic: 'paw', obsItem: 'Ex.: sabor frango, tamanho M…', obsPedido: 'Ex.: troco, cuidado com o cachorro…', desc: 'Ração, acessórios, casa de ração' },
    { id: 'bebidas', nome: 'Bebidas e adega', curto: 'Bebidas', ex: ['Adega do Centro', 'Cervejas, destilados, gelo, água e gás.'], ic: 'wine', obsItem: 'Ex.: bem gelada, marca preferida…', obsPedido: 'Ex.: troco, interfone quebrado…', desc: 'Adega, distribuidora, gelo, água e gás' },
    { id: 'variedades', nome: 'Variedades', curto: 'Variedades', ex: ['Loja da Ana', 'Roupas, presentes, utilidades e eletrônicos.'], ic: 'box', obsItem: 'Ex.: cor preferida, embrulhar para presente…', obsPedido: 'Ex.: é presente, não mandar nota com o preço…', desc: 'Roupas, presentes, eletrônicos, utilidades. Pode enviar para outras cidades.' },
    { id: 'agenda', nome: 'Agendamentos', curto: 'Agendar', ex: ['Barbearia do Zé', 'Corte, barba e sobrancelha com hora marcada.'], ic: 'calendar', obsItem: '', obsPedido: '', desc: 'Salão, barbearia, manicure, estética: o cliente marca horário online', agenda: true },
    { id: 'assinatura', nome: 'Assinaturas', curto: 'Assinaturas', ex: ['Clube do Gamer', 'Planos mensais com renovação pelo e-mail.'], ic: 'star', obsItem: '', obsPedido: '', desc: 'Planos mensais, clubes, mensalidades e códigos digitais: cobrança e lembrete automáticos', assin: true },
    { id: 'outros', nome: 'Outros', curto: 'Outros', ex: ['Minha Loja', 'Conte o que você vende.'], ic: 'grid', obsItem: 'Ex.: algum detalhe sobre este item…', obsPedido: 'Ex.: troco, ponto de referência…', desc: 'Qualquer outro tipo de loja' }
  ];
  GP.tipo = (id) => GP.TIPOS.find(t => t.id === id) || GP.TIPOS[0];
  GP.ehAgenda = (l) => !!l && l.tipo === 'agenda';
  GP.ehAssin = (l) => !!l && l.tipo === 'assinatura';
  // Busca de todo o sistema: ignora acento, maiúscula, hífen e ordem das palavras ("bacon" acha "X-Bacon"; "acai" acha "Açaí")
  GP.semAcento = (t) => String(t == null ? '' : t).normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();
  GP.acha = (texto, q) => {
    const pal = GP.semAcento(q).replace(/[^a-z0-9]+/g, ' ').trim().split(' ').filter(Boolean);
    if (!pal.length) return true;
    const t = GP.semAcento(texto).replace(/[^a-z0-9]+/g, ' '), junto = t.replace(/ /g, '');
    return pal.every(w => t.includes(w) || junto.includes(w));
  };
  // Situação de um pagamento (planos e assinaturas): Pix não pago em 30 min aparece como expirado, igual ao Mercado Pago
  GP.statusPag = (h) => {
    if (h.status === 'pendente' && h.metodo === 'pix' && Date.now() - new Date(h.criado_em).getTime() > 31 * 60e3) return ['expirado', 'Expirado'];
    if (h.status === 'pendente') return ['pendente', h.metodo === 'cartao' ? 'Em análise' : 'Aguardando'];
    return [h.status, { aprovado: 'Pago', recusado: 'Recusado', estornado: 'Devolvido' }[h.status] || h.status];
  };
  // Gerenciador de códigos digitais (produto ou plano de assinatura): colar vários, ver os livres, apagar.
  GP.codigos = {
    async abrir(sb, box, o) {
      const campo = o.produto_id ? 'produto_id' : 'plano_id', id = o.produto_id || o.plano_id;
      const desenhar = async () => {
        const { data, error } = await sb.from('ff_codigos').select('id, codigo, usado_em').eq(campo, id).order('criado_em').limit(3000);
        if (error) { box.innerHTML = `<div class="warnline">${GP.esc(/ff_codigos|relation|schema/i.test(error.message || '') ? 'Falta rodar o SQL v33 no Supabase.' : GP.err(error))}</div>`; return; }
        const livres = (data || []).filter(c => !c.usado_em), usados = (data || []).length - livres.length;
        if (o.aoMudar) o.aoMudar(livres.length);
        const mask = (c) => c.length <= 6 ? c : c.slice(0, 4) + '•••' + c.slice(-3);
        box.innerHTML = `<div class="codbox">
          <div class="row between" style="gap:8px;margin-bottom:8px"><b class="${livres.length < 3 ? 'cod-pouco' : ''}">${livres.length} código${livres.length === 1 ? '' : 's'} disponíve${livres.length === 1 ? 'l' : 'is'}</b><span class="small muted">${usados} já entregue${usados === 1 ? '' : 's'}</span></div>
          <textarea class="input" rows="3" placeholder="Cole os códigos aqui, um por linha" data-cod-tx></textarea>
          <button type="button" class="btn btn-soft btn-sm" data-cod-add style="margin-top:6px">${GP.ic('plus')}Adicionar códigos</button>
          ${livres.length ? `<details style="margin-top:10px"><summary class="small" style="cursor:pointer">Ver os disponíveis</summary><div class="codlist">${livres.slice(0, 300).map(c => `<div><code>${GP.esc(mask(c.codigo))}</code><button type="button" class="icon-btn" data-cod-del="${c.id}" aria-label="Apagar">${GP.ic('trash')}</button></div>`).join('')}${livres.length > 300 ? `<p class="small muted">… e mais ${livres.length - 300}</p>` : ''}</div></details>` : ''}
          <p class="small muted" style="margin:8px 0 0">Cada código é entregue uma vez só, por e-mail, assim que o pagamento é aprovado.${o.produto_id ? ' O estoque do produto acompanha a quantidade de códigos.' : ''}</p></div>`;
        box.querySelector('[data-cod-add]').onclick = async (e) => {
          const lin = [...new Set(box.querySelector('[data-cod-tx]').value.split(/\r?\n/).map(x => x.trim()).filter(Boolean))];
          if (!lin.length) return GP.toast('Cole pelo menos um código.', 'err');
          if (lin.some(x => x.length > 500)) return GP.toast('Cada código pode ter até 500 caracteres.', 'err');
          const ja = new Set((data || []).map(c => c.codigo)), novos = lin.filter(x => !ja.has(x));
          if (!novos.length) return GP.toast('Esses códigos já estavam cadastrados.', 'err');
          const b = e.currentTarget; b.disabled = true; b.innerHTML = '<span class="spin"></span>';
          for (let i = 0; i < novos.length; i += 200) {
            const { error: er } = await sb.from('ff_codigos').insert(novos.slice(i, i + 200).map(c => ({ loja_id: o.loja_id, [campo]: id, codigo: c })));
            if (er) { b.disabled = false; GP.toast(GP.err(er), 'err'); return desenhar(); }
          }
          GP.toast(`${novos.length} código${novos.length > 1 ? 's adicionados' : ' adicionado'}${lin.length > novos.length ? ` (${lin.length - novos.length} repetido${lin.length - novos.length > 1 ? 's' : ''} ignorado${lin.length - novos.length > 1 ? 's' : ''})` : ''}.`, 'ok');
          desenhar();
        };
        box.querySelectorAll('[data-cod-del]').forEach(b => { b.onclick = async () => {
          const { error: er } = await sb.from('ff_codigos').delete().eq('id', b.dataset.codDel);
          if (er) return GP.toast(GP.err(er), 'err');
          desenhar();
        }; });
      };
      await desenhar();
    }
  };

  // ---------- Cor da loja ----------
  // O lojista escolhe só a cor da marca. Aqui ela é ajustada para sempre dar leitura:
  // escurece cor clara demais (texto/preço em fundo branco) e decide texto branco ou preto nos botões.
  GP.COR_PADRAO = '#F2451C';
  GP.CORES = ['#F2451C', '#E11D48', '#DB2777', '#9333EA', '#4F46E5', '#2563EB', '#0891B2', '#059669', '#16A34A', '#65A30D', '#CA8A04', '#EA580C', '#92400E', '#334155', '#111827'];
  const hexRgb = (h) => { const n = parseInt(String(h).replace('#', ''), 16); return [n >> 16 & 255, n >> 8 & 255, n & 255]; };
  const rgbHex = (r, g, b) => '#' + [r, g, b].map(x => Math.max(0, Math.min(255, Math.round(x))).toString(16).padStart(2, '0')).join('').toUpperCase();
  const lum = ([r, g, b]) => { const f = (c) => { c /= 255; return c <= .03928 ? c / 12.92 : Math.pow((c + .055) / 1.055, 2.4); }; return .2126 * f(r) + .7152 * f(g) + .0722 * f(b); };
  GP.contraste = (a, b) => { const x = lum(hexRgb(a)), y = lum(hexRgb(b)); return (Math.max(x, y) + .05) / (Math.min(x, y) + .05); };
  const misturar = (h, alvo, t) => { const a = hexRgb(h), b = hexRgb(alvo); return rgbHex(a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t); };
  GP.paletaCor = (cor) => {
    let c = /^#[0-9a-f]{6}$/i.test(cor || '') ? cor.toUpperCase() : GP.COR_PADRAO;
    // precisa aparecer em fundo branco (preço, links) e com texto branco por cima: escurece até ter contraste 3,2:1
    for (let i = 0; i < 14 && GP.contraste(c, '#FFFFFF') < 3.2; i++) c = misturar(c, '#000000', .1);
    const texto = '#FFFFFF';   // depois do ajuste, texto branco sempre lê bem nos botões
    return { cor: c, escura: misturar(c, '#000000', .16), suave: misturar(c, '#FFFFFF', .88), texto };
  };
  GP.aplicarCor = (cor) => {
    if (!cor) return;
    const p = GP.paletaCor(cor), r = document.documentElement.style;
    r.setProperty('--brand', p.cor); r.setProperty('--brand-2', p.escura); r.setProperty('--brand-soft', p.suave); r.setProperty('--brand-ink', p.texto);
    const m = document.querySelector('meta[name="theme-color"]'); if (m) m.setAttribute('content', p.cor);
  };
  // Cor que mais aparece no logo (sem branco, preto e cinzas). Não usa IA: lê os pixels da imagem.
  GP.corDoLogo = (src) => new Promise((ok) => {
    if (!src) return ok(null);
    const img = new Image(); img.crossOrigin = 'anonymous';
    img.onload = () => {
      try {
        const N = 72, cv = document.createElement('canvas'); cv.width = N; cv.height = N;
        const cx = cv.getContext('2d', { willReadFrequently: true }); cx.drawImage(img, 0, 0, N, N);
        const d = cx.getImageData(0, 0, N, N).data, caixas = {};
        for (let i = 0; i < d.length; i += 4) {
          const r = d[i], g = d[i + 1], b = d[i + 2], a = d[i + 3];
          if (a < 160) continue;
          const mx = Math.max(r, g, b), mn = Math.min(r, g, b), l = (mx + mn) / 2, sat = mx === mn ? 0 : (mx - mn) / (255 - Math.abs(mx + mn - 255));
          if (sat < .28 || l < 28 || l > 235) continue;   // cinza, preto ou branco
          let h = 0; if (mx !== mn) { h = mx === r ? ((g - b) / (mx - mn)) % 6 : mx === g ? (b - r) / (mx - mn) + 2 : (r - g) / (mx - mn) + 4; h = Math.round(h * 60 + 360) % 360; }
          const k = Math.floor(h / 15), peso = sat * (1 - Math.abs(l - 128) / 160);
          const c = caixas[k] || (caixas[k] = { p: 0, r: 0, g: 0, b: 0 });
          c.p += peso; c.r += r * peso; c.g += g * peso; c.b += b * peso;
        }
        const best = Object.values(caixas).sort((x, y) => y.p - x.p)[0];
        ok(best && best.p > 4 ? rgbHex(best.r / best.p, best.g / best.p, best.b / best.p) : null);
      } catch { ok(null); }   // imagem de outro site sem permissão de leitura
    };
    img.onerror = () => ok(null);
    img.src = src;
  });
  // Horário de Brasília (sem horário de verão desde 2019): data "AAAA-MM-DD" + minutos → Date
  GP.dataSP = (d = new Date()) => new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Sao_Paulo', year: 'numeric', month: '2-digit', day: '2-digit' }).format(d);
  GP.emSP = (dia, min) => new Date(`${dia}T${String(Math.floor(min / 60)).padStart(2, '0')}:${String(min % 60).padStart(2, '0')}:00-03:00`);
  GP.horaSP = (d) => new Intl.DateTimeFormat('pt-BR', { timeZone: 'America/Sao_Paulo', hour: '2-digit', minute: '2-digit' }).format(new Date(d));
  GP.diaSP = (d, op = { weekday: 'long', day: '2-digit', month: 'long' }) => new Intl.DateTimeFormat('pt-BR', { timeZone: 'America/Sao_Paulo', ...op }).format(new Date(d));
  GP.minDe = (t) => { const [h, m] = String(t || '').split(':').map(Number); return isNaN(h) ? null : h * 60 + (m || 0); };
  // Horários livres de um profissional num dia: [{min, ini: Date, fim: Date}]
  GP.slotsProf = (prof, dia, dur, passo, ocup, minIni) => {
    const dow = new Date(dia + 'T12:00:00-03:00').getUTCDay();
    const h = (prof.horarios || {})[dow] || (prof.horarios || {})[String(dow)];
    if (!h || !h.aberto) return [];
    const ini = GP.minDe(h.ini), fim0 = GP.minDe(h.fim); if (ini == null || fim0 == null) return [];
    const fim = fim0 === 0 ? 1440 : fim0;
    const pi = GP.minDe(h.pausa_ini), pf = GP.minDe(h.pausa_fim);
    const out = [];
    for (let t = ini; t + dur <= fim; t += passo) {
      if (pi != null && pf != null && pf > pi && t < pf && t + dur > pi) continue;
      const a = GP.emSP(dia, t), b = new Date(a.getTime() + dur * 60000);
      if (minIni && a < minIni) continue;
      if ((ocup || []).some(o => o.profissional_id === prof.id && new Date(o.inicio) < b && new Date(o.fim) > a)) continue;
      out.push({ min: t, ini: a, fim: b });
    }
    return out;
  };

  // ---------- tempo real: escuta "toques" do banco num canal e chama aoMudar ----------
  // Devolve { parar(), ativo() }. Se o Realtime não estiver disponível, ativo() fica false e a tela usa a conferência de reserva.
  GP.ouvir = (sb, canal, aoMudar) => {
    let ch = null, ok = false, deb = null;
    if (sb && sb.channel) {
      try {
        ch = sb.channel(canal).on('broadcast', { event: 'mudou' }, () => { clearTimeout(deb); deb = setTimeout(aoMudar, 400); })
          .subscribe((st) => { const novo = st === 'SUBSCRIBED'; if (novo && !ok) aoMudar(); ok = novo; });
      } catch { ch = null; }
    }
    return { ativo: () => ok, parar: () => { ok = false; if (ch) { try { sb.removeChannel(ch); } catch {} ch = null; } } };
  };

  // ---------- olho para ver a senha (em todos os campos de senha) ----------
  GP.olhoSenha = (raiz = document) => {
    raiz.querySelectorAll('input[type="password"]:not([data-olho])').forEach(inp => {
      inp.dataset.olho = '1';
      const w = document.createElement('span'); w.className = 'pwd';
      inp.parentNode.insertBefore(w, inp); w.appendChild(inp);
      const b = document.createElement('button');
      b.type = 'button'; b.className = 'pwd-eye'; b.tabIndex = -1; b.setAttribute('aria-label', 'Mostrar senha'); b.innerHTML = GP.ic('eye');
      b.onclick = (e) => {
        e.preventDefault();
        const ver = inp.type === 'password'; inp.type = ver ? 'text' : 'password';
        b.innerHTML = GP.ic(ver ? 'eyeoff' : 'eye'); b.setAttribute('aria-label', ver ? 'Esconder senha' : 'Mostrar senha');
      };
      w.appendChild(b);
    });
  };
  // ---------- rodapé "feito pela GoScripts" em todas as páginas ----------
  // Entrada suave dos blocos ao rolar a página. Sem JavaScript ou com "reduzir movimento", tudo aparece normal.
  GP.revelar = (seletor) => {
    if (!('IntersectionObserver' in window) || matchMedia('(prefers-reduced-motion:reduce)').matches) return;
    const io = new IntersectionObserver((es) => es.forEach(e => { if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); } }), { rootMargin: '0px 0px -8% 0px', threshold: .08 });
    document.querySelectorAll(seletor).forEach(el => {
      if (el.classList.contains('rv')) return;
      const i = [...el.parentElement.children].indexOf(el);
      el.style.transitionDelay = Math.min(i, 5) * 70 + 'ms'; el.classList.add('rv'); io.observe(el);
    });
  };

  // Rodapé completo das páginas de apresentação e dos documentos (mesmo desenho do início)
  GP.rodapeSite = () => {
    if (document.querySelector('.site-foot')) return;
    const f = document.createElement('footer'); f.className = 'site-foot';
    f.innerHTML = `<div class="wrap"><div class="sf-top">
      <div class="sf-brand"><a class="logo" href="./"><b>${GP.ic('bag')}</b><span>Go<em>Pedido</em></span></a>
        <p>Delivery na sua região e envio para todo o Brasil, com lojas que vendem sem pagar comissão por pedido.</p></div>
      <nav class="sf-col" aria-label="Para quem compra"><h2>Para quem compra</h2>
        <a href="./">Ver as lojas</a><a href="./#como">Como funciona</a><a href="./#duvidas">Perguntas frequentes</a><a href="conta.html">Minha conta</a></nav>
      <nav class="sf-col" aria-label="Para lojistas"><h2>Para lojistas</h2>
        <a href="lojistas.html">Vender no GoPedido</a><a href="lojistas.html#planos">Planos e preços</a><a href="painel.html?criar=1">Criar minha loja</a><a href="painel.html">Entrar no painel</a></nav>
      <nav class="sf-col" aria-label="Ajuda e documentos"><h2>Ajuda e documentos</h2>
        <a href="${GP.wa(GP.WHATS, 'Olá! Vim pelo GoPedido e gostaria de falar com vocês.')}" target="_blank" rel="noopener">WhatsApp <span class="nw">(19) 98828-3178</span></a>
        <a href="termos.html">Termos de Uso</a><a href="privacidade.html">Política de Privacidade</a><a href="entregas.html">Entregas, Trocas e Reembolsos</a></nav>
    </div><div class="sf-bot"><span>© 2026 GoPedido. As vendas e entregas são de responsabilidade de cada loja.</span>
      <a class="sf-by" href="https://goscripts.com.br" target="_blank" rel="noopener">Desenvolvido por <img src="../logo-192.png" alt="" width="20" height="20"><b>GoScripts</b></a></div></div>`;
    document.body.appendChild(f);
  };

  GP.rodape = () => {
    if (document.querySelector('.gs-foot') || document.body.dataset.semRodape != null) return;
    const f = document.createElement('footer'); f.className = 'gs-foot';
    const zap = GP.wa(GP.WHATS, 'Olá! Vim pelo GoPedido e gostaria de falar com vocês.');
    f.innerHTML = `<a class="gs-zap" href="${zap}" target="_blank" rel="noopener">${GP.ic('chat')}<span>Fale conosco no WhatsApp</span></a>
      <a class="gs-by" href="https://goscripts.com.br" target="_blank" rel="noopener"><span>Desenvolvido por</span><img src="../logo-192.png" alt="" width="22" height="22"><b>GoScripts</b></a>
      <span class="gs-legal"><a href="termos.html">Termos de Uso</a> · <a href="privacidade.html">Privacidade</a> · <a href="entregas.html">Entregas e reembolsos</a></span>`;
    document.body.appendChild(f);
    // Páginas com tela cheia (login do painel) marcam onde o rodapé deve aparecer
    document.querySelectorAll('[data-rodape-aqui]').forEach(el => el.appendChild(f.cloneNode(true)));
  };

  // ---------- Entrar com Google (precisa ligar o Google em Supabase → Authentication → Providers) ----------
  GP.loginGoogle = async (sb, voltarPara) => {
    // confere antes se o Google já foi ligado no Supabase (senão o navegador cai numa página de erro)
    try {
      const r = await fetch(cfg.supabaseUrl + '/auth/v1/settings', { headers: { apikey: cfg.supabaseKey } });
      const j = await r.json();
      if (j && j.external && j.external.google === false) return GP.toast('O login com Google ainda não foi ligado. Use e-mail e senha por enquanto.', 'err');
    } catch (_) {}
    const { error } = await sb.auth.signInWithOAuth({ provider: 'google', options: { redirectTo: voltarPara || location.href.split('#')[0], queryParams: { prompt: 'select_account' } } });
    if (error) GP.toast(/provider is not enabled|Unsupported provider/i.test(error.message || '') ? 'O login com Google ainda não foi ligado no Supabase.' : GP.err(error), 'err');
  };
  GP.botaoGoogle = (texto = 'Continuar com Google') => `<button type="button" class="btn btn-google btn-block" data-google>${GP.ic('user')}<span>${GP.esc(texto)}</span></button>`;

  // ---------- Aplicativo (instalar) e avisos no celular/computador (push) ----------
  GP.app = (() => {
    const ua = navigator.userAgent || '';
    const ios = /iphone|ipad|ipod/i.test(ua) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
    const android = /android/i.test(ua);
    const macSafari = !ios && /Macintosh/.test(ua) && /Safari/.test(ua) && !/Chrome|Chromium|Edg|Firefox|OPR/.test(ua);
    const firefox = /Firefox|FxiOS/.test(ua);
    const celular = ios || android;
    let pedido = null; const ouvintes = new Set();
    const avisa = () => ouvintes.forEach(f => { try { f(); } catch (_) {} });
    const instalado = () => { try { return matchMedia('(display-mode: standalone)').matches || navigator.standalone === true; } catch (_) { return false; } };
    window.addEventListener('beforeinstallprompt', (e) => { e.preventDefault(); pedido = e; avisa(); });
    window.addEventListener('appinstalled', () => { pedido = null; avisa(); });
    let reg = null;
    const sw = () => {
      if (!('serviceWorker' in navigator)) return Promise.resolve(null);
      if (!reg) reg = navigator.serviceWorker.register('sw.js').then(() => navigator.serviceWorker.ready).catch(() => null);
      return reg;
    };
    if (document.querySelector('link[rel="manifest"]')) sw();

    // 'pronto' (botão do navegador), 'instalado', 'ios', 'mac', 'menu' (pelo menu do navegador) ou 'nao'
    const comoInstalar = () => instalado() ? 'instalado' : pedido ? 'pronto' : ios ? 'ios' : macSafari ? 'mac' : firefox && !android ? 'nao' : 'menu';
    function passos(tipo) {
      const box = document.createElement('div'); box.className = 'cfm-wrap';
      const L = {
        ios: ['Toque no botão <b>Compartilhar</b> (o quadrado com a seta para cima), embaixo ou em cima da tela.', 'Role e toque em <b>Adicionar à Tela de Início</b>.', 'Toque em <b>Adicionar</b>. Depois abra o GoPedido pelo ícone novo.'],
        mac: ['No Safari, clique em <b>Arquivo</b> na barra de cima.', 'Clique em <b>Adicionar ao Dock</b>.', 'Abra o GoPedido pelo ícone no Dock.'],
        menu: celular
          ? ['Toque nos <b>três pontinhos</b> do navegador (em cima, à direita).', 'Toque em <b>Instalar app</b> ou <b>Adicionar à tela inicial</b>.', 'Confirme. O ícone do GoPedido aparece junto dos seus apps.']
          : ['Na barra de endereço, clique no ícone de <b>instalar</b> (um monitor com uma seta), à direita.', 'Ou abra o menu do navegador (<b>três pontinhos</b>) e clique em <b>Instalar GoPedido</b> / <b>Aplicativos → Instalar este site</b>.', 'Pronto: o GoPedido abre em janela própria e ganha um ícone na área de trabalho e no menu Iniciar.'],
        nao: ['Este navegador não instala sites como aplicativo.', 'Abra esta página no <b>Google Chrome</b> ou no <b>Microsoft Edge</b> e clique em instalar.', 'Os avisos de pedido novo funcionam aqui mesmo assim.']
      }[tipo] || [];
      box.innerHTML = `<div class="cfm" role="dialog" aria-modal="true"><div class="cfm-ic">${GP.ic(celular ? 'phone' : 'monitor')}</div>
        <h3>Instalar o GoPedido</h3><ol class="app-passos">${L.map(x => `<li>${x}</li>`).join('')}</ol>
        <div class="cfm-acts"><button type="button" class="btn btn-primary" data-r="1">Entendi</button></div></div>`;
      document.body.appendChild(box); requestAnimationFrame(() => box.classList.add('on'));
      box.addEventListener('click', (e) => { if (e.target === box || e.target.closest('[data-r]')) { box.classList.remove('on'); setTimeout(() => box.remove(), 180); } });
    }
    async function instalar() {
      if (pedido) {
        const ev = pedido; pedido = null;
        try { ev.prompt(); const r = await ev.userChoice; avisa(); return r && r.outcome === 'accepted'; } catch (_) { avisa(); }
        return false;
      }
      if (!instalado()) passos(comoInstalar());
      return false;
    }

    const temPush = () => 'serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window;
    const deB64 = (s) => { const t = s.replace(/-/g, '+').replace(/_/g, '/'); const b = atob(t + '==='.slice((t.length + 3) % 4)); return Uint8Array.from(b, c => c.charCodeAt(0)); };
    // 'ligado', 'desligado', 'bloqueado', 'ios_instalar' (iPhone só recebe com o app instalado) ou 'sem_suporte'
    async function estadoPush() {
      if (!temPush()) return ios && !instalado() ? 'ios_instalar' : 'sem_suporte';
      if (Notification.permission === 'denied') return 'bloqueado';
      const r = await sw(); if (!r) return 'sem_suporte';
      const s = await r.pushManager.getSubscription().catch(() => null);
      return s && Notification.permission === 'granted' ? 'ligado' : 'desligado';
    }
    const nomeAparelho = () => (ios ? 'iPhone' : android ? 'Android' : /Windows/.test(ua) ? 'Windows' : /Mac/.test(ua) ? 'Mac' : 'Computador')
      + ' · ' + (/Edg\//.test(ua) ? 'Edge' : /OPR\//.test(ua) ? 'Opera' : /Firefox/.test(ua) ? 'Firefox' : /Chrome/.test(ua) ? 'Chrome' : /Safari/.test(ua) ? 'Safari' : 'Navegador');
    // salvar(j, aparelho) opcional: onde guardar o aparelho (motoboy usa outra tabela)
    async function ativarPush(sb, salvar) {
      if (!temPush()) throw new Error(ios && !instalado() ? 'push_ios' : 'push_sem_suporte');
      const perm = await Notification.requestPermission();
      if (perm !== 'granted') throw new Error('push_negado');
      const r = await sw(); if (!r) throw new Error('push_sem_suporte');
      const { data, error } = await sb.functions.invoke('ff-email', { body: { acao: 'push_chave' } });
      if (error || !data || !data.chave) throw new Error('push_servidor');
      const chave = deB64(data.chave);
      let s = await r.pushManager.getSubscription();
      if (s) {
        const atual = s.options && s.options.applicationServerKey ? new Uint8Array(s.options.applicationServerKey) : null;
        if (!atual || atual.length !== chave.length || atual.some((v, i) => v !== chave[i])) { await s.unsubscribe().catch(() => {}); s = null; }
      }
      if (!s) s = await r.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: chave });
      const j = s.toJSON();
      if (salvar) { await salvar(j, nomeAparelho()); return true; }
      const { error: e2 } = await sb.rpc('ff_push_salvar', { p_endpoint: j.endpoint, p_p256dh: j.keys.p256dh, p_auth: j.keys.auth, p_aparelho: nomeAparelho() });
      if (e2) throw e2;
      return true;
    }
    async function desativarPush(sb, remover) {
      const r = await sw(); const s = r && await r.pushManager.getSubscription();
      if (s) { await (remover ? remover(s.endpoint) : sb.rpc('ff_push_remover', { p_endpoint: s.endpoint })).catch(() => {}); await s.unsubscribe().catch(() => {}); }
    }
    async function testarPush(sb) {
      const { data, error } = await sb.functions.invoke('ff-email', { body: { acao: 'push_teste' } });
      if (error) throw error;
      return data || {};
    }
    // Já tinha ligado antes: mantém o aparelho cadastrado em nome de quem está logado agora
    async function renovarPush(sb, salvar) {
      try { if ((await estadoPush()) === 'ligado') await ativarPush(sb, salvar); } catch (_) {}
    }
    return { ios, android, celular, instalado, comoInstalar, instalar, aoMudar: (f) => ouvintes.add(f),
             temPush, estadoPush, ativarPush, desativarPush, testarPush, renovarPush };
  })();

  // Convite para instalar o app (cliente, lojista e motoboy). Some por 14 dias se a pessoa fechar.
  GP.convidarInstalar = () => {
    if (!document.querySelector('link[rel="manifest"]') || GP.app.instalado()) return;
    const pag = location.pathname.split('/').pop() || 'index.html';
    const T = pag.startsWith('painel') ? ['Instale o painel da sua loja', 'Abre direto nos pedidos e avisa cada pedido novo.']
      : pag.startsWith('entregador') ? ['Instale o app do entregador', 'Abre mais rápido e avisa cada entrega nova.']
      : ['Instale o GoPedido', 'Peça mais rápido, direto da tela do seu celular ou computador.'];
    const mostrar = () => {
      if (document.getElementById('gp-inst') || GP.app.instalado()) return;
      if (Number(GP.ls.get('gp_inst_off') || 0) > Date.now() - 14 * 864e5) return;
      const modo = GP.app.comoInstalar();
      if (!['pronto', 'ios', 'mac'].includes(modo)) return;
      const el = document.createElement('div'); el.id = 'gp-inst'; el.className = 'gp-inst';
      el.innerHTML = `<img src="img/app-192.png" alt=""><div class="tx"><b>${T[0]}</b><span>${T[1]}</span></div>
        <button type="button" class="btn btn-primary btn-sm" data-i>${GP.ic('download')}Instalar</button><button type="button" class="x" data-x aria-label="Fechar">×</button>`;
      document.body.appendChild(el); requestAnimationFrame(() => el.classList.add('on'));
      const fechar = () => { el.classList.remove('on'); setTimeout(() => el.remove(), 250); };
      el.querySelector('[data-x]').onclick = () => { GP.ls.set('gp_inst_off', String(Date.now())); fechar(); };
      el.querySelector('[data-i]').onclick = async () => { fechar(); await GP.app.instalar(); };
    };
    // espera o navegador dizer se dá para instalar
    setTimeout(mostrar, 4000);
    GP.app.aoMudar(() => { if (GP.app.instalado()) { const el = document.getElementById('gp-inst'); if (el) el.remove(); } else setTimeout(mostrar, 300); });
  };

  const iniciar = () => { GP.olhoSenha(); GP.rodape(); try { GP.convidarInstalar(); } catch (_) {} };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', iniciar); else iniciar();
})();
