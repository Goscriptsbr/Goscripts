-- GoPedido v33 — Loja de assinaturas (planos mensais com cobrança e lembrete por e-mail) e entrega automática de códigos digitais
-- Rode no Supabase → SQL Editor (depois do v32). Depois publique as funções ff-mercadopago e ff-email novas.

-- 1) Novo tipo de loja
alter table public.ff_lojas drop constraint if exists ff_lojas_tipo_check;
alter table public.ff_lojas add constraint ff_lojas_tipo_check
  check (tipo in ('restaurante','mercado','farmacia','pet','bebidas','variedades','outros','agenda','assinatura'));

-- 2) Planos que a loja vende: { "1": 30, "3": 80, "6": 150, "12": 280 } (preço por período, em meses)
create or replace function public.ff_assin_precos_ok(j jsonb)
returns boolean language sql immutable as $$
  select jsonb_typeof(j) = 'object' and j <> '{}'::jsonb
     and not exists (select 1 from jsonb_each(j) e
                      where e.key not in ('1','3','6','12') or jsonb_typeof(e.value) <> 'number'
                         or (e.value #>> '{}')::numeric <= 0 or (e.value #>> '{}')::numeric > 100000)
$$;
create table if not exists public.ff_assin_planos (
  id uuid primary key default gen_random_uuid(),
  loja_id uuid not null references public.ff_lojas(id) on delete cascade,
  nome text not null check (length(trim(nome)) between 1 and 80),
  descricao text not null default '' check (length(descricao) <= 600),
  precos jsonb not null check (public.ff_assin_precos_ok(precos)),
  ativo boolean not null default true,
  entrega_codigo boolean not null default false,
  ordem int not null default 0,
  criado_em timestamptz not null default now()
);
create index if not exists ff_assin_planos_loja_idx on public.ff_assin_planos (loja_id);
alter table public.ff_assin_planos enable row level security;
drop policy if exists ff_assin_planos_ver on public.ff_assin_planos;
create policy ff_assin_planos_ver on public.ff_assin_planos for select to anon, authenticated
  using ((ativo and exists (select 1 from public.ff_lojas l where l.id = loja_id and l.ativa and l.verificacao = 'verificada')) or public.ff_minha_loja(loja_id));
drop policy if exists ff_assin_planos_gerir on public.ff_assin_planos;
create policy ff_assin_planos_gerir on public.ff_assin_planos for all to authenticated
  using (public.ff_minha_loja(loja_id)) with check (public.ff_minha_loja(loja_id));
grant select on public.ff_assin_planos to anon, authenticated;
grant insert, update, delete on public.ff_assin_planos to authenticated;
grant all on public.ff_assin_planos to service_role;

-- 3) Assinantes
create table if not exists public.ff_assinantes (
  id uuid primary key default gen_random_uuid(),
  loja_id uuid not null references public.ff_lojas(id) on delete cascade,
  plano_id uuid not null references public.ff_assin_planos(id) on delete restrict,
  nome text not null check (length(trim(nome)) between 2 and 80),
  email text not null check (email ~ '^[^\s@]+@[^\s@]+\.[^\s@]{2,}$'),
  telefone text not null default '',
  status text not null default 'pendente' check (status in ('pendente','ativo','cancelado')),
  valido_ate date,
  token text not null unique default replace(gen_random_uuid()::text, '-', '') || substr(replace(gen_random_uuid()::text, '-', ''), 1, 8),
  origem text not null default 'site' check (origem in ('site','painel')),
  avisos jsonb not null default '{}'::jsonb,
  obs text not null default '' check (length(obs) <= 300),
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
create index if not exists ff_assinantes_loja_idx on public.ff_assinantes (loja_id, status);
create index if not exists ff_assinantes_vence_idx on public.ff_assinantes (valido_ate) where status = 'ativo';
create unique index if not exists ff_assinantes_unico on public.ff_assinantes (loja_id, plano_id, lower(email)) where status <> 'cancelado';
alter table public.ff_assinantes enable row level security;
drop policy if exists ff_assinantes_gerir on public.ff_assinantes;
create policy ff_assinantes_gerir on public.ff_assinantes for all to authenticated
  using (public.ff_minha_loja(loja_id)) with check (public.ff_minha_loja(loja_id));
grant select, insert, update, delete on public.ff_assinantes to authenticated;
grant all on public.ff_assinantes to service_role;

create or replace function public.ff_assinantes_toca()
returns trigger language plpgsql as $$
begin new.atualizado_em := now(); new.email := lower(trim(new.email)); return new; end $$;
drop trigger if exists ff_assinantes_toca on public.ff_assinantes;
create trigger ff_assinantes_toca before insert or update on public.ff_assinantes
  for each row execute function public.ff_assinantes_toca();

-- 4) Pagamentos das assinaturas (o dinheiro cai na conta Mercado Pago da loja)
create table if not exists public.ff_assin_pagamentos (
  id uuid primary key default gen_random_uuid(),
  assinante_id uuid not null references public.ff_assinantes(id) on delete cascade,
  loja_id uuid not null references public.ff_lojas(id) on delete cascade,
  plano_id uuid not null references public.ff_assin_planos(id) on delete cascade,
  meses int not null check (meses in (1, 3, 6, 12)),
  valor numeric(10,2) not null check (valor >= 0),
  metodo text not null check (metodo in ('pix','cartao','manual')),
  status text not null default 'pendente' check (status in ('pendente','aprovado','recusado','estornado')),
  mp_ordem text not null default '',
  codigo text not null default '',
  valido_ate date,
  email_em timestamptz,
  criado_em timestamptz not null default now(),
  pago_em timestamptz
);
create index if not exists ff_assin_pag_assinante_idx on public.ff_assin_pagamentos (assinante_id, criado_em desc);
alter table public.ff_assin_pagamentos enable row level security;
drop policy if exists ff_assin_pag_ver on public.ff_assin_pagamentos;
create policy ff_assin_pag_ver on public.ff_assin_pagamentos for select to authenticated using (public.ff_minha_loja(loja_id));
grant select on public.ff_assin_pagamentos to authenticated;
grant all on public.ff_assin_pagamentos to service_role;

-- 5) Códigos digitais (jogos, gift cards, assinaturas…): a loja cadastra uma lista e o sistema entrega um por venda
alter table public.ff_produtos add column if not exists entrega_codigo boolean not null default false;
alter table public.ff_pedidos add column if not exists codigos_em timestamptz;
create table if not exists public.ff_codigos (
  id uuid primary key default gen_random_uuid(),
  loja_id uuid not null references public.ff_lojas(id) on delete cascade,
  produto_id uuid references public.ff_produtos(id) on delete cascade,
  plano_id uuid references public.ff_assin_planos(id) on delete cascade,
  codigo text not null check (length(trim(codigo)) between 1 and 500),
  usado_em timestamptz,
  pedido_id uuid references public.ff_pedidos(id) on delete set null,
  assinante_id uuid references public.ff_assinantes(id) on delete set null,
  criado_em timestamptz not null default now(),
  check (num_nonnulls(produto_id, plano_id) = 1)
);
create index if not exists ff_codigos_livres_idx on public.ff_codigos (produto_id, plano_id, criado_em) where usado_em is null;
create index if not exists ff_codigos_pedido_idx on public.ff_codigos (pedido_id) where pedido_id is not null;
alter table public.ff_codigos enable row level security;
drop policy if exists ff_codigos_ver on public.ff_codigos;
create policy ff_codigos_ver on public.ff_codigos for select to authenticated using (public.ff_minha_loja(loja_id));
drop policy if exists ff_codigos_criar on public.ff_codigos;
create policy ff_codigos_criar on public.ff_codigos for insert to authenticated with check (
  public.ff_minha_loja(loja_id) and usado_em is null and pedido_id is null and assinante_id is null
  and (produto_id is null or exists (select 1 from public.ff_produtos p where p.id = produto_id and p.loja_id = ff_codigos.loja_id))
  and (plano_id is null or exists (select 1 from public.ff_assin_planos a where a.id = plano_id and a.loja_id = ff_codigos.loja_id)));
drop policy if exists ff_codigos_apagar on public.ff_codigos;
create policy ff_codigos_apagar on public.ff_codigos for delete to authenticated using (public.ff_minha_loja(loja_id) and usado_em is null);
grant select, insert, delete on public.ff_codigos to authenticated;
grant all on public.ff_codigos to service_role;

-- Produto com código digital: o estoque é a quantidade de códigos livres (cadastrou +1, apagou −1)
create or replace function public.ff_codigos_estoque()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' and new.produto_id is not null then
    update public.ff_produtos set estoque = coalesce(estoque, 0) + 1 where id = new.produto_id and entrega_codigo;
  elsif tg_op = 'DELETE' and old.produto_id is not null and old.usado_em is null then
    update public.ff_produtos set estoque = greatest(coalesce(estoque, 0) - 1, 0) where id = old.produto_id and entrega_codigo;
  end if;
  return null;
end $$;
drop trigger if exists ff_codigos_estoque on public.ff_codigos;
create trigger ff_codigos_estoque after insert or delete on public.ff_codigos
  for each row execute function public.ff_codigos_estoque();

-- Liga/desliga "entregar código" num produto: o estoque passa a ser os códigos livres
create or replace function public.ff_produto_codigo_tg()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.entrega_codigo and (tg_op = 'INSERT' or not old.entrega_codigo) then
    new.estoque := (select count(*) from public.ff_codigos c where c.produto_id = new.id and c.usado_em is null);
    new.vende_por := 'un';
  end if;
  return new;
end $$;
drop trigger if exists ff_produto_codigo on public.ff_produtos;
create trigger ff_produto_codigo before insert or update of entrega_codigo on public.ff_produtos
  for each row execute function public.ff_produto_codigo_tg();

-- Separa os códigos de um pedido (um por unidade); devolve quantos faltaram
create or replace function public.ff_codigos_pedido(p_pedido uuid)
returns int language plpgsql volatile security definer set search_path = public as $$
declare it record; falta int := 0; ja int; k int;
begin
  for it in select i.produto_id, sum(i.qtd)::int as qtd from public.ff_pedido_itens i
              join public.ff_produtos p on p.id = i.produto_id
             where i.pedido_id = p_pedido and p.entrega_codigo group by i.produto_id loop
    select count(*) into ja from public.ff_codigos where pedido_id = p_pedido and produto_id = it.produto_id;
    for k in 1 .. greatest(it.qtd - ja, 0) loop
      update public.ff_codigos set usado_em = now(), pedido_id = p_pedido
       where id = (select id from public.ff_codigos where produto_id = it.produto_id and usado_em is null
                    order by criado_em limit 1 for update skip locked);
      if not found then falta := falta + 1; end if;
    end loop;
  end loop;
  return falta;
end $$;
revoke all on function public.ff_codigos_pedido(uuid) from public, anon, authenticated;
grant execute on function public.ff_codigos_pedido(uuid) to service_role;

-- Pedido pago online aprovado, ou aceito pela loja (Pix/dinheiro): separa e manda os códigos por e-mail
create or replace function public.ff_codigos_pedido_tg()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.codigos_em is null and new.status <> 'cancelado'
     and ((new.pagamento = 'mp' and new.mp_status = 'aprovado' and old.mp_status is distinct from 'aprovado')
          or (new.pagamento <> 'mp' and old.status = 'novo' and new.status in ('preparando','saiu','entregue')))
     and exists (select 1 from public.ff_pedido_itens i join public.ff_produtos p on p.id = i.produto_id
                  where i.pedido_id = new.id and p.entrega_codigo) then
    perform public.ff_codigos_pedido(new.id);
    perform public.ff_chamar_push(jsonb_build_object('acao', 'codigos_pedido', 'id', new.id));
  end if;
  return null;
end $$;
drop trigger if exists ff_pedidos_codigos on public.ff_pedidos;
create trigger ff_pedidos_codigos after update of status, mp_status on public.ff_pedidos
  for each row execute function public.ff_codigos_pedido_tg();

-- 6) Limite de assinantes por plano do GoPedido: Grátis 10, Profissional 50, Premium 150 (+ extras só no Premium)
alter table public.ff_plano_pagamentos drop constraint if exists ff_plano_pagamentos_plano_check;
alter table public.ff_plano_pagamentos add constraint ff_plano_pagamentos_plano_check check (plano in ('profissional','premium','extra','extra_assin'));
alter table public.ff_plano_pagamentos drop constraint if exists ff_plano_pag_qtd_check;
alter table public.ff_plano_pagamentos add constraint ff_plano_pag_qtd_check check ((plano in ('extra','extra_assin')) = (qtd > 0) and qtd between 0 and 5000);

create or replace function public.ff_preco_extra_assin() returns numeric language sql immutable as $$ select 1.00::numeric $$;
create or replace function public.ff_assin_limite(p_plano text) returns int language sql immutable as $$
  select case p_plano when 'premium' then 150 when 'profissional' then 50 else 10 end
$$;
create or replace function public.ff_extras_assin_de(p_user uuid)
returns int language sql stable security definer set search_path = public as $$
  select case when public.ff_plano_de(p_user) <> 'premium' then 0 else coalesce((
    select sum(g.qtd) from public.ff_plano_pagamentos g join auth.users u on lower(u.email) = g.email
     where u.id = p_user and g.plano = 'extra_assin' and g.status = 'aprovado' and g.valido_ate >= public.ff_hoje_sp()), 0)::int end
$$;
create or replace function public.ff_assin_max(p_dono uuid)
returns int language sql stable security definer set search_path = public as $$
  select public.ff_assin_limite(public.ff_plano_de(p_dono)) + public.ff_extras_assin_de(p_dono)
$$;
-- assinantes ativos de todas as lojas da conta
create or replace function public.ff_assin_usados(p_dono uuid)
returns int language sql stable security definer set search_path = public as $$
  select count(*)::int from public.ff_assinantes a join public.ff_lojas l on l.id = a.loja_id
   where l.dono = p_dono and a.status = 'ativo'
$$;
revoke all on function public.ff_extras_assin_de(uuid), public.ff_assin_max(uuid), public.ff_assin_usados(uuid) from public, anon, authenticated;
grant execute on function public.ff_extras_assin_de(uuid), public.ff_assin_max(uuid), public.ff_assin_usados(uuid) to service_role;

-- Trava: passar para "ativo" respeita o limite (o pagamento aprovado pelo Mercado Pago sempre ativa)
create or replace function public.ff_trava_assinante()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_dono uuid;
begin
  if new.status = 'ativo' and (tg_op = 'INSERT' or old.status <> 'ativo')
     and coalesce(current_setting('ff.assin_pago', true), '') <> '1' then
    select dono into v_dono from public.ff_lojas where id = new.loja_id;
    if public.ff_assin_usados(v_dono) >= public.ff_assin_max(v_dono) then raise exception 'limite_assinantes'; end if;
  end if;
  return new;
end $$;
drop trigger if exists ff_trava_assinante on public.ff_assinantes;
create trigger ff_trava_assinante before insert or update of status on public.ff_assinantes
  for each row execute function public.ff_trava_assinante();

-- Cabe mais um assinante nesta loja? (usado antes de cobrar um assinante novo)
create or replace function public.ff_assin_cabe(p_loja uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.ff_assin_usados(l.dono) < public.ff_assin_max(l.dono) from public.ff_lojas l where l.id = p_loja
$$;
revoke all on function public.ff_assin_cabe(uuid) from public, anon, authenticated;
grant execute on function public.ff_assin_cabe(uuid) to service_role;

-- Assinantes extras: só com o Premium ativo, R$ 1,00 por assinante por mês
create or replace function public.ff_extra_assin_calc(p_email text, p_qtd int, p_meses int)
returns json language plpgsql stable security definer set search_path = public as $$
declare a public.ff_assinaturas; hoje date := public.ff_hoje_sp();
begin
  if p_qtd is null or p_qtd < 5 or p_qtd > 2000 then return json_build_object('erro', 'extra_assin_qtd'); end if;
  if p_meses not between 1 and 3 then return json_build_object('erro', 'plano_invalido'); end if;
  select * into a from public.ff_assinaturas where email = lower(trim(p_email));
  if not found or a.plano <> 'premium' or (a.valido_ate is not null and a.valido_ate < hoje) then
    return json_build_object('erro', 'extra_so_premium');
  end if;
  return json_build_object('valor', round(p_qtd * public.ff_preco_extra_assin() * p_meses, 2), 'valido_ate', hoje + p_meses * 30,
                           'premium_ate', a.valido_ate, 'preco', public.ff_preco_extra_assin());
end $$;
revoke all on function public.ff_extra_assin_calc(text, int, int) from public, anon, authenticated;
grant execute on function public.ff_extra_assin_calc(text, int, int) to service_role;

create or replace function public.ff_plano_aplicar(p_pag uuid)
returns json language plpgsql security definer set search_path = public as $$
declare g public.ff_plano_pagamentos; c json; ate date;
begin
  select * into g from public.ff_plano_pagamentos where id = p_pag for update;
  if not found then raise exception 'pagamento_invalido'; end if;
  if g.status = 'aprovado' then return json_build_object('ok', true, 'valido_ate', g.valido_ate); end if;
  if g.plano in ('extra', 'extra_assin') then
    ate := public.ff_hoje_sp() + g.meses * 30;
    update public.ff_plano_pagamentos set status = 'aprovado', pago_em = now(), valido_ate = ate where id = g.id;
    return json_build_object('ok', true, 'valido_ate', ate);
  end if;
  c := public.ff_plano_calc(g.email, g.plano, g.meses);
  ate := coalesce((c ->> 'valido_ate')::date, greatest(coalesce((select valido_ate from public.ff_assinaturas where email = g.email), public.ff_hoje_sp()), public.ff_hoje_sp()) + g.meses * 30);
  insert into public.ff_assinaturas (email, plano, valido_ate, obs)
  values (g.email, g.plano, ate, 'pago pelo Mercado Pago')
  on conflict (email) do update set plano = excluded.plano, valido_ate = excluded.valido_ate, obs = 'pago pelo Mercado Pago', aviso_em = null;
  update public.ff_plano_pagamentos set status = 'aprovado', pago_em = now(), valido_ate = ate where id = g.id;
  return json_build_object('ok', true, 'valido_ate', ate);
end $$;
revoke all on function public.ff_plano_aplicar(uuid) from public, anon, authenticated;
grant execute on function public.ff_plano_aplicar(uuid) to service_role;

-- 7) Pagamento aprovado → estende a assinatura (soma ao tempo que falta) e separa o código, se o plano entrega código
create or replace function public.ff_assin_aplicar(p_pag uuid)
returns json language plpgsql volatile security definer set search_path = public as $$
declare g public.ff_assin_pagamentos; a public.ff_assinantes; pl public.ff_assin_planos; hoje date := public.ff_hoje_sp(); base date; ate date; cod text := '';
begin
  select * into g from public.ff_assin_pagamentos where id = p_pag for update;
  if not found then raise exception 'pagamento_invalido'; end if;
  if g.status = 'aprovado' then return json_build_object('ok', true, 'valido_ate', g.valido_ate, 'codigo', g.codigo); end if;
  select * into a from public.ff_assinantes where id = g.assinante_id for update;
  select * into pl from public.ff_assin_planos where id = g.plano_id;
  base := greatest(coalesce(a.valido_ate, hoje), hoje);
  ate := (base + make_interval(months => g.meses))::date;
  if pl.entrega_codigo then
    update public.ff_codigos set usado_em = now(), assinante_id = a.id
     where id = (select id from public.ff_codigos where plano_id = pl.id and usado_em is null order by criado_em limit 1 for update skip locked)
    returning codigo into cod;
    cod := coalesce(cod, '');
  end if;
  perform set_config('ff.assin_pago', '1', true);
  update public.ff_assinantes set status = 'ativo', valido_ate = ate, plano_id = g.plano_id, avisos = '{}'::jsonb where id = a.id;
  perform set_config('ff.assin_pago', '', true);
  update public.ff_assin_pagamentos set status = 'aprovado', pago_em = now(), valido_ate = ate, codigo = cod where id = g.id;
  return json_build_object('ok', true, 'valido_ate', ate, 'codigo', cod, 'faltou_codigo', pl.entrega_codigo and cod = '');
end $$;
revoke all on function public.ff_assin_aplicar(uuid) from public, anon, authenticated;
grant execute on function public.ff_assin_aplicar(uuid) to service_role;

-- O lojista registra um pagamento recebido por fora (dinheiro, Pix direto…) e a assinatura é renovada
create or replace function public.ff_assin_manual(p_assinante uuid, p_meses int, p_valor numeric)
returns json language plpgsql volatile security definer set search_path = public as $$
declare a public.ff_assinantes; v_dono uuid; v_pag uuid;
begin
  select * into a from public.ff_assinantes where id = p_assinante;
  if not found or not public.ff_minha_loja(a.loja_id) then raise exception 'sem_acesso'; end if;
  if a.status = 'cancelado' then raise exception 'assinante_cancelado'; end if;
  if p_meses not in (1, 3, 6, 12) then raise exception 'periodo_invalido'; end if;
  if a.status <> 'ativo' then
    select dono into v_dono from public.ff_lojas where id = a.loja_id;
    if public.ff_assin_usados(v_dono) >= public.ff_assin_max(v_dono) then raise exception 'limite_assinantes'; end if;
  end if;
  insert into public.ff_assin_pagamentos (assinante_id, loja_id, plano_id, meses, valor, metodo)
  values (a.id, a.loja_id, a.plano_id, p_meses, greatest(coalesce(p_valor, 0), 0), 'manual') returning id into v_pag;
  return public.ff_assin_aplicar(v_pag);
end $$;
revoke all on function public.ff_assin_manual(uuid, int, numeric) from public, anon;
grant execute on function public.ff_assin_manual(uuid, int, numeric) to authenticated;

-- E-mails automáticos: pagamento confirmado (com o código, se tiver) e convite para quem o lojista cadastrou
create or replace function public.ff_assin_pag_tg()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'aprovado' and old.status is distinct from 'aprovado' then
    perform public.ff_chamar_push(jsonb_build_object('acao', 'assin_pago', 'id', new.id));
  end if;
  return null;
end $$;
drop trigger if exists ff_assin_pag_email on public.ff_assin_pagamentos;
create trigger ff_assin_pag_email after update of status on public.ff_assin_pagamentos
  for each row execute function public.ff_assin_pag_tg();

create or replace function public.ff_assin_convite_tg()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.origem = 'painel' and new.status = 'pendente' then
    perform public.ff_chamar_push(jsonb_build_object('acao', 'assin_convite', 'id', new.id));
  end if;
  return null;
end $$;
drop trigger if exists ff_assin_convite on public.ff_assinantes;
create trigger ff_assin_convite after insert on public.ff_assinantes
  for each row execute function public.ff_assin_convite_tg();

-- 8) Plano vencido com assinantes acima do limite também bloqueia a loja
create or replace function public.ff_bloqueio_loja(p_loja uuid)
returns text language plpgsql stable security definer set search_path = public as $$
declare v_dono uuid; v_plano text; v_lojas int; v_prod int; v_rank int; v_ativos int;
begin
  select dono into v_dono from public.ff_lojas where id = p_loja;
  if v_dono is null then return ''; end if;
  v_plano := public.ff_plano_de(v_dono);
  select lojas, produtos into v_lojas, v_prod from public.ff_limites(v_plano);
  v_prod := v_prod + public.ff_extras_de(v_dono);
  select rk into v_rank from (select id, row_number() over (order by criado_em, id) rk from public.ff_lojas where dono = v_dono) x where id = p_loja;
  if v_rank > v_lojas then return 'lojas'; end if;
  select count(*) into v_ativos from public.ff_produtos p join public.ff_lojas l on l.id = p.loja_id where l.dono = v_dono and p.disponivel;
  if v_ativos > v_prod then return 'produtos'; end if;
  if public.ff_assin_usados(v_dono) > public.ff_assin_max(v_dono) then return 'assinantes'; end if;
  return '';
end $$;
revoke all on function public.ff_bloqueio_loja(uuid) from public;
grant execute on function public.ff_bloqueio_loja(uuid) to service_role;

create or replace function public.ff_meu_plano()
returns json language sql stable security definer set search_path = public as $$
  with d as (select public.ff_dono_de(auth.uid()) as dono)
  select json_build_object(
    'plano', pl.plano,
    'valido_ate', (select a.valido_ate from public.ff_assinaturas a join auth.users u on lower(u.email) = lower(a.email) where u.id = d.dono),
    'plano_pago', (select a.plano from public.ff_assinaturas a join auth.users u on lower(u.email) = lower(a.email) where u.id = d.dono),
    'hoje', public.ff_hoje_sp(),
    'lojas_max', li.lojas, 'produtos_max', li.produtos + public.ff_extras_de(d.dono), 'extras', public.ff_extras_de(d.dono),
    'extras_ate', (select min(g.valido_ate) from public.ff_plano_pagamentos g join auth.users u on lower(u.email) = g.email
                    where u.id = d.dono and g.plano = 'extra' and g.status = 'aprovado' and g.valido_ate >= public.ff_hoje_sp()),
    'lojas', (select count(*) from public.ff_lojas where dono = d.dono),
    'produtos', (select count(*) from public.ff_produtos p join public.ff_lojas l on l.id = p.loja_id where l.dono = d.dono),
    'produtos_ativos', (select count(*) from public.ff_produtos p join public.ff_lojas l on l.id = p.loja_id where l.dono = d.dono and p.disponivel),
    'lojas_bloqueadas', coalesce((select json_agg(x.id) from (select id, row_number() over (order by criado_em, id) rk from public.ff_lojas where dono = d.dono) x where x.rk > li.lojas), '[]'::json),
    'assinantes', public.ff_assin_usados(d.dono), 'assinantes_max', public.ff_assin_max(d.dono), 'extras_assin', public.ff_extras_assin_de(d.dono),
    'equipe', (select count(*) from public.ff_equipe where dono = d.dono),
    'equipe_max', public.ff_equipe_max(pl.plano),
    'sou_dono', d.dono = auth.uid())
  from d, lateral (select public.ff_plano_de(d.dono) as plano) pl, lateral public.ff_limites(pl.plano) li
$$;
revoke all on function public.ff_meu_plano() from public;
grant execute on function public.ff_meu_plano() to authenticated;

notify pgrst, 'reload schema';
