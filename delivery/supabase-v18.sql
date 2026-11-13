-- GoPedido v18 — equipe da loja (administradores)
-- Rode depois do v17. Pode rodar mais de uma vez sem problema.
--
-- • O dono adiciona administradores e escolhe a quais lojas cada um tem acesso (todas ou algumas).
-- • Limite por plano (sem contar o dono): Grátis 1 · Profissional 4 · Premium 8.
-- • O administrador cuida de pedidos, cardápio, promoções, horários e entrega das lojas liberadas.
-- • Só o dono mexe na chave Pix, na equipe, no plano e cria/apaga lojas.
-- • As contas da equipe são criadas, alteradas e removidas pela Edge Function "ff-equipe".

create table if not exists public.ff_equipe (
  id        uuid primary key default gen_random_uuid(),
  dono      uuid not null references auth.users(id) on delete cascade,
  user_id   uuid not null unique references auth.users(id) on delete cascade,
  nome      text not null default '',
  email     text not null default '',
  todas     boolean not null default true,
  lojas     uuid[] not null default '{}',
  criado_em timestamptz not null default now()
);
create index if not exists ff_equipe_dono_idx on public.ff_equipe (dono);
alter table public.ff_equipe enable row level security;
drop policy if exists ff_equipe_dono_ver on public.ff_equipe;
create policy ff_equipe_dono_ver on public.ff_equipe for select to authenticated
  using (dono = auth.uid() or user_id = auth.uid());
revoke all on public.ff_equipe from anon, authenticated;
grant select on public.ff_equipe to authenticated;   -- criar/alterar/remover só pela Edge Function

-- Quem é o dono "de verdade" do usuário logado (ele mesmo, ou o dono da equipe dele)
create or replace function public.ff_dono_de(p_user uuid)
returns uuid language sql stable security definer set search_path = public as $$
  select coalesce((select dono from public.ff_equipe where user_id = p_user), p_user)
$$;

create or replace function public.ff_sou_funcionario()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.ff_equipe where user_id = auth.uid())
$$;

-- Pode gerir esta loja? (dono ou administrador com acesso a ela)
create or replace function public.ff_minha_loja(p_loja uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.ff_lojas l
     where l.id = p_loja
       and (l.dono = auth.uid()
            or exists (select 1 from public.ff_equipe e
                        where e.user_id = auth.uid() and e.dono = l.dono
                          and (e.todas or l.id = any (e.lojas))))
  )
$$;

-- É o dono desta loja? (para o que é só do dono)
create or replace function public.ff_sou_dono(p_loja uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.ff_lojas where id = p_loja and dono = auth.uid())
$$;

revoke all on function public.ff_dono_de(uuid), public.ff_sou_funcionario(), public.ff_minha_loja(uuid), public.ff_sou_dono(uuid) from public;
grant execute on function public.ff_sou_funcionario(), public.ff_minha_loja(uuid), public.ff_sou_dono(uuid) to authenticated;

-- Lojas: ver/editar também para a equipe; criar e apagar só o dono
drop policy if exists ff_lojas_ver    on public.ff_lojas;
drop policy if exists ff_lojas_criar  on public.ff_lojas;
drop policy if exists ff_lojas_editar on public.ff_lojas;
drop policy if exists ff_lojas_apagar on public.ff_lojas;
create policy ff_lojas_ver on public.ff_lojas for select to anon, authenticated
  using ((ativa and verificacao = 'verificada') or dono = auth.uid() or public.ff_minha_loja(id) or public.ff_is_admin());
create policy ff_lojas_criar on public.ff_lojas for insert to authenticated
  with check (dono = auth.uid() and not public.ff_sou_funcionario());
create policy ff_lojas_editar on public.ff_lojas for update to authenticated
  using (public.ff_minha_loja(id)) with check (public.ff_minha_loja(id));
create policy ff_lojas_apagar on public.ff_lojas for delete to authenticated
  using (dono = auth.uid());

-- Proteção da loja: além de verificação e notas, a equipe não muda dono, Pix nem o bloqueio
create or replace function public.ff_protege_loja()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if public.ff_is_admin() or pg_trigger_depth() > 1 then return new; end if;
  if tg_op = 'INSERT' then
    new.verificacao := 'pendente'; new.verificacao_motivo := '';
    new.nota_media := null; new.nota_qtd := 0;
  else
    new.verificacao := old.verificacao; new.verificacao_motivo := old.verificacao_motivo;
    new.nota_media := old.nota_media; new.nota_qtd := old.nota_qtd;
    if auth.uid() is not null and auth.uid() <> old.dono then
      -- alguém da equipe (não o dono): não muda dono, bloqueio nem Pix
      new.dono := old.dono; new.ativa := old.ativa;
      new.pix_tipo := old.pix_tipo; new.pix_chave := old.pix_chave;
      new.pix_nome := old.pix_nome; new.pix_cidade := old.pix_cidade;
    elsif auth.uid() is not null then
      new.dono := old.dono; new.ativa := old.ativa;   -- o dono também não troca o dono nem se desbloqueia
    end if;
  end if;
  return new;
end;
$$;

-- Dados de verificação (CPF do responsável): só o dono
drop policy if exists ff_verif_dono on public.ff_verificacoes;
create policy ff_verif_dono on public.ff_verificacoes for all to authenticated
  using (public.ff_sou_dono(loja_id)) with check (public.ff_sou_dono(loja_id));

-- Comprovantes de Pix: dono e equipe da loja podem abrir
drop policy if exists ff_comp_ver on storage.objects;
create policy ff_comp_ver on storage.objects for select to authenticated
  using (bucket_id = 'ff-comprovantes' and exists (
    select 1 from public.ff_lojas l
     where l.id::text = (storage.foldername(name))[1] and public.ff_minha_loja(l.id)));

-- Código do motoboy: equipe também pode ver e gerar
create or replace function public.ff_codigo_entregador(p_loja uuid, p_novo boolean default false)
returns json language plpgsql volatile security definer set search_path = public as $$
declare a public.ff_entregador_acesso;
begin
  if not public.ff_minha_loja(p_loja) then raise exception 'sem_loja'; end if;
  select * into a from public.ff_entregador_acesso where loja_id = p_loja;
  if not found or p_novo or a.expira <= now() then
    insert into public.ff_entregador_acesso (loja_id, codigo, expira)
    values (p_loja, public.ff_gera_codigo(), now() + interval '8 hours')
    on conflict (loja_id) do update set codigo = excluded.codigo, expira = excluded.expira
    returning * into a;
  end if;
  return json_build_object('codigo', a.codigo, 'expira', a.expira);
end;
$$;
revoke all on function public.ff_codigo_entregador(uuid, boolean) from public;
grant execute on function public.ff_codigo_entregador(uuid, boolean) to authenticated;

-- Lojas que o usuário logado pode gerir (dono ou equipe)
create or replace function public.ff_minhas_lojas()
returns setof public.ff_lojas language sql stable security definer set search_path = public as $$
  select l.* from public.ff_lojas l where public.ff_minha_loja(l.id) order by l.criado_em
$$;
revoke all on function public.ff_minhas_lojas() from public;
grant execute on function public.ff_minhas_lojas() to authenticated;

-- Limite de administradores por plano
create or replace function public.ff_equipe_max(p_plano text)
returns int language sql immutable as $$
  select case p_plano when 'premium' then 8 when 'profissional' then 4 else 1 end
$$;

-- Trava: não passa do limite do plano do dono
create or replace function public.ff_trava_equipe()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (select count(*) from public.ff_equipe where dono = new.dono)
     >= public.ff_equipe_max(public.ff_plano_de(new.dono)) then
    raise exception 'limite_equipe';
  end if;
  if exists (select 1 from public.ff_lojas where dono = new.user_id) then
    raise exception 'ja_e_lojista';
  end if;
  return new;
end;
$$;
drop trigger if exists ff_equipe_trava on public.ff_equipe;
create trigger ff_equipe_trava before insert on public.ff_equipe
  for each row execute function public.ff_trava_equipe();

-- Resumo do plano: para a equipe mostra o plano do dono; inclui equipe e se é o dono
create or replace function public.ff_meu_plano()
returns json language sql stable security definer set search_path = public as $$
  with d as (select public.ff_dono_de(auth.uid()) as dono)
  select json_build_object(
    'plano', pl.plano,
    'valido_ate', (select a.valido_ate from public.ff_assinaturas a join auth.users u on lower(u.email) = lower(a.email) where u.id = d.dono),
    'lojas_max', li.lojas, 'produtos_max', li.produtos,
    'lojas', (select count(*) from public.ff_lojas where dono = d.dono),
    'produtos', (select count(*) from public.ff_produtos p join public.ff_lojas l on l.id = p.loja_id where l.dono = d.dono),
    'equipe', (select count(*) from public.ff_equipe where dono = d.dono),
    'equipe_max', public.ff_equipe_max(pl.plano),
    'sou_dono', d.dono = auth.uid())
  from d, lateral (select public.ff_plano_de(d.dono) as plano) pl, lateral public.ff_limites(pl.plano) li
$$;
revoke all on function public.ff_meu_plano() from public;
grant execute on function public.ff_meu_plano() to authenticated;
