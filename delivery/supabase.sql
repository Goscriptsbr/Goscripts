-- =====================================================================
--  GoPedido — delivery de fast food (Supabase)
--  Usa o MESMO projeto Supabase do convite da Liz, mas com tabelas
--  próprias (prefixo ff_). Não mexe em nada do convite.
--
--  Como usar: Supabase > SQL Editor > New query > cole TUDO > Run.
--  Pode rodar de novo sem problema: não apaga dados existentes.
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------
--  Tabelas
-- ---------------------------------------------------------------------

-- Lojas (uma por conta)
create table if not exists public.ff_lojas (
  id             uuid primary key default gen_random_uuid(),
  dono           uuid not null unique default auth.uid() references auth.users(id) on delete cascade,
  slug           text not null unique,
  nome           text not null,
  descricao      text not null default '',
  imagem_url     text not null default '',
  capa_url       text not null default '',
  telefone       text not null default '',          -- WhatsApp da loja
  endereco       text not null default '',
  lat            double precision,
  lng            double precision,
  taxa_km        numeric(10,2) not null default 0,  -- R$ por km
  taxa_minima    numeric(10,2) not null default 0,  -- taxa mínima de entrega
  raio_km        numeric(10,2) not null default 0,  -- 0 = sem limite
  pedido_minimo  numeric(10,2) not null default 0,
  tempo_entrega  text not null default '30–50 min',
  aceita_pix     boolean not null default true,
  aceita_debito  boolean not null default true,
  aceita_credito boolean not null default true,
  pix_tipo       text not null default 'aleatoria'
                 check (pix_tipo in ('cpf','cnpj','telefone','email','aleatoria')),
  pix_chave      text not null default '',
  pix_nome       text not null default '',          -- nome do recebedor
  pix_cidade     text not null default '',
  aberta         boolean not null default false,
  ativa          boolean not null default true,
  criado_em      timestamptz not null default now()
);

-- Cardápio
create table if not exists public.ff_produtos (
  id          uuid primary key default gen_random_uuid(),
  loja_id     uuid not null references public.ff_lojas(id) on delete cascade,
  nome        text not null,
  descricao   text not null default '',
  categoria   text not null default 'Lanches',
  preco       numeric(10,2) not null check (preco >= 0),
  imagem_url  text not null default '',
  disponivel  boolean not null default true,
  ordem       int not null default 0,
  criado_em   timestamptz not null default now()
);
create index if not exists ff_produtos_loja_idx on public.ff_produtos (loja_id);

-- Pedidos
create table if not exists public.ff_pedidos (
  id               uuid primary key default gen_random_uuid(),
  numero           bigint generated always as identity,
  token            text not null unique
                   default substr(replace(gen_random_uuid()::text, '-', ''), 1, 16),
  loja_id          uuid not null references public.ff_lojas(id) on delete cascade,
  cliente_nome     text not null,
  cliente_telefone text not null,
  endereco         text not null,
  complemento      text not null default '',
  lat              double precision not null,
  lng              double precision not null,
  distancia_km     numeric(10,2) not null default 0,
  taxa_entrega     numeric(10,2) not null default 0,
  subtotal         numeric(10,2) not null default 0,
  total            numeric(10,2) not null default 0,
  pagamento        text not null check (pagamento in ('pix','debito','credito')),
  comprovante_path text,
  observacao       text not null default '',
  status           text not null default 'novo'
                   check (status in ('novo','preparando','saiu','entregue','cancelado')),
  criado_em        timestamptz not null default now(),
  atualizado_em    timestamptz not null default now()
);
create index if not exists ff_pedidos_loja_idx on public.ff_pedidos (loja_id, criado_em desc);

create table if not exists public.ff_pedido_itens (
  id          uuid primary key default gen_random_uuid(),
  pedido_id   uuid not null references public.ff_pedidos(id) on delete cascade,
  produto_id  uuid references public.ff_produtos(id) on delete set null,
  nome        text not null,
  preco       numeric(10,2) not null,
  qtd         int not null check (qtd > 0),
  obs         text not null default ''
);
create index if not exists ff_pedido_itens_pedido_idx on public.ff_pedido_itens (pedido_id);

-- ---------------------------------------------------------------------
--  Segurança (RLS)
--  - Qualquer pessoa vê lojas ativas e o cardápio.
--  - Só o dono mexe na própria loja, cardápio e pedidos.
--  - Clientes NÃO acessam pedidos direto: só pelas funções abaixo.
-- ---------------------------------------------------------------------

alter table public.ff_lojas        enable row level security;
alter table public.ff_produtos     enable row level security;
alter table public.ff_pedidos      enable row level security;
alter table public.ff_pedido_itens enable row level security;

create or replace function public.ff_minha_loja(p_loja uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.ff_lojas where id = p_loja and dono = auth.uid());
$$;

drop policy if exists ff_lojas_ver     on public.ff_lojas;
drop policy if exists ff_lojas_criar   on public.ff_lojas;
drop policy if exists ff_lojas_editar  on public.ff_lojas;
drop policy if exists ff_lojas_apagar  on public.ff_lojas;
create policy ff_lojas_ver    on public.ff_lojas for select to anon, authenticated
  using (ativa or dono = auth.uid());
create policy ff_lojas_criar  on public.ff_lojas for insert to authenticated
  with check (dono = auth.uid());
create policy ff_lojas_editar on public.ff_lojas for update to authenticated
  using (dono = auth.uid()) with check (dono = auth.uid());
create policy ff_lojas_apagar on public.ff_lojas for delete to authenticated
  using (dono = auth.uid());

drop policy if exists ff_produtos_ver  on public.ff_produtos;
drop policy if exists ff_produtos_dono on public.ff_produtos;
create policy ff_produtos_ver  on public.ff_produtos for select to anon, authenticated
  using (true);
create policy ff_produtos_dono on public.ff_produtos for all to authenticated
  using (public.ff_minha_loja(loja_id)) with check (public.ff_minha_loja(loja_id));

drop policy if exists ff_pedidos_dono on public.ff_pedidos;
create policy ff_pedidos_dono on public.ff_pedidos for all to authenticated
  using (public.ff_minha_loja(loja_id)) with check (public.ff_minha_loja(loja_id));

drop policy if exists ff_itens_dono on public.ff_pedido_itens;
create policy ff_itens_dono on public.ff_pedido_itens for select to authenticated
  using (exists (select 1 from public.ff_pedidos p
                 where p.id = pedido_id and public.ff_minha_loja(p.loja_id)));

revoke all on public.ff_lojas, public.ff_produtos, public.ff_pedidos, public.ff_pedido_itens from anon;
grant select on public.ff_lojas, public.ff_produtos to anon;
grant select, insert, update, delete on public.ff_lojas, public.ff_produtos to authenticated;
grant select, update on public.ff_pedidos to authenticated;
grant select on public.ff_pedido_itens to authenticated;

-- ---------------------------------------------------------------------
--  Funções
-- ---------------------------------------------------------------------

-- Distância em km entre dois pontos (fórmula de Haversine, linha reta)
create or replace function public.ff_distancia_km(
  lat1 double precision, lng1 double precision,
  lat2 double precision, lng2 double precision)
returns numeric language sql immutable as $$
  select round((2 * 6371 * asin(sqrt(
    power(sin(radians(lat2 - lat1) / 2), 2) +
    cos(radians(lat1)) * cos(radians(lat2)) * power(sin(radians(lng2 - lng1) / 2), 2)
  )))::numeric, 2);
$$;

-- Cria um pedido. Recalcula preços e taxa no servidor (o cliente não consegue
-- mudar valores). No Pix, só aceita se o comprovante já foi anexado.
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
    (loja_id, cliente_nome, cliente_telefone, endereco, complemento, lat, lng,
     distancia_km, taxa_entrega, pagamento, comprovante_path, observacao)
  values
    (l.id, left(trim(p_cliente ->> 'nome'), 80), left(trim(p_cliente ->> 'telefone'), 30),
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

-- Acompanhar um pedido pelo código do link
create or replace function public.ff_acompanhar(p_token text)
returns json language sql stable security definer set search_path = public as $$
  select json_build_object(
    'numero', p.numero, 'status', p.status, 'criado_em', p.criado_em,
    'atualizado_em', p.atualizado_em, 'cliente_nome', p.cliente_nome,
    'endereco', p.endereco, 'complemento', p.complemento,
    'distancia_km', p.distancia_km, 'taxa_entrega', p.taxa_entrega,
    'subtotal', p.subtotal, 'total', p.total, 'pagamento', p.pagamento,
    'observacao', p.observacao,
    'loja', json_build_object('nome', l.nome, 'slug', l.slug, 'imagem_url', l.imagem_url,
                              'telefone', l.telefone, 'tempo_entrega', l.tempo_entrega),
    'itens', coalesce((select json_agg(json_build_object(
                         'nome', i.nome, 'preco', i.preco, 'qtd', i.qtd, 'obs', i.obs))
                       from public.ff_pedido_itens i where i.pedido_id = p.id), '[]'::json))
  from public.ff_pedidos p join public.ff_lojas l on l.id = p.loja_id
  where p.token = p_token;
$$;

-- Atualiza a data de modificação do pedido
create or replace function public.ff_toca_pedido()
returns trigger language plpgsql as $$
begin new.atualizado_em := now(); return new; end;
$$;
drop trigger if exists ff_pedidos_toca on public.ff_pedidos;
create trigger ff_pedidos_toca before update on public.ff_pedidos
  for each row execute function public.ff_toca_pedido();

revoke all on function public.ff_criar_pedido(uuid, jsonb, jsonb, text, text) from public;
revoke all on function public.ff_acompanhar(text) from public;
revoke all on function public.ff_minha_loja(uuid) from public;
grant execute on function public.ff_criar_pedido(uuid, jsonb, jsonb, text, text) to anon, authenticated;
grant execute on function public.ff_acompanhar(text) to anon, authenticated;
grant execute on function public.ff_minha_loja(uuid) to authenticated;
grant execute on function public.ff_distancia_km(double precision, double precision, double precision, double precision) to anon, authenticated;

-- ---------------------------------------------------------------------
--  Arquivos (Storage)
--  ff-imagens       → fotos das lojas e produtos (públicas)
--  ff-comprovantes  → comprovantes de Pix (privados, só a loja vê)
-- ---------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('ff-imagens', 'ff-imagens', true, 5242880,
        array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('ff-comprovantes', 'ff-comprovantes', false, 8388608,
        array['image/jpeg','image/png','image/webp','application/pdf'])
on conflict (id) do nothing;

drop policy if exists ff_img_ver     on storage.objects;
drop policy if exists ff_img_enviar  on storage.objects;
drop policy if exists ff_img_editar  on storage.objects;
drop policy if exists ff_img_apagar  on storage.objects;
drop policy if exists ff_comp_enviar on storage.objects;
drop policy if exists ff_comp_ver    on storage.objects;

-- Fotos: cada dono só mexe na pasta com o próprio id
create policy ff_img_ver on storage.objects for select to anon, authenticated
  using (bucket_id = 'ff-imagens');
create policy ff_img_enviar on storage.objects for insert to authenticated
  with check (bucket_id = 'ff-imagens' and (storage.foldername(name))[1] = auth.uid()::text);
create policy ff_img_editar on storage.objects for update to authenticated
  using (bucket_id = 'ff-imagens' and (storage.foldername(name))[1] = auth.uid()::text);
create policy ff_img_apagar on storage.objects for delete to authenticated
  using (bucket_id = 'ff-imagens' and (storage.foldername(name))[1] = auth.uid()::text);

-- Comprovantes: qualquer cliente envia para a pasta de uma loja aberta;
-- só o dono daquela loja consegue abrir
create policy ff_comp_enviar on storage.objects for insert to anon, authenticated
  with check (bucket_id = 'ff-comprovantes' and exists (
    select 1 from public.ff_lojas l
    where l.id::text = (storage.foldername(name))[1] and l.ativa and l.aberta));
create policy ff_comp_ver on storage.objects for select to authenticated
  using (bucket_id = 'ff-comprovantes' and exists (
    select 1 from public.ff_lojas l
    where l.id::text = (storage.foldername(name))[1] and l.dono = auth.uid()));
