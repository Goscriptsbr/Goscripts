-- GoPedido v24 — plano Grátis passa a ter até 30 produtos (antes 50).
-- Lojas que já têm mais de 30 não perdem nada: só não cadastram produtos novos
-- até apagar alguns ou assinar um plano. Pode rodar mais de uma vez.

create or replace function public.ff_limites(p_plano text)
returns table (lojas int, produtos int) language sql immutable as $$
  select case p_plano when 'premium' then 5 when 'profissional' then 2 else 1 end,
         case p_plano when 'premium' then 500 when 'profissional' then 200 else 30 end
$$;
