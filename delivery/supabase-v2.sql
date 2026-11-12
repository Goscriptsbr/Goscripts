-- =====================================================================
--  GoPedido — ATUALIZAÇÃO 2
--  Motoboy com código da loja (8h) · conta do cliente · endereços
--  Rode DEPOIS do supabase.sql. Pode rodar de novo sem problema.
-- =====================================================================

-- ---------- Pedidos: cliente e entregador ----------
alter table public.ff_pedidos add column if not exists cliente_id uuid references auth.users(id) on delete set null;
alter table public.ff_pedidos add column if not exists entregador_nome text not null default '';
create index if not exists ff_pedidos_cliente_idx on public.ff_pedidos (cliente_id, criado_em desc);

-- ---------- Conta do cliente ----------
create table if not exists public.ff_clientes (
  id         uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  nome       text not null default '',
  telefone   text not null default '',
  criado_em  timestamptz not null default now()
);

create table if not exists public.ff_enderecos (
  id          uuid primary key default gen_random_uuid(),
  cliente_id  uuid not null default auth.uid() references auth.users(id) on delete cascade,
  apelido     text not null default '',
  cep         text not null default '',
  rua         text not null default '',
  numero      text not null default '',
  bairro      text not null default '',
  cidade      text not null default '',
  uf          text not null default '',
  complemento text not null default '',
  lat         double precision,
  lng         double precision,
  principal   boolean not null default false,
  criado_em   timestamptz not null default now()
);
create index if not exists ff_enderecos_cliente_idx on public.ff_enderecos (cliente_id);

alter table public.ff_clientes  enable row level security;
alter table public.ff_enderecos enable row level security;

drop policy if exists ff_clientes_eu  on public.ff_clientes;
drop policy if exists ff_enderecos_eu on public.ff_enderecos;
create policy ff_clientes_eu on public.ff_clientes for all to authenticated
  using (id = auth.uid()) with check (id = auth.uid());
create policy ff_enderecos_eu on public.ff_enderecos for all to authenticated
  using (cliente_id = auth.uid()) with check (cliente_id = auth.uid());

revoke all on public.ff_clientes, public.ff_enderecos from anon;
grant select, insert, update, delete on public.ff_clientes, public.ff_enderecos to authenticated;

-- ---------- Código de acesso do motoboy ----------
-- Fica numa tabela fechada: ninguém lê direto, só pelas funções abaixo.
create table if not exists public.ff_entregador_acesso (
  loja_id  uuid primary key references public.ff_lojas(id) on delete cascade,
  codigo   text not null unique,
  expira   timestamptz not null
);
alter table public.ff_entregador_acesso enable row level security;
revoke all on public.ff_entregador_acesso from anon, authenticated;

create or replace function public.ff_gera_codigo()
returns text language plpgsql volatile as $$
declare
  alfa text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  b bytea := decode(replace(gen_random_uuid()::text, '-', ''), 'hex');
  r text := '';
  i int;
begin
  for i in 0..7 loop
    r := r || substr(alfa, (get_byte(b, i) % length(alfa)) + 1, 1);
  end loop;
  return r;
end;
$$;

-- Lojista: pega o código atual (troca sozinho se passou de 8h) ou gera um novo
create or replace function public.ff_codigo_entregador(p_novo boolean default false)
returns json language plpgsql volatile security definer set search_path = public as $$
declare
  v_loja uuid;
  a public.ff_entregador_acesso;
begin
  select id into v_loja from public.ff_lojas where dono = auth.uid();
  if v_loja is null then raise exception 'sem_loja'; end if;
  select * into a from public.ff_entregador_acesso where loja_id = v_loja;
  if not found or p_novo or a.expira <= now() then
    insert into public.ff_entregador_acesso (loja_id, codigo, expira)
    values (v_loja, public.ff_gera_codigo(), now() + interval '8 hours')
    on conflict (loja_id) do update set codigo = excluded.codigo, expira = excluded.expira
    returning * into a;
  end if;
  return json_build_object('codigo', a.codigo, 'expira', a.expira);
end;
$$;

-- Loja de um código válido (null se inválido ou vencido)
create or replace function public.ff_loja_do_codigo(p_codigo text)
returns uuid language sql stable security definer set search_path = public as $$
  select loja_id from public.ff_entregador_acesso
  where codigo = upper(regexp_replace(coalesce(p_codigo, ''), '[^A-Za-z0-9]', '', 'g'))
    and expira > now();
$$;

-- Motoboy: entrar com o código
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
                              'endereco', l.endereco, 'lat', l.lat, 'lng', l.lng),
    'expira', (select expira from public.ff_entregador_acesso where loja_id = v_loja));
end;
$$;

-- Motoboy: lista de entregas da loja
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
      'distancia_km', p.distancia_km, 'total', p.total, 'pagamento', p.pagamento,
      'observacao', p.observacao, 'entregador_nome', p.entregador_nome,
      'criado_em', p.criado_em, 'atualizado_em', p.atualizado_em,
      'itens', coalesce((select json_agg(json_build_object('nome', i.nome, 'qtd', i.qtd))
                         from public.ff_pedido_itens i where i.pedido_id = p.id), '[]'::json))
      order by p.criado_em)
    from public.ff_pedidos p
    where p.loja_id = v_loja
      and (p.status in ('preparando', 'saiu')
           or (p.status = 'entregue' and p.atualizado_em > now() - interval '12 hours'))
  ), '[]'::json);
end;
$$;

-- Motoboy: "saí para entrega" e "entregue"
create or replace function public.ff_entregador_status(p_codigo text, p_pedido uuid, p_status text, p_nome text default '')
returns json language plpgsql volatile security definer set search_path = public as $$
declare
  v_loja uuid := public.ff_loja_do_codigo(p_codigo);
  p public.ff_pedidos;
begin
  if v_loja is null then raise exception 'codigo_invalido'; end if;
  select * into p from public.ff_pedidos where id = p_pedido and loja_id = v_loja for update;
  if not found then raise exception 'pedido_invalido'; end if;

  if p_status = 'saiu' and p.status = 'preparando' then
    update public.ff_pedidos
       set status = 'saiu', entregador_nome = left(trim(coalesce(p_nome, '')), 60)
     where id = p.id;
  elsif p_status = 'entregue' and p.status = 'saiu' then
    update public.ff_pedidos set status = 'entregue' where id = p.id;
  else
    raise exception 'status_invalido';
  end if;
  return json_build_object('ok', true);
end;
$$;

-- ---------- Pedido: agora guarda o cliente logado ----------
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
begin
  select * into l from public.ff_lojas where id = p_loja and ativa;
  if not found then raise exception 'loja_invalida'; end if;
  if not l.aberta then raise exception 'loja_fechada'; end if;
  if l.lat is null or l.lng is null then raise exception 'loja_sem_localizacao'; end if;

  if p_pagamento not in ('pix','debito','credito')
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

  update public.ff_pedidos set subtotal = v_sub, total = v_sub + v_taxa
   where id = v_ped.id returning * into v_ped;

  return json_build_object('token', v_ped.token, 'numero', v_ped.numero, 'total', v_ped.total);
end;
$$;

-- Acompanhar pedido (agora mostra o nome do entregador)
create or replace function public.ff_acompanhar(p_token text)
returns json language sql stable security definer set search_path = public as $$
  select json_build_object(
    'numero', p.numero, 'status', p.status, 'criado_em', p.criado_em,
    'atualizado_em', p.atualizado_em, 'cliente_nome', p.cliente_nome,
    'endereco', p.endereco, 'complemento', p.complemento,
    'distancia_km', p.distancia_km, 'taxa_entrega', p.taxa_entrega,
    'subtotal', p.subtotal, 'total', p.total, 'pagamento', p.pagamento,
    'observacao', p.observacao, 'entregador_nome', p.entregador_nome,
    'loja', json_build_object('nome', l.nome, 'slug', l.slug, 'imagem_url', l.imagem_url,
                              'telefone', l.telefone, 'tempo_entrega', l.tempo_entrega),
    'itens', coalesce((select json_agg(json_build_object(
                         'nome', i.nome, 'preco', i.preco, 'qtd', i.qtd, 'obs', i.obs))
                       from public.ff_pedido_itens i where i.pedido_id = p.id), '[]'::json))
  from public.ff_pedidos p join public.ff_lojas l on l.id = p.loja_id
  where p.token = p_token;
$$;

-- Cliente: meus pedidos
create or replace function public.ff_meus_pedidos()
returns json language sql stable security definer set search_path = public as $$
  select coalesce(json_agg(x order by x.criado_em desc), '[]'::json) from (
    select p.token, p.numero, p.status, p.total, p.criado_em,
           l.nome as loja_nome, l.imagem_url as loja_imagem, l.slug as loja_slug
    from public.ff_pedidos p join public.ff_lojas l on l.id = p.loja_id
    where p.cliente_id = auth.uid() and auth.uid() is not null
    order by p.criado_em desc limit 50) x;
$$;

-- ---------- Permissões ----------
revoke all on function public.ff_gera_codigo()                         from public;
revoke all on function public.ff_codigo_entregador(boolean)            from public;
revoke all on function public.ff_loja_do_codigo(text)                  from public;
revoke all on function public.ff_entregador_entrar(text)               from public;
revoke all on function public.ff_entregador_pedidos(text)              from public;
revoke all on function public.ff_entregador_status(text, uuid, text, text) from public;
revoke all on function public.ff_meus_pedidos()                        from public;
revoke all on function public.ff_criar_pedido(uuid, jsonb, jsonb, text, text) from public;
revoke all on function public.ff_acompanhar(text)                      from public;

grant execute on function public.ff_codigo_entregador(boolean)            to authenticated;
grant execute on function public.ff_entregador_entrar(text)               to anon, authenticated;
grant execute on function public.ff_entregador_pedidos(text)              to anon, authenticated;
grant execute on function public.ff_entregador_status(text, uuid, text, text) to anon, authenticated;
grant execute on function public.ff_meus_pedidos()                        to authenticated;
grant execute on function public.ff_criar_pedido(uuid, jsonb, jsonb, text, text) to anon, authenticated;
grant execute on function public.ff_acompanhar(text)                      to anon, authenticated;
