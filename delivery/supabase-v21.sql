-- GoPedido v21 — agência de postagem escolhida pelo lojista (Melhor Envio)
-- Rode depois do v20. Pode rodar mais de uma vez sem problema.

-- Agência escolhida por transportadora: { "<id da transportadora>": { "id": 123, "nome": "...", "endereco": "..." } }
alter table public.ff_lojas   add column if not exists me_agencias jsonb not null default '{}'::jsonb;
-- Agência onde o pacote deste pedido deve ser postado (gravada ao gerar a etiqueta)
alter table public.ff_pedidos add column if not exists me_agencia  jsonb not null default '{}'::jsonb;
