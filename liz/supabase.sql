-- =====================================================================
--  Convite do aniversário de 1 ano da Liz — banco de dados (Supabase)
--  Cole TUDO no Supabase > SQL Editor > New query e clique em "Run".
--  Pode rodar de novo sem problema: não apaga dados existentes.
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------- Tabelas ----------

-- Quem pode entrar no painel
create table if not exists public.admins (
  email text primary key
);
insert into public.admins (email) values ('goscriptsbr@gmail.com')
on conflict do nothing;

-- Informações da festa (uma linha só, editável pelo painel)
create table if not exists public.evento (
  id        int primary key default 1 check (id = 1),
  local     text not null default '',
  endereco  text not null default '',
  mapa_url  text not null default '',
  mensagem  text not null default '',
  prazo     timestamptz not null default '2026-12-05 23:59:59-03'
);
insert into public.evento (id) values (1) on conflict do nothing;
update public.evento set
  local    = case when local    = '' then 'Salão de Festas Cantinho Meu' else local end,
  endereco = case when endereco = '' then 'R. Sebastião Benedito da Silva, 333 - Jardim Novo II, Mogi Guaçu - SP' else endereco end,
  mapa_url = case when mapa_url = '' then 'https://maps.app.goo.gl/KaSEnLjM6C4CzaV87' else mapa_url end
where id = 1;

-- Uma linha por família (cada uma tem seu link)
create table if not exists public.familias (
  id            uuid primary key default gen_random_uuid(),
  nome          text not null,
  token         text not null unique
                default substr(replace(gen_random_uuid()::text, '-', ''), 1, 12),
  telefone      text not null default '',
  recado        text not null default '',
  respondido_em timestamptz,
  criado_em     timestamptz not null default now()
);

-- Uma linha por pessoa
create table if not exists public.convidados (
  id            uuid primary key default gen_random_uuid(),
  familia_id    uuid not null references public.familias(id) on delete cascade,
  nome          text not null,
  crianca       boolean not null default false,
  resposta      text check (resposta in ('sim', 'nao')),
  respondido_em timestamptz,
  ordem         int not null default 0,
  criado_em     timestamptz not null default now()
);
create index if not exists convidados_familia_idx on public.convidados (familia_id);

-- ---------- Segurança (RLS) ----------
-- Convidados NÃO acessam as tabelas diretamente: só pelas funções abaixo,
-- que exigem o código do link da família. O painel exige login de admin.

alter table public.admins     enable row level security;
alter table public.evento     enable row level security;
alter table public.familias   enable row level security;
alter table public.convidados enable row level security;

create or replace function public.is_admin()
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.admins
    where lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
$$;

drop policy if exists admin_tudo on public.evento;
drop policy if exists admin_tudo on public.familias;
drop policy if exists admin_tudo on public.convidados;

create policy admin_tudo on public.evento
  for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy admin_tudo on public.familias
  for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy admin_tudo on public.convidados
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

revoke all on public.admins, public.evento, public.familias, public.convidados from anon;
grant select, insert, update, delete
  on public.evento, public.familias, public.convidados to authenticated;

-- ---------- Funções usadas pelo convite ----------

-- Lê o convite de uma família pelo código do link
create or replace function public.get_convite(p_token text)
returns json
language plpgsql stable security definer
set search_path = public
as $$
declare
  f public.familias;
  e public.evento;
begin
  select * into f from public.familias where token = p_token;
  if not found then
    return null;
  end if;
  select * into e from public.evento where id = 1;

  return json_build_object(
    'familia',         f.nome,
    'recado',          f.recado,
    'respondido_em',   f.respondido_em,
    'prazo',           e.prazo,
    'prazo_encerrado', now() > e.prazo,
    'evento', json_build_object(
      'local', e.local, 'endereco', e.endereco,
      'mapa_url', e.mapa_url, 'mensagem', e.mensagem
    ),
    'convidados', coalesce((
      select json_agg(json_build_object(
               'id', c.id, 'nome', c.nome, 'crianca', c.crianca, 'resposta', c.resposta)
             order by c.ordem, c.criado_em)
      from public.convidados c where c.familia_id = f.id
    ), '[]'::json)
  );
end;
$$;

-- Informações gerais da festa (para quem abre o convite sem código)
create or replace function public.get_evento()
returns json
language sql stable security definer
set search_path = public
as $$
  select json_build_object(
    'local', local, 'endereco', endereco, 'mapa_url', mapa_url,
    'mensagem', mensagem, 'prazo', prazo, 'prazo_encerrado', now() > prazo)
  from public.evento where id = 1;
$$;

-- Grava as respostas de uma família
-- p_respostas: [{"id": "<uuid do convidado>", "resposta": "sim" | "nao"}, ...]
create or replace function public.responder(p_token text, p_respostas jsonb, p_recado text default '')
returns json
language plpgsql volatile security definer
set search_path = public
as $$
declare
  f public.familias;
  r jsonb;
begin
  select * into f from public.familias where token = p_token;
  if not found then
    raise exception 'convite_invalido';
  end if;
  if now() > (select prazo from public.evento where id = 1) then
    raise exception 'prazo_encerrado';
  end if;

  for r in select * from jsonb_array_elements(coalesce(p_respostas, '[]'::jsonb)) loop
    if (r ->> 'resposta') in ('sim', 'nao') then
      update public.convidados
         set resposta = r ->> 'resposta', respondido_em = now()
       where id = (r ->> 'id')::uuid and familia_id = f.id;
    end if;
  end loop;

  update public.familias
     set recado = left(coalesce(p_recado, ''), 500), respondido_em = now()
   where id = f.id;

  return public.get_convite(p_token);
end;
$$;

revoke all on function public.get_convite(text)               from public;
revoke all on function public.get_evento()                    from public;
revoke all on function public.responder(text, jsonb, text)    from public;
revoke all on function public.is_admin()                      from public;
grant execute on function public.get_convite(text)            to anon, authenticated;
grant execute on function public.get_evento()                 to anon, authenticated;
grant execute on function public.responder(text, jsonb, text) to anon, authenticated;
grant execute on function public.is_admin()                   to authenticated;
