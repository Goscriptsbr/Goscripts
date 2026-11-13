-- GoPedido v16 — pedidos em tempo real no painel da loja (Supabase Realtime)
-- Pode rodar mais de uma vez sem problema.
-- O Realtime respeita as regras de segurança (RLS): cada lojista só recebe os pedidos das lojas dele.

do $$
begin
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'ff_pedidos') then
    alter publication supabase_realtime add table public.ff_pedidos;
  end if;
end $$;

-- Avisos em tempo real para o cliente (acompanhar pedido) e para o motoboy.
-- O banco manda só um "toque" vazio ({}), sem nenhum dado do pedido:
--   • cliente: canal "pedido-<token secreto do link do pedido>"
--   • motoboy: canal "entregas-<código atual de 8 letras da loja>"
-- Ao receber o toque, a tela busca os dados pelas funções protegidas de sempre.
-- Se o Realtime falhar por qualquer motivo, o pedido continua sendo salvo normalmente.
create or replace function public.ff_rt_aviso()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_cod text;
begin
  begin
    if tg_op = 'UPDATE' then
      perform realtime.send('{}'::jsonb, 'mudou', 'pedido-' || new.token, false);
    end if;
    if new.tipo_entrega = 'entrega' then
      select codigo into v_cod from public.ff_entregador_acesso where loja_id = new.loja_id and expira > now();
      if v_cod is not null then
        perform realtime.send('{}'::jsonb, 'mudou', 'entregas-' || v_cod, false);
      end if;
    end if;
  exception when others then null;
  end;
  return null;
end;
$$;
revoke all on function public.ff_rt_aviso() from public;

drop trigger if exists ff_pedidos_rt on public.ff_pedidos;
create trigger ff_pedidos_rt after insert or update on public.ff_pedidos
  for each row execute function public.ff_rt_aviso();

-- Vários motoboys na mesma loja:
--   • se dois tocarem em "Peguei" no mesmo pedido, só o primeiro fica com ele (o outro recebe "já pegou");
--   • só quem pegou o pedido consegue confirmar a entrega.
create or replace function public.ff_entregador_status(p_codigo text, p_pedido uuid, p_status text, p_nome text default '')
returns json language plpgsql volatile security definer set search_path = public as $$
declare
  v_loja uuid := public.ff_loja_do_codigo(p_codigo);
  v_nome text := left(trim(coalesce(p_nome, '')), 60);
  p public.ff_pedidos;
begin
  if v_loja is null then raise exception 'codigo_invalido'; end if;
  select * into p from public.ff_pedidos where id = p_pedido and loja_id = v_loja for update;
  if not found then raise exception 'pedido_invalido'; end if;

  if p_status = 'saiu' then
    if p.status = 'saiu' then raise exception 'ja_pegou'; end if;
    if p.status <> 'preparando' then raise exception 'status_invalido'; end if;
    update public.ff_pedidos set status = 'saiu', entregador_nome = v_nome where id = p.id;
  elsif p_status = 'entregue' then
    if p.status <> 'saiu' then raise exception 'status_invalido'; end if;
    if coalesce(p.entregador_nome, '') <> '' and lower(p.entregador_nome) <> lower(v_nome) then
      raise exception 'pedido_de_outro';
    end if;
    update public.ff_pedidos set status = 'entregue' where id = p.id;
  else
    raise exception 'status_invalido';
  end if;
  return json_build_object('ok', true);
end;
$$;
revoke all on function public.ff_entregador_status(text, uuid, text, text) from public;
grant execute on function public.ff_entregador_status(text, uuid, text, text) to anon, authenticated;
