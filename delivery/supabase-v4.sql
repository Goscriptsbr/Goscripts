-- =====================================================================
--  GoPedido — ATUALIZAÇÃO 4: pagamento em dinheiro com troco
--  Rode DEPOIS das atualizações anteriores. Pode rodar de novo.
-- =====================================================================

alter table public.ff_lojas   add column if not exists aceita_dinheiro boolean not null default true;
alter table public.ff_pedidos add column if not exists troco_para numeric(10,2);

alter table public.ff_pedidos drop constraint if exists ff_pedidos_pagamento_check;
alter table public.ff_pedidos add constraint ff_pedidos_pagamento_check
  check (pagamento in ('pix','debito','credito','dinheiro'));

create or replace function public.ff_criar_pedido(
  p_loja uuid, p_cliente jsonb, p_itens jsonb, p_pagamento text, p_comprovante text default null)
returns json language plpgsql volatile security definer set search_path = public as $$
declare
  l      public.ff_lojas;
  pr     public.ff_produtos;
  it     jsonb;
  q      int;
  n      int := 0;
  v_sub  numeric := 0;
  v_dist numeric;
  v_taxa numeric;
  v_lat  double precision := nullif(p_cliente ->> 'lat', '')::double precision;
  v_lng  double precision := nullif(p_cliente ->> 'lng', '')::double precision;
  v_ped  public.ff_pedidos;
  v_troco numeric := nullif(p_cliente ->> 'troco_para', '')::numeric;
begin
  select * into l from public.ff_lojas where id = p_loja and ativa;
  if not found then raise exception 'loja_invalida'; end if;
  if not l.aberta then raise exception 'loja_fechada'; end if;
  if l.lat is null or l.lng is null then raise exception 'loja_sem_localizacao'; end if;

  if p_pagamento not in ('pix','debito','credito','dinheiro')
     or (p_pagamento = 'dinheiro' and not l.aceita_dinheiro)
     or (p_pagamento = 'pix'     and not l.aceita_pix)
     or (p_pagamento = 'debito'  and not l.aceita_debito)
     or (p_pagamento = 'credito' and not l.aceita_credito) then
    raise exception 'pagamento_invalido';
  end if;

  if p_pagamento = 'pix' then
    if coalesce(p_comprovante, '') = ''
       or split_part(p_comprovante, '/', 1) <> l.id::text
       or not exists (select 1 from storage.objects
                      where bucket_id = 'ff-comprovantes' and name = p_comprovante) then
      raise exception 'comprovante_obrigatorio';
    end if;
  end if;

  if length(trim(coalesce(p_cliente ->> 'nome', ''))) < 2
     or length(regexp_replace(coalesce(p_cliente ->> 'telefone', ''), '\D', '', 'g')) < 10
     or length(trim(coalesce(p_cliente ->> 'endereco', ''))) < 5 then
    raise exception 'dados_incompletos';
  end if;
  if v_lat is null or v_lng is null then raise exception 'localizacao_obrigatoria'; end if;

  v_dist := public.ff_distancia_km(l.lat, l.lng, v_lat, v_lng);
  if l.raio_km > 0 and v_dist > l.raio_km then raise exception 'fora_da_area'; end if;
  v_taxa := greatest(l.taxa_minima, round(v_dist * l.taxa_km, 2));

  insert into public.ff_pedidos
    (loja_id, cliente_id, cliente_nome, cliente_telefone, endereco, complemento, lat, lng,
     distancia_km, taxa_entrega, pagamento, comprovante_path, observacao)
  values
    (l.id, auth.uid(), left(trim(p_cliente ->> 'nome'), 80), left(trim(p_cliente ->> 'telefone'), 30),
     left(trim(p_cliente ->> 'endereco'), 200), left(trim(coalesce(p_cliente ->> 'complemento', '')), 120),
     v_lat, v_lng, v_dist, v_taxa, p_pagamento,
     case when p_pagamento = 'pix' then p_comprovante end,
     left(trim(coalesce(p_cliente ->> 'observacao', '')), 300))
  returning * into v_ped;

  for it in select * from jsonb_array_elements(coalesce(p_itens, '[]'::jsonb)) loop
    q := least(greatest(coalesce((it ->> 'qtd')::int, 0), 0), 99);
    continue when q = 0;
    select * into pr from public.ff_produtos
     where id = (it ->> 'id')::uuid and loja_id = l.id and disponivel;
    if not found then raise exception 'produto_indisponivel'; end if;
    insert into public.ff_pedido_itens (pedido_id, produto_id, nome, preco, qtd, obs)
    values (v_ped.id, pr.id, pr.nome, pr.preco, q, left(trim(coalesce(it ->> 'obs', '')), 200));
    v_sub := v_sub + pr.preco * q;
    n := n + 1;
  end loop;

  if n = 0 then raise exception 'carrinho_vazio'; end if;
  if v_sub < l.pedido_minimo then raise exception 'abaixo_do_minimo'; end if;

  if p_pagamento = 'dinheiro' and coalesce(v_troco, 0) > 0 and v_troco < v_sub + v_taxa then
    raise exception 'troco_invalido';
  end if;

  update public.ff_pedidos
     set subtotal = v_sub, total = v_sub + v_taxa,
         troco_para = case when p_pagamento = 'dinheiro' and coalesce(v_troco, 0) > 0 then v_troco end
   where id = v_ped.id returning * into v_ped;

  return json_build_object('token', v_ped.token, 'numero', v_ped.numero, 'total', v_ped.total);
end;
$$;


-- Acompanhar pedido (com troco)
create or replace function public.ff_acompanhar(p_token text)
returns json language sql stable security definer set search_path = public as $$
  select json_build_object(
    'numero', p.numero, 'status', p.status, 'criado_em', p.criado_em,
    'atualizado_em', p.atualizado_em, 'cliente_nome', p.cliente_nome,
    'endereco', p.endereco, 'complemento', p.complemento,
    'distancia_km', p.distancia_km, 'taxa_entrega', p.taxa_entrega,
    'subtotal', p.subtotal, 'total', p.total, 'pagamento', p.pagamento, 'troco_para', p.troco_para,
    'observacao', p.observacao, 'entregador_nome', p.entregador_nome,
    'loja', json_build_object('nome', l.nome, 'slug', l.slug, 'imagem_url', l.imagem_url,
                              'telefone', l.telefone, 'tempo_entrega', l.tempo_entrega, 'cnpj', l.cnpj),
    'itens', coalesce((select json_agg(json_build_object(
                         'nome', i.nome, 'preco', i.preco, 'qtd', i.qtd, 'obs', i.obs))
                       from public.ff_pedido_itens i where i.pedido_id = p.id), '[]'::json))
  from public.ff_pedidos p join public.ff_lojas l on l.id = p.loja_id
  where p.token = p_token;
$$;

-- Motoboy: dados da loja (com CNPJ, para o comprovante)
create or replace function public.ff_entregador_entrar(p_codigo text)
returns json language plpgsql stable security definer set search_path = public as $$
declare
  v_loja uuid := public.ff_loja_do_codigo(p_codigo);
  l public.ff_lojas;
begin
  if v_loja is null then raise exception 'codigo_invalido'; end if;
  select * into l from public.ff_lojas where id = v_loja;
  return json_build_object(
    'loja', json_build_object('nome', l.nome, 'imagem_url', l.imagem_url, 'telefone', l.telefone,
                              'endereco', l.endereco, 'lat', l.lat, 'lng', l.lng, 'cnpj', l.cnpj),
    'expira', (select expira from public.ff_entregador_acesso where loja_id = v_loja));
end;
$$;

-- Motoboy: entregas com valores, troco e itens completos (para reimprimir)
create or replace function public.ff_entregador_pedidos(p_codigo text)
returns json language plpgsql stable security definer set search_path = public as $$
declare
  v_loja uuid := public.ff_loja_do_codigo(p_codigo);
begin
  if v_loja is null then raise exception 'codigo_invalido'; end if;
  return coalesce((
    select json_agg(json_build_object(
      'id', p.id, 'numero', p.numero, 'status', p.status,
      'cliente_nome', p.cliente_nome, 'cliente_telefone', p.cliente_telefone,
      'endereco', p.endereco, 'complemento', p.complemento, 'lat', p.lat, 'lng', p.lng,
      'distancia_km', p.distancia_km, 'subtotal', p.subtotal, 'taxa_entrega', p.taxa_entrega,
      'total', p.total, 'pagamento', p.pagamento, 'troco_para', p.troco_para,
      'observacao', p.observacao, 'entregador_nome', p.entregador_nome,
      'criado_em', p.criado_em, 'atualizado_em', p.atualizado_em,
      'itens', coalesce((select json_agg(json_build_object('nome', i.nome, 'qtd', i.qtd, 'preco', i.preco, 'obs', i.obs))
                         from public.ff_pedido_itens i where i.pedido_id = p.id), '[]'::json))
      order by p.criado_em)
    from public.ff_pedidos p
    where p.loja_id = v_loja
      and (p.status in ('preparando', 'saiu')
           or (p.status = 'entregue' and p.atualizado_em > now() - interval '12 hours'))
  ), '[]'::json);
end;
$$;

grant execute on function public.ff_criar_pedido(uuid, jsonb, jsonb, text, text) to anon, authenticated;
grant execute on function public.ff_acompanhar(text)                      to anon, authenticated;
grant execute on function public.ff_entregador_entrar(text)               to anon, authenticated;
grant execute on function public.ff_entregador_pedidos(text)              to anon, authenticated;
