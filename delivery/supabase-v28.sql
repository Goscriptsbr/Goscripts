-- GoPedido v28 — Limites novos e produtos extras só no Premium.
-- Profissional: 150 produtos (antes 200) · Premium: 350 (antes 500).
-- No Premium, o lojista pode comprar produtos a mais (digita a quantidade): R$ 0,20 por produto por mês.
-- Quem já tem mais produtos que o novo limite não perde nada: só não cadastra novos. Pode rodar mais de uma vez.

create or replace function public.ff_limites(p_plano text)
returns table (lojas int, produtos int) language sql immutable as $$
  select case p_plano when 'premium' then 5 when 'profissional' then 2 else 1 end,
         case p_plano when 'premium' then 350 when 'profissional' then 150 else 30 end
$$;

-- pagamentos de plano passam a aceitar "extra" (produtos a mais) com a quantidade
alter table public.ff_plano_pagamentos add column if not exists qtd int not null default 0;
alter table public.ff_plano_pagamentos drop constraint if exists ff_plano_pagamentos_plano_check;
alter table public.ff_plano_pagamentos add constraint ff_plano_pagamentos_plano_check check (plano in ('profissional','premium','extra'));
alter table public.ff_plano_pagamentos drop constraint if exists ff_plano_pag_qtd_check;
alter table public.ff_plano_pagamentos add constraint ff_plano_pag_qtd_check check ((plano = 'extra') = (qtd > 0) and qtd between 0 and 5000);

create or replace function public.ff_preco_extra() returns numeric language sql immutable as $$ select 0.20::numeric $$;

-- produtos extras valendo hoje (só contam com o Premium ativo)
create or replace function public.ff_extras_de(p_user uuid)
returns int language sql stable security definer set search_path = public as $$
  select case when public.ff_plano_de(p_user) <> 'premium' then 0 else coalesce((
    select sum(g.qtd) from public.ff_plano_pagamentos g join auth.users u on lower(u.email) = g.email
     where u.id = p_user and g.plano = 'extra' and g.status = 'aprovado' and g.valido_ate >= public.ff_hoje_sp()), 0)::int end
$$;

-- trava de produto: limite do plano + extras
create or replace function public.ff_trava_produto()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_dono uuid; v_max int;
begin
  select dono into v_dono from public.ff_lojas where id = new.loja_id;
  select produtos into v_max from public.ff_limites(public.ff_plano_de(v_dono));
  v_max := v_max + public.ff_extras_de(v_dono);
  if (select count(*) from public.ff_produtos p join public.ff_lojas l on l.id = p.loja_id where l.dono = v_dono) >= v_max then
    raise exception 'limite_produtos';
  end if;
  return new;
end $$;

-- resumo do plano no painel: mostra os extras
create or replace function public.ff_meu_plano()
returns json language sql stable security definer set search_path = public as $$
  with d as (select public.ff_dono_de(auth.uid()) as dono)
  select json_build_object(
    'plano', pl.plano,
    'valido_ate', (select a.valido_ate from public.ff_assinaturas a join auth.users u on lower(u.email) = lower(a.email) where u.id = d.dono),
    'lojas_max', li.lojas, 'produtos_max', li.produtos + public.ff_extras_de(d.dono), 'extras', public.ff_extras_de(d.dono),
    'extras_ate', (select min(g.valido_ate) from public.ff_plano_pagamentos g join auth.users u on lower(u.email) = g.email
                    where u.id = d.dono and g.plano = 'extra' and g.status = 'aprovado' and g.valido_ate >= public.ff_hoje_sp()),
    'lojas', (select count(*) from public.ff_lojas where dono = d.dono),
    'produtos', (select count(*) from public.ff_produtos p join public.ff_lojas l on l.id = p.loja_id where l.dono = d.dono),
    'equipe', (select count(*) from public.ff_equipe where dono = d.dono),
    'equipe_max', public.ff_equipe_max(pl.plano),
    'sou_dono', d.dono = auth.uid())
  from d, lateral (select public.ff_plano_de(d.dono) as plano) pl, lateral public.ff_limites(pl.plano) li
$$;
revoke all on function public.ff_meu_plano() from public;
grant execute on function public.ff_meu_plano() to authenticated;

-- Preço e validade dos extras (só para quem tem Premium ativo)
create or replace function public.ff_extra_calc(p_email text, p_qtd int, p_meses int)
returns json language plpgsql stable security definer set search_path = public as $$
declare a public.ff_assinaturas; hoje date := public.ff_hoje_sp();
begin
  if p_qtd is null or p_qtd < 10 or p_qtd > 2000 then return json_build_object('erro', 'extra_qtd'); end if;
  if p_meses not between 1 and 3 then return json_build_object('erro', 'plano_invalido'); end if;
  select * into a from public.ff_assinaturas where email = lower(trim(p_email));
  if not found or a.plano <> 'premium' or (a.valido_ate is not null and a.valido_ate < hoje) then
    return json_build_object('erro', 'extra_so_premium');
  end if;
  return json_build_object('valor', round(p_qtd * public.ff_preco_extra() * p_meses, 2), 'valido_ate', hoje + p_meses * 30,
                           'premium_ate', a.valido_ate, 'preco', public.ff_preco_extra());
end $$;

-- liberar: extras não mexem na assinatura, só ficam aprovados com a validade
create or replace function public.ff_plano_aplicar(p_pag uuid)
returns json language plpgsql security definer set search_path = public as $$
declare g public.ff_plano_pagamentos; c json; ate date;
begin
  select * into g from public.ff_plano_pagamentos where id = p_pag for update;
  if not found then raise exception 'pagamento_invalido'; end if;
  if g.status = 'aprovado' then return json_build_object('ok', true, 'valido_ate', g.valido_ate); end if;
  if g.plano = 'extra' then
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

revoke all on function public.ff_extra_calc(text, int, int) from public, anon, authenticated;
revoke all on function public.ff_plano_aplicar(uuid) from public, anon, authenticated;
grant execute on function public.ff_extra_calc(text, int, int) to service_role;
grant execute on function public.ff_plano_aplicar(uuid) to service_role;
