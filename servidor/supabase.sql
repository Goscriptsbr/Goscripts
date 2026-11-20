-- Banco do SINUCOU (projeto do Supabase SÓ do jogo — não usar o projeto do convite nem o do GoPedido).
-- Cole tudo no Supabase > SQL Editor > New query > Run.

create table if not exists public.sinucou_players (
  code text primary key,
  data jsonb not null default '{}'::jsonb,       -- nome, último acesso, pontos da liga, perfil
  updated_at timestamptz not null default now()
);

create table if not exists public.sinucou_mailbox (
  code text primary key,
  msgs jsonb not null default '[]'::jsonb,       -- pedidos de amizade/recados para quem está offline
  updated_at timestamptz not null default now()
);

create table if not exists public.sinucou_saves (
  code text primary key,
  tok text not null,                             -- segredo do aparelho dono da conta
  pass text,                                     -- senha (só o hash, com sal)
  save jsonb not null default '{}'::jsonb,       -- itens, progresso
  eco jsonb,                                     -- saldo de moedas/grana (fonte da verdade)
  updated_at timestamptz not null default now()
);

-- Segurança: ninguém de fora lê nem grava (só o servidor do jogo, com a chave service_role).
alter table public.sinucou_players enable row level security;
alter table public.sinucou_mailbox enable row level security;
alter table public.sinucou_saves enable row level security;

-- se a tabela já existia antes das moedas no servidor:
alter table public.sinucou_saves add column if not exists eco jsonb;
