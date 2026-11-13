-- =====================================================================
--  GoPedido — ATUALIZAÇÃO 9: planos (limite de lojas e produtos)
--  Grátis: 1 loja / 50 produtos · Profissional (R$ 50): 2 / 200 · Premium (R$ 100): 5 / 500
--  Rode DEPOIS das atualizações anteriores. Pode rodar de novo.
--
--  COMO LIBERAR UM PLANO PARA UM LOJISTA:
--    Supabase > Table Editor > ff_assinaturas > Insert row
--      email      = e-mail que o lojista usa no painel
--      plano      = profissional  (ou premium)
--      valido_ate = data do fim (ou vazio para não vencer)
--  Ou pelo SQL:
--    insert into ff_assinaturas (email, plano, valido_ate)
--    values ('lojista@email.com', 'profissional', '2026-12-31')
--    on conflict (email) do update set plano = excluded.plano, valido_ate = excluded.valido_ate;
-- =====================================================================

create table if not exists public.ff_assinaturas (
  email      text primary key,
  plano      text not null default 'gratis' check (plano in ('gratis','profissional','premium')),
  valido_ate date,
  obs        text not null default '',
  criado_em  timestamptz not null default now()
);
alter table public.ff_assinaturas enable row level security;
revoke all on public.ff_assinaturas from anon, authenticated;

-- Limites de cada plano
create or replace function public.ff_limites(p_plano text)
returns table (lojas int, produtos int) language sql immutable as $$
  select case p_plano when 'premium' then 5 when 'profissional' then 2 else 1 end,
         case p_plano when 'premium' then 500 when 'profissional' then 200 else 50 end
$$;

-- Plano atual de um usuário (vencido = grátis)
create or replace function public.ff_plano_de(p_user uuid)
returns text language sql stable security definer set search_path = public as $$
  select coalesce((
    select a.plano from public.ff_assinaturas a
      join auth.users u on lower(u.email) = lower(a.email)
     where u.id = p_user and (a.valido_ate is null or a.valido_ate >= public.ff_hoje_sp())
  ), 'gratis')
$$;

-- Resumo para o painel
create or replace function public.ff_meu_plano()
returns json language sql stable security definer set search_path = public as $$
  select json_build_object(
    'plano', pl.plano,
    'valido_ate', (select a.valido_ate from public.ff_assinaturas a join auth.users u on lower(u.email) = lower(a.email) where u.id = auth.uid()),
    'lojas_max', li.lojas, 'produtos_max', li.produtos,
    'lojas', (select count(*) from public.ff_lojas where dono = auth.uid()),
    'produtos', (select count(*) from public.ff_produtos p join public.ff_lojas l on l.id = p.loja_id where l.dono = auth.uid()))
  from (select public.ff_plano_de(auth.uid()) as plano) pl, lateral public.ff_limites(pl.plano) li
$$;
revoke all on function public.ff_meu_plano() from public;
grant execute on function public.ff_meu_plano() to authenticated;

-- Trava ao criar loja
create or replace function public.ff_trava_loja()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_max int;
begin
  select lojas into v_max from public.ff_limites(public.ff_plano_de(new.dono));
  if (select count(*) from public.ff_lojas where dono = new.dono) >= v_max then
    raise exception 'limite_lojas';
  end if;
  return new;
end;
$$;
drop trigger if exists ff_lojas_trava on public.ff_lojas;
create trigger ff_lojas_trava before insert on public.ff_lojas
  for each row execute function public.ff_trava_loja();

-- Trava ao criar produto (conta inteira, somando as lojas)
create or replace function public.ff_trava_produto()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_dono uuid; v_max int;
begin
  select dono into v_dono from public.ff_lojas where id = new.loja_id;
  select produtos into v_max from public.ff_limites(public.ff_plano_de(v_dono));
  if (select count(*) from public.ff_produtos p join public.ff_lojas l on l.id = p.loja_id where l.dono = v_dono) >= v_max then
    raise exception 'limite_produtos';
  end if;
  return new;
end;
$$;
drop trigger if exists ff_produtos_trava on public.ff_produtos;
create trigger ff_produtos_trava before insert on public.ff_produtos
  for each row execute function public.ff_trava_produto();
