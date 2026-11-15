-- GoPedido v27 — Pagamento dos planos pelo Mercado Pago (Pix ou cartão), liberação automática.
-- O lojista escolhe o plano e 1, 2 ou 3 meses; pagou, o plano é liberado na hora para o e-mail da conta.
-- Preços: Profissional 50 / 95 / 135 · Premium 100 / 195 / 285. Pode rodar mais de uma vez.

create table if not exists public.ff_plano_pagamentos (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null,
  email       text not null,
  plano       text not null check (plano in ('profissional','premium')),
  meses       int  not null check (meses between 1 and 3),
  valor       numeric(10,2) not null check (valor > 0),
  status      text not null default 'pendente' check (status in ('pendente','aprovado','recusado','estornado')),
  metodo      text not null default '' check (metodo in ('','pix','cartao')),
  mp_id       text not null default '',
  valido_ate  date,                       -- até quando ficou o plano depois deste pagamento
  criado_em   timestamptz not null default now(),
  pago_em     timestamptz
);
create index if not exists ff_plano_pag_user on public.ff_plano_pagamentos(user_id, criado_em desc);
alter table public.ff_plano_pagamentos enable row level security;
drop policy if exists ff_plano_pag_ver on public.ff_plano_pagamentos;
create policy ff_plano_pag_ver on public.ff_plano_pagamentos for select to authenticated
  using (user_id = auth.uid() or public.ff_is_admin());
revoke insert, update, delete on public.ff_plano_pagamentos from anon, authenticated;
grant select on public.ff_plano_pagamentos to authenticated;

-- aviso de vencimento (5 dias antes) não sai duas vezes
alter table public.ff_assinaturas add column if not exists aviso_em date;

-- Tabela de preços
create or replace function public.ff_preco_plano(p_plano text, p_meses int)
returns numeric language sql immutable as $$
  select case p_plano
    when 'profissional' then case p_meses when 1 then 50  when 2 then 95  when 3 then 135 end
    when 'premium'      then case p_meses when 1 then 100 when 2 then 195 when 3 then 285 end
  end::numeric
$$;

-- Quanto custa e até quando fica, para um e-mail (meses de 30 dias, no máximo ~3 meses à frente).
-- Mesmo plano ainda valendo: soma no fim. Trocou de plano: os dias que sobravam viram dias do plano novo, pelo valor.
create or replace function public.ff_plano_calc(p_email text, p_plano text, p_meses int)
returns json language plpgsql stable security definer set search_path = public as $$
declare
  a public.ff_assinaturas; hoje date := public.ff_hoje_sp(); v numeric := public.ff_preco_plano(p_plano, p_meses);
  base date; credito int := 0; ate date;
begin
  if v is null then return json_build_object('erro', 'plano_invalido'); end if;
  select * into a from public.ff_assinaturas where email = lower(trim(p_email));
  if found and a.plano <> 'gratis' and a.valido_ate is null then return json_build_object('erro', 'plano_vitalicio'); end if;
  if found and a.plano <> 'gratis' and a.valido_ate >= hoje then
    if a.plano = p_plano then
      base := a.valido_ate;
    else
      credito := floor((a.valido_ate - hoje) * public.ff_preco_plano(a.plano, 1) / public.ff_preco_plano(p_plano, 1));
      base := hoje + credito;
    end if;
  else
    base := hoje;
  end if;
  ate := base + p_meses * 30;
  if a.plano = p_plano and a.valido_ate >= hoje and ate > hoje + 95 then
    return json_build_object('erro', 'limite_meses', 'valido_ate', a.valido_ate);
  end if;
  return json_build_object('valor', v, 'valido_ate', ate, 'credito_dias', credito,
                           'atual', coalesce(a.plano, 'gratis'), 'atual_ate', a.valido_ate);
end $$;

-- Libera o plano de um pagamento aprovado (só o servidor chama; não faz nada se já liberou)
create or replace function public.ff_plano_aplicar(p_pag uuid)
returns json language plpgsql security definer set search_path = public as $$
declare g public.ff_plano_pagamentos; c json; ate date;
begin
  select * into g from public.ff_plano_pagamentos where id = p_pag for update;
  if not found then raise exception 'pagamento_invalido'; end if;
  if g.status = 'aprovado' then return json_build_object('ok', true, 'valido_ate', g.valido_ate); end if;
  c := public.ff_plano_calc(g.email, g.plano, g.meses);
  -- já pagou: se passou do limite por ter pago duas vezes, ainda assim soma (o dinheiro entrou)
  ate := coalesce((c ->> 'valido_ate')::date, greatest(coalesce((select valido_ate from public.ff_assinaturas where email = g.email), public.ff_hoje_sp()), public.ff_hoje_sp()) + g.meses * 30);
  insert into public.ff_assinaturas (email, plano, valido_ate, obs)
  values (g.email, g.plano, ate, 'pago pelo Mercado Pago')
  on conflict (email) do update set plano = excluded.plano, valido_ate = excluded.valido_ate, obs = 'pago pelo Mercado Pago', aviso_em = null;
  update public.ff_plano_pagamentos set status = 'aprovado', pago_em = now(), valido_ate = ate where id = g.id;
  return json_build_object('ok', true, 'valido_ate', ate);
end $$;

revoke all on function public.ff_plano_calc(text, text, int) from public, anon, authenticated;
revoke all on function public.ff_plano_aplicar(uuid) from public, anon, authenticated;
grant execute on function public.ff_plano_calc(text, text, int) to service_role;
grant execute on function public.ff_plano_aplicar(uuid) to service_role;
