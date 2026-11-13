-- GoPedido v17 — tipo de loja (restaurante, mercado, farmácia, pet shop, bebidas, variedades, outros)
-- Rode depois do v16. Pode rodar mais de uma vez sem problema.
-- As lojas que já existem ficam como "restaurante".

alter table public.ff_lojas add column if not exists tipo text not null default 'restaurante';
alter table public.ff_lojas drop constraint if exists ff_lojas_tipo_check;
alter table public.ff_lojas add constraint ff_lojas_tipo_check
  check (tipo in ('restaurante','mercado','farmacia','pet','bebidas','variedades','outros'));

-- Para a etapa do Melhor Envio (só lojas de Variedades): liga/desliga o envio para outras cidades.
alter table public.ff_lojas add column if not exists envio_externo boolean not null default false;
