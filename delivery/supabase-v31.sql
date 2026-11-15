-- GoPedido v31 — Motoboy: quem coletou / quem entregou, avisos no celular do motoboy
-- Rode no Supabase → SQL Editor (depois do v30). Depois publique a função ff-email nova.

-- 1) Quem coletou e quando
alter table public.ff_pedidos add column if not exists entregador_id text not null default '';
alter table public.ff_pedidos add column if not exists coletado_em timestamptz;
alter table public.ff_pedidos add column if not exists entregue_em timestamptz;
alter table public.ff_pedidos add column if not exists pushes jsonb not null default '{}'::jsonb;

-- Motoboy muda o status. Ele é reconhecido pelo login do Google (se entrou com Google)
-- ou pelo aparelho (um código aleatório guardado no celular dele).
drop function if exists public.ff_entregador_status(text, uuid, text, text);
create or replace function public.ff_entregador_status(p_codigo text, p_pedido uuid, p_status text, p_nome text default '', p_ent text default '')
returns json language plpgsql volatile security definer set search_path = public as $$
declare
  v_loja uuid := public.ff_loja_do_codigo(p_codigo);
  v_nome text := left(trim(coalesce(p_nome, '')), 60);
  v_ent  text := coalesce(auth.uid()::text, left(regexp_replace(coalesce(p_ent, ''), '[^A-Za-z0-9-]', '', 'g'), 40));
  p public.ff_pedidos;
begin
  if v_loja is null then raise exception 'codigo_invalido'; end if;
  select * into p from public.ff_pedidos where id = p_pedido and loja_id = v_loja for update;
  if not found then raise exception 'pedido_invalido'; end if;

  if p_status = 'saiu' then
    if p.status = 'saiu' then raise exception 'ja_pegou'; end if;
    if p.status <> 'preparando' then raise exception 'status_invalido'; end if;
    update public.ff_pedidos set status = 'saiu', entregador_nome = v_nome, entregador_id = coalesce(v_ent, ''), coletado_em = now() where id = p.id;
  elsif p_status = 'entregue' then
    if p.status <> 'saiu' then raise exception 'status_invalido'; end if;
    -- só quem coletou confirma a entrega
    if coalesce(p.entregador_id, '') <> '' then
      if p.entregador_id <> coalesce(v_ent, '') then raise exception 'pedido_de_outro'; end if;
    elsif coalesce(p.entregador_nome, '') <> '' and lower(p.entregador_nome) <> lower(v_nome) then
      raise exception 'pedido_de_outro';
    end if;
    update public.ff_pedidos set status = 'entregue', entregue_em = now() where id = p.id;
  else
    raise exception 'status_invalido';
  end if;
  return json_build_object('ok', true);
end;
$$;
revoke all on function public.ff_entregador_status(text, uuid, text, text, text) from public;
grant execute on function public.ff_entregador_status(text, uuid, text, text, text) to anon, authenticated;

-- Lista do motoboy (igual + quem coletou e os horários)
create or replace function public.ff_entregador_pedidos(p_codigo text)
returns json language plpgsql stable security definer set search_path = public as $$
declare
  v_loja uuid := public.ff_loja_do_codigo(p_codigo);
begin
  if v_loja is null then raise exception 'codigo_invalido'; end if;
  return coalesce((
    select json_agg(json_build_object(
      'id', p.id, 'numero', p.numero, 'status', p.status,
      'cliente_nome', p.cliente_nome, 'cliente_telefone', p.cliente_telefone,
      'endereco', p.endereco, 'complemento', p.complemento, 'lat', p.lat, 'lng', p.lng,
      'distancia_km', p.distancia_km, 'subtotal', p.subtotal, 'taxa_entrega', p.taxa_entrega,
      'desconto', p.desconto, 'cupom', p.cupom,
      'total', p.total, 'pagamento', p.pagamento, 'troco_para', p.troco_para,
      'observacao', p.observacao, 'entregador_nome', p.entregador_nome,
      'entregador_id', p.entregador_id, 'coletado_em', p.coletado_em, 'entregue_em', p.entregue_em,
      'criado_em', p.criado_em, 'atualizado_em', p.atualizado_em,
      'itens', coalesce((select json_agg(json_build_object('nome', i.nome, 'qtd', i.qtd, 'preco', i.preco, 'obs', i.obs, 'opcoes', i.opcoes))
                         from public.ff_pedido_itens i where i.pedido_id = p.id), '[]'::json))
      order by p.criado_em)
    from public.ff_pedidos p
    where p.loja_id = v_loja and p.tipo_entrega = 'entrega'
      and (p.status in ('preparando', 'saiu')
           or (p.status = 'entregue' and p.atualizado_em > now() - interval '12 hours'))
  ), '[]'::json);
end;
$$;
grant execute on function public.ff_entregador_pedidos(text) to anon, authenticated;

-- 2) Avisos no celular do motoboy
create table if not exists public.ff_push_moto (
  id        uuid primary key default gen_random_uuid(),
  loja_id   uuid not null references public.ff_lojas(id) on delete cascade,
  codigo    text not null,              -- código do turno em que ele ligou (troca o código = para de receber)
  ent_id    text not null default '',
  nome      text not null default '',
  endpoint  text not null unique,
  p256dh    text not null,
  auth      text not null,
  criado_em timestamptz not null default now()
);
create index if not exists ff_push_moto_loja_idx on public.ff_push_moto (loja_id, codigo);
alter table public.ff_push_moto enable row level security;
revoke all on public.ff_push_moto from anon, authenticated;
grant all on public.ff_push_moto to service_role;

create or replace function public.ff_moto_push_salvar(p_codigo text, p_ent text, p_nome text, p_endpoint text, p_p256dh text, p_auth text)
returns void language plpgsql volatile security definer set search_path = public as $$
declare v_loja uuid := public.ff_loja_do_codigo(p_codigo); v_cod text;
begin
  if v_loja is null then raise exception 'codigo_invalido'; end if;
  if p_endpoint !~ '^https://' or length(p_endpoint) > 1000
     or coalesce(p_p256dh, '') !~ '^[A-Za-z0-9_-]{80,100}$' or coalesce(p_auth, '') !~ '^[A-Za-z0-9_-]{16,30}$' then
    raise exception 'aparelho_invalido';
  end if;
  select codigo into v_cod from public.ff_entregador_acesso where loja_id = v_loja;
  insert into public.ff_push_moto (loja_id, codigo, ent_id, nome, endpoint, p256dh, auth)
  values (v_loja, v_cod, coalesce(auth.uid()::text, left(regexp_replace(coalesce(p_ent, ''), '[^A-Za-z0-9-]', '', 'g'), 40)),
          left(trim(coalesce(p_nome, '')), 60), p_endpoint, p_p256dh, p_auth)
  on conflict (endpoint) do update set loja_id = excluded.loja_id, codigo = excluded.codigo, ent_id = excluded.ent_id,
    nome = excluded.nome, p256dh = excluded.p256dh, auth = excluded.auth, criado_em = now();
end;
$$;
create or replace function public.ff_moto_push_remover(p_endpoint text)
returns void language sql volatile security definer set search_path = public as $$
  delete from public.ff_push_moto where endpoint = p_endpoint;
$$;
revoke all on function public.ff_moto_push_salvar(text, text, text, text, text, text), public.ff_moto_push_remover(text) from public;
grant execute on function public.ff_moto_push_salvar(text, text, text, text, text, text), public.ff_moto_push_remover(text) to anon, authenticated;

-- Quando a loja aceita um pedido de entrega → avisa os motoboys.
-- Quando um motoboy coleta → avisa os outros motoboys e a loja. Quando entrega → avisa a loja.
create or replace function public.ff_push_moto_tg()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.tipo_entrega = 'entrega' and new.status is distinct from old.status then
    if new.status = 'preparando' then
      perform public.ff_chamar_push(jsonb_build_object('acao', 'push_moto', 'id', new.id, 'evento', 'pronto'));
    elsif new.status = 'saiu' and coalesce(new.entregador_nome, '') <> '' then
      perform public.ff_chamar_push(jsonb_build_object('acao', 'push_moto', 'id', new.id, 'evento', 'coletado'));
    elsif new.status = 'entregue' and coalesce(new.entregador_nome, '') <> '' then
      perform public.ff_chamar_push(jsonb_build_object('acao', 'push_moto', 'id', new.id, 'evento', 'entregue'));
    end if;
  end if;
  return null;
end;
$$;
drop trigger if exists ff_pedidos_push_moto on public.ff_pedidos;
create trigger ff_pedidos_push_moto after update of status on public.ff_pedidos
  for each row execute function public.ff_push_moto_tg();

-- Trocou o código do motoboy pelo painel: quem estava no turno anterior para de receber avisos
create or replace function public.ff_push_moto_limpa()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.codigo is distinct from old.codigo then
    delete from public.ff_push_moto where loja_id = new.loja_id and codigo <> new.codigo and criado_em < now() - interval '16 hours';
  end if;
  return null;
end;
$$;
drop trigger if exists ff_entregador_acesso_push on public.ff_entregador_acesso;
create trigger ff_entregador_acesso_push after update of codigo on public.ff_entregador_acesso
  for each row execute function public.ff_push_moto_limpa();

notify pgrst, 'reload schema';
