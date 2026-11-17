-- GoPedido v41: loja "só retirada no local" (sem entrega)
-- Rode depois da v40. Pode rodar mais de uma vez.

alter table public.ff_lojas add column if not exists faz_entrega boolean not null default true;

-- A loja precisa ter pelo menos um jeito de o cliente receber: entrega ou retirada
alter table public.ff_lojas drop constraint if exists ff_lojas_algum_modo;
alter table public.ff_lojas add constraint ff_lojas_algum_modo check (faz_entrega or aceita_retirada);

-- Trava no servidor: loja que não entrega não recebe pedido de entrega (nem de envio)
create or replace function public.ff_pedido_modo_tg()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.tipo_entrega in ('entrega', 'envio')
     and exists (select 1 from public.ff_lojas where id = new.loja_id and faz_entrega = false) then
    raise exception 'entrega_indisponivel';
  end if;
  return new;
end;
$$;
drop trigger if exists ff_pedidos_modo on public.ff_pedidos;
create trigger ff_pedidos_modo before insert on public.ff_pedidos
  for each row execute function public.ff_pedido_modo_tg();
