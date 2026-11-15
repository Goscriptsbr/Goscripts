-- GoPedido v26 — Cor da loja (o lojista escolhe a cor da marca; o sistema cuida da leitura).
-- Vazio = cor padrão do GoPedido. Pode rodar mais de uma vez.
alter table public.ff_lojas add column if not exists cor text not null default '';
alter table public.ff_lojas drop constraint if exists ff_lojas_cor_check;
alter table public.ff_lojas add constraint ff_lojas_cor_check check (cor = '' or cor ~ '^#[0-9A-Fa-f]{6}$');
