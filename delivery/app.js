/* GoPedido — funções compartilhadas */
(function () {
  const cfg = window.GP_CONFIG;
  const GP = (window.GP = { cfg });

  // ---------- Supabase ----------
  GP.client = (persist) =>
    window.supabase.createClient(cfg.supabaseUrl, cfg.supabaseKey, {
      auth: persist ? { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true } : { persistSession: false }
    });
  GP.publicUrl = (sb, path) => (path ? sb.storage.from('ff-imagens').getPublicUrl(path).data.publicUrl : '');

  // ---------- Ícones ----------
  const ICONS = {
    bag: '<path d="M6 7h12l1 13H5L6 7Z"/><path d="M9 7a3 3 0 0 1 6 0"/>',
    pin: '<path d="M12 21s-7-6.2-7-11.5A7 7 0 0 1 19 9.5C19 14.8 12 21 12 21Z"/><circle cx="12" cy="9.5" r="2.5"/>',
    clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
    bike: '<circle cx="6" cy="17" r="3"/><circle cx="18" cy="17" r="3"/><path d="M6 17l4-8h4l4 8M10 9 8 5H6m8 4 1-3h2"/>',
    search: '<circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/>',
    x: '<path d="M6 6l12 12M18 6 6 18"/>',
    plus: '<path d="M12 5v14M5 12h14"/>',
    minus: '<path d="M5 12h14"/>',
    copy: '<rect x="9" y="9" width="11" height="11" rx="2"/><path d="M5 15V6a2 2 0 0 1 2-2h8"/>',
    upload: '<path d="M12 15V4m0 0-4 4m4-4 4 4"/><path d="M4 15v3a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-3"/>',
    check: '<path d="m5 12 5 5 9-10"/>',
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
    shield: '<path d="M12 3 4 6v6c0 5 3.4 8 8 9 4.6-1 8-4 8-9V6l-8-3Z"/><path d="m9 12 2 2 4-4"/>',
    bolt: '<path d="M13 2 4 14h7l-1 8 9-12h-7l1-8Z"/>',
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
    const t = document.createElement('div');
    t.className = 'toast ' + type;
    t.innerHTML = (type === 'ok' ? GP.ic('check') : '') + '<span>' + GP.esc(msg) + '</span>';
    box.appendChild(t);
    setTimeout(() => { t.style.transition = 'opacity .3s'; t.style.opacity = '0'; setTimeout(() => t.remove(), 300); }, 3200);
  };

  // ---------- Erros do banco em português ----------
  const ERROS = {
    loja_invalida: 'Loja não encontrada.',
    loja_fechada: 'A loja está fechada no momento.',
    loja_sem_localizacao: 'A loja ainda não configurou a localização.',
    pagamento_invalido: 'Forma de pagamento não aceita por esta loja.',
    comprovante_obrigatorio: 'Anexe o comprovante do Pix para enviar o pedido.',
    dados_incompletos: 'Preencha nome, telefone e endereço.',
    localizacao_obrigatoria: 'Informe sua localização no mapa.',
    fora_da_area: 'Seu endereço está fora da área de entrega da loja.',
    produto_indisponivel: 'Um dos produtos ficou indisponível. Revise a sacola.',
    carrinho_vazio: 'Sua sacola está vazia.',
    abaixo_do_minimo: 'O pedido não atingiu o valor mínimo da loja.',
    'Invalid login credentials': 'E-mail ou senha incorretos.',
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
  GP.taxa = (loja, dist) => Math.max(Number(loja.taxa_minima) || 0, Math.round(dist * (Number(loja.taxa_km) || 0) * 100) / 100);
  GP.foraArea = (loja, dist) => Number(loja.raio_km) > 0 && dist > Number(loja.raio_km);

  GP.geo = () => new Promise((ok, fail) => {
    if (!navigator.geolocation) return fail(new Error('Seu navegador não permite localização.'));
    navigator.geolocation.getCurrentPosition(
      (p) => ok({ lat: p.coords.latitude, lng: p.coords.longitude }),
      (e) => fail(new Error(e.code === 1 ? 'Permita o acesso à localização para calcular a entrega.' : 'Não foi possível obter sua localização.')),
      { enableHighAccuracy: true, timeout: 15000, maximumAge: 60000 }
    );
  });

  // Mapa com pino arrastável (Leaflet + OpenStreetMap)
  GP.mapPicker = (el, start, onChange) => {
    const c = start && start.lat != null ? [start.lat, start.lng] : cfg.centro;
    const map = L.map(el, { zoomControl: true, attributionControl: true }).setView(c, start && start.lat != null ? 16 : 13);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', { maxZoom: 19, attribution: '© OpenStreetMap' }).addTo(map);
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
      set(lat, lng) { put(lat, lng); map.setView([lat, lng], 17); },
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
  GP.pixChave = (tipo, chave) => {
    const k = String(chave || '').trim();
    if (tipo === 'cpf' || tipo === 'cnpj') return GP.digits(k);
    if (tipo === 'telefone') { const d = GP.digits(k); return '+' + (d.length <= 11 ? '55' + d : d); }
    if (tipo === 'email') return k.toLowerCase();
    return k;
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

  GP.STATUS = {
    novo: { t: 'Recebido', c: 'b-brand', d: 'A loja recebeu seu pedido' },
    preparando: { t: 'Em preparo', c: 'b-warn', d: 'Seu pedido está sendo preparado' },
    saiu: { t: 'Saiu para entrega', c: 'b-ok', d: 'O entregador está a caminho' },
    entregue: { t: 'Entregue', c: 'b-off', d: 'Pedido entregue. Bom apetite!' },
    cancelado: { t: 'Cancelado', c: 'b-bad', d: 'Este pedido foi cancelado' }
  };
  GP.PAG = { pix: 'Pix', debito: 'Cartão de débito (na entrega)', credito: 'Cartão de crédito (na entrega)' };
})();
