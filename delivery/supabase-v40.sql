-- GoPedido v40: e-mail de boas-vindas para lojista, motoboy e cliente
-- Rode depois da v39. Pode rodar mais de uma vez.
--
-- Cada pessoa recebe no máximo UM e-mail de boas-vindas de cada tipo.
--   lojista → quando cria a primeira loja (gatilho no banco)
--   motoboy → quando entra pela primeira vez na área do entregador com a conta Google
--   cliente → quando cria a conta de cliente (só contas novas, de até 3 dias)
-- O e-mail sai pela função ff-email (mesmo Gmail dos outros e-mails).

create table if not exists public.ff_boasvindas (
  id         uuid primary key default gen_random_uuid(),
  usuario    uuid not null references auth.users(id) on delete cascade,
  tipo       text not null check (tipo in ('lojista', 'motoboy', 'cliente')),
  loja_id    uuid,
  criado_em  timestamptz not null default now(),
  enviado_em timestamptz,
  unique (usuario, tipo)
);
alter table public.ff_boasvindas enable row level security;
revoke all on public.ff_boasvindas from anon, authenticated;

-- Interna: registra e pede o envio (uma vez só por pessoa e tipo)
create or replace function public.ff_boasvindas_criar(p_usuario uuid, p_tipo text, p_loja uuid default null)
returns boolean language plpgsql volatile security definer set search_path = public as $$
declare v_id uuid;
begin
  if p_usuario is null then return false; end if;
  insert into public.ff_boasvindas (usuario, tipo, loja_id)
  values (p_usuario, p_tipo, p_loja)
  on conflict (usuario, tipo) do nothing
  returning id into v_id;
  if v_id is null then return false; end if;
  perform public.ff_chamar_push(jsonb_build_object('acao', 'boas_vindas', 'id', v_id));
  return true;
exception when others then
  return false;  -- nunca atrapalha a criação da loja ou o login
end;
$$;
revoke all on function public.ff_boasvindas_criar(uuid, text, uuid) from public, anon, authenticated;

-- Lojista: ao criar a primeira loja
create or replace function public.ff_boasvindas_loja_tg()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform public.ff_boasvindas_criar(new.dono, 'lojista', new.id);
  return null;
end;
$$;
drop trigger if exists ff_lojas_boasvindas on public.ff_lojas;
create trigger ff_lojas_boasvindas after insert on public.ff_lojas
  for each row execute function public.ff_boasvindas_loja_tg();

-- Chamada pelo site (cliente e motoboy) logo depois de entrar
create or replace function public.ff_boas_vindas(p_tipo text)
returns json language plpgsql volatile security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_criado timestamptz;
begin
  if v_uid is null then raise exception 'sem_login'; end if;
  if p_tipo not in ('cliente', 'motoboy') then raise exception 'tipo_invalido'; end if;
  select created_at into v_criado from auth.users where id = v_uid;

  if p_tipo = 'cliente' then
    -- Só contas novas (quem já usava antes desta versão não recebe)
    if v_criado is null or v_criado < now() - interval '3 days' then
      return json_build_object('enviado', false, 'motivo', 'conta_antiga');
    end if;
    -- Lojista ou pessoa da equipe já recebe o e-mail próprio
    if exists (select 1 from public.ff_lojas where dono = v_uid)
       or exists (select 1 from public.ff_equipe where user_id = v_uid) then
      return json_build_object('enviado', false, 'motivo', 'lojista');
    end if;
  end if;

  return json_build_object('enviado', public.ff_boasvindas_criar(v_uid, p_tipo, null));
end;
$$;
revoke all on function public.ff_boas_vindas(text) from public, anon;
grant execute on function public.ff_boas_vindas(text) to authenticated;

-- =====================================================================
-- Motoboy: entrar com a conta (Google) passa a ser obrigatório
-- Só o código da loja não basta mais: sem estar conectado, nenhuma entrega aparece.
-- =====================================================================

create or replace function public.ff_entregador_entrar(p_codigo text)
returns json language plpgsql stable security definer set search_path = public as $$
declare
  v_loja uuid;
  l public.ff_lojas;
begin
  if auth.uid() is null then raise exception 'moto_login'; end if;
  v_loja := public.ff_loja_do_codigo(p_codigo);
  if v_loja is null then raise exception 'codigo_invalido'; end if;
  select * into l from public.ff_lojas where id = v_loja;
  return json_build_object(
    'loja', json_build_object('nome', l.nome, 'imagem_url', l.imagem_url, 'telefone', l.telefone,
                              'endereco', l.endereco, 'lat', l.lat, 'lng', l.lng, 'cnpj', l.cnpj),
    'expira', (select expira from public.ff_entregador_acesso where loja_id = v_loja));
end;
$$;

create or replace function public.ff_entregador_pedidos(p_codigo text)
returns json language plpgsql stable security definer set search_path = public as $$
declare
  v_loja uuid;
begin
  if auth.uid() is null then raise exception 'moto_login'; end if;
  v_loja := public.ff_loja_do_codigo(p_codigo);
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

create or replace function public.ff_entregador_status(p_codigo text, p_pedido uuid, p_status text, p_nome text default '', p_ent text default '')
returns json language plpgsql volatile security definer set search_path = public as $$
declare
  v_loja uuid;
  v_nome text := left(trim(coalesce(p_nome, '')), 60);
  v_ent  text := auth.uid()::text;   -- quem é o motoboy vem sempre da conta, nunca do aparelho
  p public.ff_pedidos;
begin
  if v_ent is null then raise exception 'moto_login'; end if;
  v_loja := public.ff_loja_do_codigo(p_codigo);
  if v_loja is null then raise exception 'codigo_invalido'; end if;
  select * into p from public.ff_pedidos where id = p_pedido and loja_id = v_loja for update;
  if not found then raise exception 'pedido_invalido'; end if;

  if p_status = 'saiu' then
    if p.status = 'saiu' then raise exception 'ja_pegou'; end if;
    if p.status <> 'preparando' then raise exception 'status_invalido'; end if;
    update public.ff_pedidos set status = 'saiu', entregador_nome = v_nome, entregador_id = v_ent, coletado_em = now() where id = p.id;
  elsif p_status = 'entregue' then
    if p.status <> 'saiu' then raise exception 'status_invalido'; end if;
    -- só quem coletou confirma a entrega
    if coalesce(p.entregador_id, '') <> '' and p.entregador_id not like 'd-%' then
      if p.entregador_id <> v_ent then raise exception 'pedido_de_outro'; end if;
    elsif coalesce(p.entregador_nome, '') <> '' and lower(p.entregador_nome) <> lower(v_nome) then
      -- pedido coletado antes desta versão (sem conta): confere pelo nome
      raise exception 'pedido_de_outro';
    end if;
    update public.ff_pedidos set status = 'entregue', entregue_em = now() where id = p.id;
  else
    raise exception 'status_invalido';
  end if;
  return json_build_object('ok', true);
end;
$$;

create or replace function public.ff_moto_push_salvar(p_codigo text, p_ent text, p_nome text, p_endpoint text, p_p256dh text, p_auth text)
returns void language plpgsql volatile security definer set search_path = public as $$
declare v_loja uuid; v_cod text;
begin
  if auth.uid() is null then raise exception 'moto_login'; end if;
  v_loja := public.ff_loja_do_codigo(p_codigo);
  if v_loja is null then raise exception 'codigo_invalido'; end if;
  if p_endpoint !~ '^https://' or length(p_endpoint) > 1000
     or coalesce(p_p256dh, '') !~ '^[A-Za-z0-9_-]{80,100}$' or coalesce(p_auth, '') !~ '^[A-Za-z0-9_-]{16,30}$' then
    raise exception 'aparelho_invalido';
  end if;
  select codigo into v_cod from public.ff_entregador_acesso where loja_id = v_loja;
  insert into public.ff_push_moto (loja_id, codigo, ent_id, nome, endpoint, p256dh, auth)
  values (v_loja, v_cod, auth.uid()::text, left(trim(coalesce(p_nome, '')), 60), p_endpoint, p_p256dh, p_auth)
  on conflict (endpoint) do update set loja_id = excluded.loja_id, codigo = excluded.codigo, ent_id = excluded.ent_id,
    nome = excluded.nome, p256dh = excluded.p256dh, auth = excluded.auth, criado_em = now();
end;
$$;

-- Sem conta não tem acesso: tira a permissão de quem não está logado
revoke all on function public.ff_entregador_entrar(text) from public, anon;
revoke all on function public.ff_entregador_pedidos(text) from public, anon;
revoke all on function public.ff_entregador_status(text, uuid, text, text, text) from public, anon;
revoke all on function public.ff_moto_push_salvar(text, text, text, text, text, text) from public, anon;
grant execute on function public.ff_entregador_entrar(text) to authenticated;
grant execute on function public.ff_entregador_pedidos(text) to authenticated;
grant execute on function public.ff_entregador_status(text, uuid, text, text, text) to authenticated;
grant execute on function public.ff_moto_push_salvar(text, text, text, text, text, text) to authenticated;
