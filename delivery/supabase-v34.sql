-- GoPedido · SQL v34 — Excluir loja (com as vendas guardadas)
-- Rode depois do v33. Pode rodar mais de uma vez.
--
-- • O lojista (só o dono da conta) pode excluir uma loja pelo painel, digitando o nome dela para confirmar.
-- • A loja some do site, do painel e das contas de limite do plano, e libera o endereço (slug).
-- • NADA de venda é apagado: pedidos, itens, pagamentos (Mercado Pago), etiquetas de envio, agendamentos,
--   assinantes, pagamentos de assinatura e códigos entregues continuam guardados.
-- • Fica um registro em ff_lojas_excluidas com uma foto dos dados da loja e o resumo do que ela vendeu.
-- • Ninguém mais consegue apagar a loja "de verdade" pelo site (isso apagaria os pedidos junto).
-- • As conexões com Mercado Pago e Melhor Envio da loja são desligadas (as chaves são apagadas).

-- 1) Marcas na loja
alter table public.ff_lojas add column if not exists excluida_em timestamptz;
alter table public.ff_lojas add column if not exists excluida_motivo text not null default '';
alter table public.ff_lojas add column if not exists slug_original text not null default '';
create index if not exists ff_lojas_excluida_idx on public.ff_lojas (dono) where excluida_em is null;

-- 2) Registro das lojas excluídas (só o administrador vê)
create table if not exists public.ff_lojas_excluidas (
  id uuid primary key default gen_random_uuid(),
  loja_id uuid not null,
  dono uuid,
  dono_email text not null default '',
  nome text not null default '',
  slug text not null default '',
  tipo text not null default '',
  motivo text not null default '',
  pedidos int not null default 0,
  pedidos_entregues int not null default 0,
  total_vendido numeric(12,2) not null default 0,
  agendamentos int not null default 0,
  assinantes int not null default 0,
  assinaturas_pagas int not null default 0,
  total_assinaturas numeric(12,2) not null default 0,
  dados jsonb not null default '{}'::jsonb,
  excluida_por uuid,
  excluida_em timestamptz not null default now()
);
create index if not exists ff_lojas_excluidas_loja_idx on public.ff_lojas_excluidas (loja_id);
alter table public.ff_lojas_excluidas enable row level security;
drop policy if exists ff_lojas_excluidas_admin on public.ff_lojas_excluidas;
create policy ff_lojas_excluidas_admin on public.ff_lojas_excluidas for select to authenticated using (public.ff_is_admin());
revoke all on public.ff_lojas_excluidas from anon, authenticated;
grant select on public.ff_lojas_excluidas to authenticated;
grant all on public.ff_lojas_excluidas to service_role;

-- 3) Ninguém apaga loja de verdade pelo site (apagaria os pedidos em cascata)
drop policy if exists ff_lojas_apagar on public.ff_lojas;

-- Loja excluída não aparece para o público nem para o lojista (só para o administrador)
drop policy if exists ff_lojas_ver on public.ff_lojas;
create policy ff_lojas_ver on public.ff_lojas for select to anon, authenticated
  using ((excluida_em is null and ((ativa and verificacao = 'verificada') or dono = auth.uid() or public.ff_minha_loja(id))) or public.ff_is_admin());

-- Loja excluída não é mais "minha" (fecha pedidos, produtos, equipe etc. para o lojista)
create or replace function public.ff_minha_loja(p_loja uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.ff_lojas l
     where l.id = p_loja and l.excluida_em is null
       and (l.dono = auth.uid()
            or exists (select 1 from public.ff_equipe e
                        where e.user_id = auth.uid() and e.dono = l.dono
                          and (e.todas or l.id = any (e.lojas))))
  )
$$;

-- Loja excluída não volta: só a própria exclusão mexe nela
create or replace function public.ff_lojas_excluida_trava()
returns trigger language plpgsql as $$
begin
  -- (notas de avaliação e outros resumos ainda podem atualizar; reabrir, religar ou trocar o endereço, não)
  if old.excluida_em is not null and coalesce(current_setting('ff.excluindo', true), '') <> '1'
     and (new.ativa or new.aberta or new.slug is distinct from old.slug or new.dono is distinct from old.dono
          or new.mp_conectado or new.horario_auto) then
    raise exception 'loja_excluida';
  end if;
  if new.excluida_em is distinct from old.excluida_em and coalesce(current_setting('ff.excluindo', true), '') <> '1' then
    raise exception 'loja_excluida';
  end if;
  return new;
end $$;
drop trigger if exists ff_lojas_excluida_trava on public.ff_lojas;
create trigger ff_lojas_excluida_trava before update on public.ff_lojas
  for each row execute function public.ff_lojas_excluida_trava();

-- 4) Limites do plano contam só as lojas que existem
create or replace function public.ff_trava_loja()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_max int;
begin
  select lojas into v_max from public.ff_limites(public.ff_plano_de(new.dono));
  if (select count(*) from public.ff_lojas where dono = new.dono and excluida_em is null) >= v_max then
    raise exception 'limite_lojas';
  end if;
  return new;
end;
$$;

create or replace function public.ff_trava_produto()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_dono uuid; v_max int; v_exc timestamptz;
begin
  select dono, excluida_em into v_dono, v_exc from public.ff_lojas where id = new.loja_id;
  if v_exc is not null then raise exception 'loja_excluida'; end if;
  select produtos into v_max from public.ff_limites(public.ff_plano_de(v_dono));
  v_max := v_max + public.ff_extras_de(v_dono);
  if (select count(*) from public.ff_produtos p join public.ff_lojas l on l.id = p.loja_id where l.dono = v_dono and l.excluida_em is null) >= v_max then
    raise exception 'limite_produtos';
  end if;
  return new;
end $$;

create or replace function public.ff_assin_usados(p_dono uuid)
returns int language sql stable security definer set search_path = public as $$
  select count(*)::int from public.ff_assinantes a join public.ff_lojas l on l.id = a.loja_id
   where l.dono = p_dono and l.excluida_em is null and a.status = 'ativo'
$$;
revoke all on function public.ff_assin_usados(uuid) from public, anon, authenticated;
grant execute on function public.ff_assin_usados(uuid) to service_role;

create or replace function public.ff_bloqueio_loja(p_loja uuid)
returns text language plpgsql stable security definer set search_path = public as $$
declare v_dono uuid; v_plano text; v_lojas int; v_prod int; v_rank int; v_ativos int;
begin
  select dono into v_dono from public.ff_lojas where id = p_loja and excluida_em is null;
  if v_dono is null then return ''; end if;
  v_plano := public.ff_plano_de(v_dono);
  select lojas, produtos into v_lojas, v_prod from public.ff_limites(v_plano);
  v_prod := v_prod + public.ff_extras_de(v_dono);
  select rk into v_rank from (select id, row_number() over (order by criado_em, id) rk from public.ff_lojas where dono = v_dono and excluida_em is null) x where id = p_loja;
  if v_rank > v_lojas then return 'lojas'; end if;
  select count(*) into v_ativos from public.ff_produtos p join public.ff_lojas l on l.id = p.loja_id where l.dono = v_dono and l.excluida_em is null and p.disponivel;
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
    'lojas', (select count(*) from public.ff_lojas where dono = d.dono and excluida_em is null),
    'produtos', (select count(*) from public.ff_produtos p join public.ff_lojas l on l.id = p.loja_id where l.dono = d.dono and l.excluida_em is null),
    'produtos_ativos', (select count(*) from public.ff_produtos p join public.ff_lojas l on l.id = p.loja_id where l.dono = d.dono and l.excluida_em is null and p.disponivel),
    'lojas_bloqueadas', coalesce((select json_agg(x.id) from (select id, row_number() over (order by criado_em, id) rk from public.ff_lojas where dono = d.dono and excluida_em is null) x where x.rk > li.lojas), '[]'::json),
    'assinantes', public.ff_assin_usados(d.dono), 'assinantes_max', public.ff_assin_max(d.dono), 'extras_assin', public.ff_extras_assin_de(d.dono),
    'equipe', (select count(*) from public.ff_equipe where dono = d.dono),
    'equipe_max', public.ff_equipe_max(pl.plano),
    'sou_dono', d.dono = auth.uid())
  from d, lateral (select public.ff_plano_de(d.dono) as plano) pl, lateral public.ff_limites(pl.plano) li
$$;
revoke all on function public.ff_meu_plano() from public;
grant execute on function public.ff_meu_plano() to authenticated;

-- Quem só tem loja excluída pode entrar na equipe de outra conta
create or replace function public.ff_trava_equipe()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (select count(*) from public.ff_equipe where dono = new.dono)
     >= public.ff_equipe_max(public.ff_plano_de(new.dono)) then
    raise exception 'limite_equipe';
  end if;
  if exists (select 1 from public.ff_lojas where dono = new.user_id and excluida_em is null) then
    raise exception 'ja_e_lojista';
  end if;
  return new;
end;
$$;

-- 5) O que impede excluir agora (o painel mostra antes de pedir a confirmação)
create or replace function public.ff_loja_pendencias(p_loja uuid)
returns json language plpgsql stable security definer set search_path = public as $$
declare l public.ff_lojas; v_ped int; v_ag int := 0; v_as int := 0;
begin
  select * into l from public.ff_lojas where id = p_loja and excluida_em is null;
  if l.id is null or l.dono <> auth.uid() then raise exception 'sem_permissao'; end if;
  select count(*) into v_ped from public.ff_pedidos
   where loja_id = p_loja and status in ('novo','preparando','saiu') and criado_em > now() - interval '3 days';
  begin
    select count(*) into v_ag from public.ff_agendamentos where loja_id = p_loja and status = 'agendado' and inicio > now();
  exception when undefined_table then v_ag := 0; end;
  begin
    select count(*) into v_as from public.ff_assinantes where loja_id = p_loja and status = 'ativo' and valido_ate >= public.ff_hoje_sp();
  exception when undefined_table then v_as := 0; end;
  return json_build_object('pedidos_abertos', v_ped, 'agendamentos_futuros', v_ag, 'assinantes_ativos', v_as,
    'pedidos', (select count(*) from public.ff_pedidos where loja_id = p_loja));
end $$;
revoke all on function public.ff_loja_pendencias(uuid) from public, anon;
grant execute on function public.ff_loja_pendencias(uuid) to authenticated;

-- 6) Excluir a loja
create or replace function public.ff_excluir_loja(p_loja uuid, p_confirma text, p_motivo text default '')
returns json language plpgsql volatile security definer set search_path = public as $$
declare l public.ff_lojas; p json; v_email text; v_ped int; v_ent int; v_tot numeric; v_ag int := 0; v_as int := 0; v_ap int := 0; v_ta numeric := 0;
begin
  select * into l from public.ff_lojas where id = p_loja for update;
  if l.id is null or l.excluida_em is not null then raise exception 'loja_nao_encontrada'; end if;
  if l.dono <> auth.uid() then raise exception 'so_dono_exclui'; end if;
  if lower(regexp_replace(trim(coalesce(p_confirma, '')), '\s+', ' ', 'g')) <> lower(regexp_replace(trim(l.nome), '\s+', ' ', 'g')) then
    raise exception 'confirmacao_errada';
  end if;
  p := public.ff_loja_pendencias(p_loja);
  if (p->>'pedidos_abertos')::int > 0 then raise exception 'loja_com_pedidos_abertos'; end if;
  if (p->>'agendamentos_futuros')::int > 0 then raise exception 'loja_com_agendamentos'; end if;
  if (p->>'assinantes_ativos')::int > 0 then raise exception 'loja_com_assinantes'; end if;

  -- resumo do que a loja vendeu (fica no registro)
  select count(*), count(*) filter (where status = 'entregue'), coalesce(sum(total) filter (where status = 'entregue'), 0)
    into v_ped, v_ent, v_tot from public.ff_pedidos where loja_id = p_loja;
  begin select count(*) into v_ag from public.ff_agendamentos where loja_id = p_loja; exception when undefined_table then null; end;
  begin
    select count(*) into v_as from public.ff_assinantes where loja_id = p_loja;
    select count(*), coalesce(sum(valor), 0) into v_ap, v_ta from public.ff_assin_pagamentos where loja_id = p_loja and status = 'aprovado';
  exception when undefined_table then null; end;
  select email into v_email from auth.users where id = l.dono;

  insert into public.ff_lojas_excluidas (loja_id, dono, dono_email, nome, slug, tipo, motivo, pedidos, pedidos_entregues, total_vendido,
         agendamentos, assinantes, assinaturas_pagas, total_assinaturas, dados, excluida_por)
  values (l.id, l.dono, coalesce(v_email, ''), l.nome, l.slug, coalesce(l.tipo, ''), left(trim(coalesce(p_motivo, '')), 500),
          v_ped, v_ent, v_tot, v_ag, v_as, v_ap, v_ta, to_jsonb(l), auth.uid());

  perform set_config('ff.excluindo', '1', true);
  update public.ff_lojas set excluida_em = now(), excluida_motivo = left(trim(coalesce(p_motivo, '')), 500),
         slug_original = slug, slug = left(slug, 60) || '-excluida-' || substr(replace(id::text, '-', ''), 1, 8),
         ativa = false, aberta = false, horario_auto = false, mp_conectado = false
   where id = p_loja;
  begin update public.ff_lojas set me_conectado = false where id = p_loja; exception when undefined_column then null; end;
  perform set_config('ff.excluindo', '', true);

  -- desliga o que ainda poderia gerar cobrança, aviso ou acesso (sem apagar histórico)
  update public.ff_produtos set disponivel = false where loja_id = p_loja and disponivel;
  begin delete from public.ff_mp_contas where loja_id = p_loja; exception when undefined_table then null; end;
  begin delete from public.ff_me_contas where loja_id = p_loja; exception when undefined_table then null; end;
  begin delete from public.ff_entregador_acesso where loja_id = p_loja; exception when undefined_table then null; end;
  begin
    update public.ff_assin_planos set ativo = false where loja_id = p_loja;
    update public.ff_assinantes set status = 'cancelado' where loja_id = p_loja and status = 'pendente';
  exception when undefined_table then null; end;
  update public.ff_equipe set lojas = array_remove(lojas, p_loja) where p_loja = any (lojas);

  return json_build_object('ok', true, 'pedidos_guardados', v_ped);
end $$;
revoke all on function public.ff_excluir_loja(uuid, text, text) from public, anon;
grant execute on function public.ff_excluir_loja(uuid, text, text) to authenticated;

-- 7) Administrador: lojas (com as excluídas marcadas) e o registro
create or replace function public.ff_admin_lojas()
returns json language plpgsql stable security definer set search_path = public as $$
begin
  if not public.ff_is_admin() then raise exception 'sem_permissao'; end if;
  return coalesce((select json_agg(x order by x.ordem, x.criado_em desc) from (
    select l.id, l.slug, l.nome, l.descricao, l.imagem_url, l.cnpj, l.telefone, l.endereco, l.pix_tipo, l.pix_chave, l.pix_nome,
           l.verificacao, l.verificacao_motivo, l.ativa, l.aberta, l.criado_em, l.nota_media, l.nota_qtd,
           l.excluida_em, l.excluida_motivo, l.slug_original,
           u.email as dono_email, v.responsavel_nome, v.responsavel_cpf,
           (select count(*) from public.ff_pedidos p where p.loja_id = l.id) as pedidos,
           (select count(*) from public.ff_produtos p where p.loja_id = l.id) as produtos,
           (select count(*) from public.ff_denuncias d where d.loja_id = l.id and not d.resolvida) as denuncias,
           (select row_to_json(e) from (select pedidos_entregues, total_vendido, assinaturas_pagas, total_assinaturas, motivo
              from public.ff_lojas_excluidas e where e.loja_id = l.id order by e.excluida_em desc limit 1) e) as registro,
           case when l.excluida_em is not null then 3 when l.verificacao = 'pendente' then 0 when l.verificacao = 'recusada' then 2 else 1 end as ordem
      from public.ff_lojas l
      left join auth.users u on u.id = l.dono
      left join public.ff_verificacoes v on v.loja_id = l.id) x), '[]'::json);
end;
$$;
revoke all on function public.ff_admin_lojas() from public, anon;
grant execute on function public.ff_admin_lojas() to authenticated;

notify pgrst, 'reload schema';
