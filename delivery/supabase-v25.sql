-- GoPedido v25 — Agendamentos (salão, barbearia, manicure, estética…)
-- Novo tipo de loja "agenda": serviços, profissionais com agenda própria e horários marcados pelo cliente.
-- Não mexe em nada das lojas de delivery. Pode rodar mais de uma vez.

create extension if not exists btree_gist;

-- 1) Tipo de loja novo + configurações da agenda
alter table public.ff_lojas drop constraint if exists ff_lojas_tipo_check;
alter table public.ff_lojas add constraint ff_lojas_tipo_check
  check (tipo in ('restaurante','mercado','farmacia','pet','bebidas','variedades','outros','agenda'));

alter table public.ff_lojas add column if not exists ag_intervalo   int not null default 30;  -- de quantos em quantos minutos aparecem os horários
alter table public.ff_lojas add column if not exists ag_antecedencia int not null default 60; -- marcar com pelo menos X minutos de antecedência
alter table public.ff_lojas add column if not exists ag_dias        int not null default 30;  -- até quantos dias para frente
alter table public.ff_lojas add column if not exists ag_cancelar_h  int not null default 2;   -- cliente cancela sozinho até X horas antes
alter table public.ff_lojas drop constraint if exists ff_lojas_ag_check;
alter table public.ff_lojas add constraint ff_lojas_ag_check check (
  ag_intervalo in (5,10,15,20,30,45,60) and ag_antecedencia between 0 and 10080
  and ag_dias between 1 and 180 and ag_cancelar_h between 0 and 168);

-- 2) Serviços
create table if not exists public.ff_servicos (
  id          uuid primary key default gen_random_uuid(),
  loja_id     uuid not null references public.ff_lojas(id) on delete cascade,
  nome        text not null check (length(trim(nome)) between 2 and 80),
  descricao   text not null default '' check (length(descricao) <= 300),
  preco       numeric(10,2) not null default 0 check (preco >= 0 and preco <= 100000),
  preco_a_partir boolean not null default false,          -- "a partir de R$ 40"
  duracao_min int not null check (duracao_min between 5 and 720),
  ativo       boolean not null default true,
  ordem       int not null default 0,
  criado_em   timestamptz not null default now()
);
create index if not exists ff_servicos_loja on public.ff_servicos(loja_id);

-- 3) Profissionais (cada um com os próprios horários)
-- horarios: {"0":{"aberto":false},"1":{"aberto":true,"ini":"09:00","fim":"18:00","pausa_ini":"12:00","pausa_fim":"13:00"},...}
-- servicos: lista de ids que a pessoa faz (vazio = faz todos)
create table if not exists public.ff_profissionais (
  id         uuid primary key default gen_random_uuid(),
  loja_id    uuid not null references public.ff_lojas(id) on delete cascade,
  nome       text not null check (length(trim(nome)) between 2 and 60),
  foto_url   text not null default '',
  horarios   jsonb not null default '{}'::jsonb,
  servicos   uuid[] not null default '{}',
  ativo      boolean not null default true,
  ordem      int not null default 0,
  criado_em  timestamptz not null default now()
);
create index if not exists ff_profissionais_loja on public.ff_profissionais(loja_id);

-- 4) Agendamentos
create table if not exists public.ff_agendamentos (
  id              uuid primary key default gen_random_uuid(),
  loja_id         uuid not null references public.ff_lojas(id) on delete cascade,
  profissional_id uuid not null references public.ff_profissionais(id) on delete restrict,
  servico_id      uuid references public.ff_servicos(id) on delete set null,
  numero          int not null default 0,
  token           text not null unique default replace(gen_random_uuid()::text, '-', ''),
  servico_nome    text not null,
  profissional_nome text not null,
  preco           numeric(10,2) not null default 0,
  duracao_min     int not null,
  inicio          timestamptz not null,
  fim             timestamptz not null,
  cliente_id      uuid,
  cliente_nome    text not null,
  cliente_telefone text not null,
  cliente_email   text not null default '',
  observacao      text not null default '',
  status          text not null default 'agendado' check (status in ('agendado','concluido','cancelado','faltou')),
  cancelado_por   text not null default '' check (cancelado_por in ('','cliente','loja')),
  origem          text not null default 'site' check (origem in ('site','painel')),
  emails          jsonb not null default '{}'::jsonb,
  lembrete_em     timestamptz,
  criado_em       timestamptz not null default now(),
  atualizado_em   timestamptz not null default now(),
  check (fim > inicio)
);
create index if not exists ff_ag_loja_inicio on public.ff_agendamentos(loja_id, inicio);
create index if not exists ff_ag_lembrete on public.ff_agendamentos(inicio) where status = 'agendado' and lembrete_em is null;
-- A regra que impede dois clientes no mesmo horário com a mesma pessoa
alter table public.ff_agendamentos drop constraint if exists ff_ag_sem_conflito;
alter table public.ff_agendamentos add constraint ff_ag_sem_conflito
  exclude using gist (profissional_id with =, tstzrange(inicio, fim, '[)') with &&) where (status <> 'cancelado');

-- 5) Quem vê e quem mexe
alter table public.ff_servicos enable row level security;
alter table public.ff_profissionais enable row level security;
alter table public.ff_agendamentos enable row level security;

drop policy if exists ff_serv_ver on public.ff_servicos;
drop policy if exists ff_serv_gerir on public.ff_servicos;
create policy ff_serv_ver on public.ff_servicos for select to anon, authenticated
  using (ativo and exists (select 1 from public.ff_lojas l where l.id = loja_id and l.ativa and l.verificacao = 'verificada')
         or public.ff_minha_loja(loja_id) or public.ff_is_admin());
create policy ff_serv_gerir on public.ff_servicos for all to authenticated
  using (public.ff_minha_loja(loja_id)) with check (public.ff_minha_loja(loja_id));

drop policy if exists ff_prof_ver on public.ff_profissionais;
drop policy if exists ff_prof_gerir on public.ff_profissionais;
create policy ff_prof_ver on public.ff_profissionais for select to anon, authenticated
  using (ativo and exists (select 1 from public.ff_lojas l where l.id = loja_id and l.ativa and l.verificacao = 'verificada')
         or public.ff_minha_loja(loja_id) or public.ff_is_admin());
create policy ff_prof_gerir on public.ff_profissionais for all to authenticated
  using (public.ff_minha_loja(loja_id)) with check (public.ff_minha_loja(loja_id));

-- Agendamentos: a loja vê e atualiza os dela; o cliente só pelo link (token), via funções abaixo
drop policy if exists ff_ag_ver on public.ff_agendamentos;
drop policy if exists ff_ag_editar on public.ff_agendamentos;
create policy ff_ag_ver on public.ff_agendamentos for select to authenticated
  using (public.ff_minha_loja(loja_id) or public.ff_is_admin());
create policy ff_ag_editar on public.ff_agendamentos for update to authenticated
  using (public.ff_minha_loja(loja_id)) with check (public.ff_minha_loja(loja_id));
grant select, update on public.ff_agendamentos to authenticated;
grant select on public.ff_servicos, public.ff_profissionais to anon, authenticated;
grant insert, update, delete on public.ff_servicos, public.ff_profissionais to authenticated;

-- A loja só pode mudar situação, horário, profissional e observação; o resto é do servidor
create or replace function public.ff_ag_guarda() returns trigger language plpgsql as $$
declare v_dur int;
begin
  new.id := old.id; new.loja_id := old.loja_id; new.token := old.token; new.numero := old.numero;
  new.cliente_id := old.cliente_id; new.origem := old.origem; new.criado_em := old.criado_em;
  -- e-mails e lembrete: só o servidor (função de e-mail) marca
  if current_user not in ('service_role', 'postgres', 'supabase_admin')
     and coalesce(current_setting('request.jwt.claim.role', true), '') <> 'service_role' and not public.ff_is_admin() then
    new.emails := old.emails; new.lembrete_em := case when new.inicio <> old.inicio then null else old.lembrete_em end;
  end if;
  if new.status = 'cancelado' and old.status <> 'cancelado' and new.cancelado_por = '' then new.cancelado_por := 'loja'; end if;
  if new.status <> 'cancelado' then new.cancelado_por := ''; end if;
  -- trocou de profissional: tem que ser da mesma loja
  if new.profissional_id <> old.profissional_id then
    if not exists (select 1 from public.ff_profissionais where id = new.profissional_id and loja_id = old.loja_id) then
      raise exception 'profissional_invalido';
    end if;
    select nome into new.profissional_nome from public.ff_profissionais where id = new.profissional_id;
  end if;
  -- remarcou: mantém a duração e manda o lembrete de novo
  if new.inicio <> old.inicio then
    new.fim := new.inicio + make_interval(mins => old.duracao_min);
    new.lembrete_em := null; new.emails := new.emails - 'ag_lembrete';
  else
    new.fim := old.fim;
  end if;
  new.duracao_min := old.duracao_min; new.preco := old.preco; new.servico_nome := old.servico_nome; new.servico_id := old.servico_id;
  new.atualizado_em := now();
  return new;
end $$;
drop trigger if exists ff_ag_guarda on public.ff_agendamentos;
create trigger ff_ag_guarda before update on public.ff_agendamentos for each row execute function public.ff_ag_guarda();

-- 6) Horário de trabalho de um profissional num dia (minutos desde 0h, horário de Brasília)
create or replace function public.ff_prof_trabalha(p_hor jsonb, p_ini timestamptz, p_fim timestamptz)
returns boolean language plpgsql immutable as $$
declare
  li timestamp := p_ini at time zone 'America/Sao_Paulo';
  lf timestamp := p_fim at time zone 'America/Sao_Paulo';
  d jsonb := p_hor -> extract(dow from li)::int::text;
  hi int; hf int; mi int; mf int; pi int; pf int;
begin
  if d is null or coalesce((d ->> 'aberto')::boolean, false) = false then return false; end if;
  if li::date <> lf::date and not (lf::time = '00:00' and lf::date = li::date + 1) then return false; end if;
  hi := split_part(d ->> 'ini', ':', 1)::int * 60 + split_part(d ->> 'ini', ':', 2)::int;
  hf := split_part(d ->> 'fim', ':', 1)::int * 60 + split_part(d ->> 'fim', ':', 2)::int;
  if hf = 0 then hf := 1440; end if;
  mi := extract(hour from li)::int * 60 + extract(minute from li)::int;
  mf := case when lf::time = '00:00' and lf::date > li::date then 1440 else extract(hour from lf)::int * 60 + extract(minute from lf)::int end;
  if mi < hi or mf > hf then return false; end if;
  if coalesce(d ->> 'pausa_ini', '') <> '' and coalesce(d ->> 'pausa_fim', '') <> '' then
    pi := split_part(d ->> 'pausa_ini', ':', 1)::int * 60 + split_part(d ->> 'pausa_ini', ':', 2)::int;
    pf := split_part(d ->> 'pausa_fim', ':', 1)::int * 60 + split_part(d ->> 'pausa_fim', ':', 2)::int;
    if pf > pi and mi < pf and mf > pi then return false; end if;
  end if;
  return true;
exception when others then return false;
end $$;

-- 7) Horários ocupados (só início/fim, sem dados dos clientes) para a página mostrar os livres
create or replace function public.ff_agenda_ocupado(p_loja uuid, p_de date, p_dias int default 1)
returns table (profissional_id uuid, inicio timestamptz, fim timestamptz)
language sql stable security definer set search_path = public as $$
  select a.profissional_id, a.inicio, a.fim
    from public.ff_agendamentos a
   where a.loja_id = p_loja and a.status <> 'cancelado'
     and a.inicio < ((p_de + least(greatest(p_dias, 1), 62))::timestamp at time zone 'America/Sao_Paulo')
     and a.fim   > (p_de::timestamp at time zone 'America/Sao_Paulo')
$$;
grant execute on function public.ff_agenda_ocupado(uuid, date, int) to anon, authenticated;

-- 8) Marcar um horário (cliente pelo site, ou a própria loja pelo painel)
create or replace function public.ff_agendar(
  p_loja uuid, p_servico uuid, p_profissional uuid, p_inicio timestamptz, p_cliente jsonb)
returns json language plpgsql security definer set search_path = public as $$
declare
  l public.ff_lojas; s public.ff_servicos; pr public.ff_profissionais; a public.ff_agendamentos;
  v_staff boolean := public.ff_minha_loja(p_loja);
  v_fim timestamptz; v_num int; v_nome text; v_tel text; v_email text;
begin
  select * into l from public.ff_lojas where id = p_loja and ativa for update;
  if not found or l.tipo <> 'agenda' then raise exception 'loja_invalida'; end if;
  if not v_staff and l.verificacao <> 'verificada' then raise exception 'loja_em_analise'; end if;
  select * into s from public.ff_servicos where id = p_servico and loja_id = l.id and (ativo or v_staff);
  if not found then raise exception 'servico_invalido'; end if;

  v_nome := left(trim(coalesce(p_cliente ->> 'nome', '')), 80);
  v_tel := left(trim(coalesce(p_cliente ->> 'telefone', '')), 30);
  v_email := lower(left(trim(coalesce(p_cliente ->> 'email', '')), 120));
  if length(v_nome) < 2 then raise exception 'nome_obrigatorio'; end if;
  if length(regexp_replace(v_tel, '\D', '', 'g')) < 10 and not v_staff then raise exception 'telefone_invalido'; end if;
  if v_email = '' and not v_staff then raise exception 'email_obrigatorio_agenda'; end if;
  if v_email <> '' and v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'email_invalido'; end if;

  -- horário redondo, dentro da antecedência e do limite de dias (a loja pode marcar fora disso)
  if extract(second from p_inicio) <> 0 then raise exception 'horario_invalido'; end if;
  if not v_staff then
    if p_inicio < now() + make_interval(mins => l.ag_antecedencia) then raise exception 'horario_passou'; end if;
    if p_inicio > now() + make_interval(days => l.ag_dias + 1) then raise exception 'horario_longe'; end if;
  elsif p_inicio < now() - interval '1 day' then raise exception 'horario_passou';
  end if;
  v_fim := p_inicio + make_interval(mins => s.duracao_min);

  -- profissional escolhido, ou o primeiro livre que faz o serviço
  if p_profissional is not null then
    select * into pr from public.ff_profissionais
     where id = p_profissional and loja_id = l.id and (ativo or v_staff)
       and (cardinality(servicos) = 0 or s.id = any(servicos));
    if not found then raise exception 'profissional_invalido'; end if;
    if not v_staff and not public.ff_prof_trabalha(pr.horarios, p_inicio, v_fim) then raise exception 'fora_do_horario'; end if;
  else
    select * into pr from public.ff_profissionais p
     where p.loja_id = l.id and p.ativo and (cardinality(p.servicos) = 0 or s.id = any(p.servicos))
       and public.ff_prof_trabalha(p.horarios, p_inicio, v_fim)
       and not exists (select 1 from public.ff_agendamentos x where x.profissional_id = p.id and x.status <> 'cancelado'
                         and tstzrange(x.inicio, x.fim, '[)') && tstzrange(p_inicio, v_fim, '[)'))
     order by p.ordem, p.nome limit 1;
    if not found then raise exception 'horario_ocupado'; end if;
  end if;

  -- um mesmo telefone não segura muitos horários futuros na mesma loja (evita trote)
  if not v_staff and (select count(*) from public.ff_agendamentos
                       where loja_id = l.id and status = 'agendado' and inicio > now()
                         and regexp_replace(cliente_telefone, '\D', '', 'g') = regexp_replace(v_tel, '\D', '', 'g')) >= 5 then
    raise exception 'limite_agendamentos';
  end if;

  select coalesce(max(numero), 0) + 1 into v_num from public.ff_agendamentos where loja_id = l.id;
  begin
    insert into public.ff_agendamentos
      (loja_id, profissional_id, servico_id, numero, servico_nome, profissional_nome, preco, duracao_min,
       inicio, fim, cliente_id, cliente_nome, cliente_telefone, cliente_email, observacao, origem)
    values
      (l.id, pr.id, s.id, v_num, s.nome, pr.nome, s.preco, s.duracao_min,
       p_inicio, v_fim, auth.uid(), v_nome, v_tel, v_email, left(trim(coalesce(p_cliente ->> 'obs', '')), 300),
       case when v_staff and coalesce((p_cliente ->> 'painel')::boolean, false) then 'painel' else 'site' end)
    returning * into a;
  exception when exclusion_violation then raise exception 'horario_ocupado';
  end;
  return json_build_object('token', a.token, 'numero', a.numero, 'inicio', a.inicio, 'profissional', a.profissional_nome);
end $$;
grant execute on function public.ff_agendar(uuid, uuid, uuid, timestamptz, jsonb) to anon, authenticated;

-- 9) O cliente vê o agendamento pelo link
create or replace function public.ff_ver_agendamento(p_token text)
returns json language sql stable security definer set search_path = public as $$
  select json_build_object(
    'numero', a.numero, 'status', a.status, 'cancelado_por', a.cancelado_por,
    'servico', a.servico_nome, 'profissional', a.profissional_nome, 'preco', a.preco, 'duracao', a.duracao_min,
    'inicio', a.inicio, 'fim', a.fim, 'cliente_nome', a.cliente_nome, 'observacao', a.observacao,
    'pode_cancelar', a.status = 'agendado' and a.inicio - now() >= make_interval(hours => l.ag_cancelar_h),
    'cancelar_h', l.ag_cancelar_h,
    'loja', json_build_object('nome', l.nome, 'slug', l.slug, 'telefone', l.telefone, 'endereco', l.endereco,
                              'lat', l.lat, 'lng', l.lng, 'imagem_url', l.imagem_url))
  from public.ff_agendamentos a join public.ff_lojas l on l.id = a.loja_id
  where a.token = p_token
$$;
grant execute on function public.ff_ver_agendamento(text) to anon, authenticated;

-- 10) O cliente cancela pelo link (até X horas antes)
create or replace function public.ff_cancelar_agendamento(p_token text)
returns json language plpgsql security definer set search_path = public as $$
declare a public.ff_agendamentos; h int;
begin
  select * into a from public.ff_agendamentos where token = p_token for update;
  if not found then raise exception 'agendamento_invalido'; end if;
  if a.status <> 'agendado' then raise exception 'agendamento_encerrado'; end if;
  select ag_cancelar_h into h from public.ff_lojas where id = a.loja_id;
  if a.inicio - now() < make_interval(hours => h) then raise exception 'cancelar_tarde'; end if;
  update public.ff_agendamentos set status = 'cancelado', cancelado_por = 'cliente' where id = a.id;
  return json_build_object('ok', true);
end $$;
grant execute on function public.ff_cancelar_agendamento(text) to anon, authenticated;

-- Tempo real no painel
do $$ begin
  begin alter publication supabase_realtime add table public.ff_agendamentos; exception when others then null; end;
end $$;
