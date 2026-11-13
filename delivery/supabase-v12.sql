-- =====================================================================
--  GoPedido — ATUALIZAÇÃO 12: cupons visíveis para os clientes
--  Rode DEPOIS das atualizações anteriores. Pode rodar de novo.
-- =====================================================================

-- A loja escolhe se o cupom aparece na página (público) ou fica oculto
alter table public.ff_cupons add column if not exists publico boolean not null default true;

-- Cupons públicos válidos agora (de uma loja, ou de todas se p_loja for vazio)
create or replace function public.ff_cupons_publicos(p_loja uuid default null)
returns json language sql stable security definer set search_path = public as $$
  select coalesce(json_agg(json_build_object(
           'loja_id', c.loja_id, 'codigo', c.codigo, 'tipo', c.tipo, 'valor', c.valor,
           'minimo', c.minimo, 'validade', c.validade, 'por_cliente', c.por_cliente,
           'restantes', case when c.limite is null then null else greatest(c.limite - c.usos, 0) end)
         order by c.criado_em desc), '[]'::json)
    from public.ff_cupons c
    join public.ff_lojas l on l.id = c.loja_id and l.ativa
   where c.ativo and c.publico
     and (p_loja is null or c.loja_id = p_loja)
     and (c.validade is null or c.validade >= public.ff_hoje_sp())
     and (c.limite is null or c.usos < c.limite)
$$;
revoke all on function public.ff_cupons_publicos(uuid) from public;
grant execute on function public.ff_cupons_publicos(uuid) to anon, authenticated;
