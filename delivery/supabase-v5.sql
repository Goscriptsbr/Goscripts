-- =====================================================================
--  GoPedido — ATUALIZAÇÃO 5: horário de funcionamento por dia da semana
--  Rode DEPOIS das atualizações anteriores. Pode rodar de novo.
-- =====================================================================

-- horarios: {"0":{"aberto":true,"ini":"18:00","fim":"23:30"}, ... } (0 = domingo)
alter table public.ff_lojas add column if not exists horarios jsonb not null default '{}'::jsonb;
alter table public.ff_lojas add column if not exists horario_auto boolean not null default false;

-- A loja está aberta agora? (horário de Brasília)
--  · automático: dentro do horário do dia E não pausada
--  · manual: vale o botão aberta/fechada
create or replace function public.ff_aberta_agora(p_auto boolean, p_aberta boolean, p_h jsonb)
returns boolean language plpgsql stable set search_path = public as $$
declare
  t   timestamp := now() at time zone 'America/Sao_Paulo';
  dow int := extract(dow from t)::int;
  m   int := extract(hour from t)::int * 60 + extract(minute from t)::int;
  d   jsonb; ini int; fim int;
begin
  if not coalesce(p_aberta, false) then return false; end if;
  if not coalesce(p_auto, false) then return true; end if;
  -- hoje
  d := p_h -> dow::text;
  if d is not null and coalesce((d ->> 'aberto')::boolean, false) then
    ini := split_part(d ->> 'ini', ':', 1)::int * 60 + split_part(d ->> 'ini', ':', 2)::int;
    fim := split_part(d ->> 'fim', ':', 1)::int * 60 + split_part(d ->> 'fim', ':', 2)::int;
    if fim > ini and m >= ini and m < fim then return true; end if;
    if fim <= ini and m >= ini then return true; end if;   -- vira a meia-noite
  end if;
  -- ontem que passou da meia-noite
  d := p_h -> ((dow + 6) % 7)::text;
  if d is not null and coalesce((d ->> 'aberto')::boolean, false) then
    ini := split_part(d ->> 'ini', ':', 1)::int * 60 + split_part(d ->> 'ini', ':', 2)::int;
    fim := split_part(d ->> 'fim', ':', 1)::int * 60 + split_part(d ->> 'fim', ':', 2)::int;
    if fim <= ini and m < fim then return true; end if;
  end if;
  return false;
exception when others then
  return false;
end;
$$;
grant execute on function public.ff_aberta_agora(boolean, boolean, jsonb) to anon, authenticated;

-- Comprovante do Pix: só para loja aberta de verdade (respeitando o horário)
drop policy if exists ff_comp_enviar on storage.objects;
create policy ff_comp_enviar on storage.objects for insert to anon, authenticated
  with check (bucket_id = 'ff-comprovantes' and exists (
    select 1 from public.ff_lojas l
    where l.id::text = (storage.foldername(name))[1] and l.ativa
      and public.ff_aberta_agora(l.horario_auto, l.aberta, l.horarios)));

create or replace function public.ff_criar_pedido(
  p_loja uuid, p_cliente jsonb, p_itens jsonb, p_pagamento text, p_comprovante text default null)
returns json language plpgsql volatile security definer set search_path = public as $$
declare
  l      public.ff_lojas;
  pr     public.ff_produtos;
  it     jsonb;
  q      int;
  n      int := 0;
  v_sub  numeric := 0;
  v_dist numeric;
  v_taxa numeric;
  v_lat  double precision := nullif(p_cliente ->> 'lat', '')::double precision;
  v_lng  double precision := nullif(p_cliente ->> 'lng', '')::double precision;
  v_ped  public.ff_pedidos;
  v_troco numeric := nullif(p_cliente ->> 'troco_para', '')::numeric;
begin
  select * into l from public.ff_lojas where id = p_loja and ativa;
  if not found then raise exception 'loja_invalida'; end if;
  if not public.ff_aberta_agora(l.horario_auto, l.aberta, l.horarios) then raise exception 'loja_fechada'; end if;
  if l.lat is null or l.lng is null then raise exception 'loja_sem_localizacao'; end if;

  if p_pagamento not in ('pix','debito','credito','dinheiro')
     or (p_pagamento = 'dinheiro' and not l.aceita_dinheiro)
     or (p_pagamento = 'pix'     and not l.aceita_pix)
     or (p_pagamento = 'debito'  and not l.aceita_debito)
     or (p_pagamento = 'credito' and not l.aceita_credito) then
    raise exception 'pagamento_invalido';
  end if;

  if p_pagamento = 'pix' then
    if coalesce(p_comprovante, '') = ''
       or split_part(p_comprovante, '/', 1) <> l.id::text
       or not exists (select 1 from storage.objects
                      where bucket_id = 'ff-comprovantes' and name = p_comprovante) then
      raise exception 'comprovante_obrigatorio';
    end if;
  end if;

  if length(trim(coalesce(p_cliente ->> 'nome', ''))) < 2
     or length(regexp_replace(coalesce(p_cliente ->> 'telefone', ''), '\D', '', 'g')) < 10
     or length(trim(coalesce(p_cliente ->> 'endereco', ''))) < 5 then
    raise exception 'dados_incompletos';
  end if;
  if v_lat is null or v_lng is null then raise exception 'localizacao_obrigatoria'; end if;

  v_dist := public.ff_distancia_km(l.lat, l.lng, v_lat, v_lng);
  if l.raio_km > 0 and v_dist > l.raio_km then raise exception 'fora_da_area'; end if;
  v_taxa := greatest(l.taxa_minima, round(v_dist * l.taxa_km, 2));

  insert into public.ff_pedidos
    (loja_id, cliente_id, cliente_nome, cliente_telefone, endereco, complemento, lat, lng,
     distancia_km, taxa_entrega, pagamento, comprovante_path, observacao)
  values
    (l.id, auth.uid(), left(trim(p_cliente ->> 'nome'), 80), left(trim(p_cliente ->> 'telefone'), 30),
     left(trim(p_cliente ->> 'endereco'), 200), left(trim(coalesce(p_cliente ->> 'complemento', '')), 120),
     v_lat, v_lng, v_dist, v_taxa, p_pagamento,
     case when p_pagamento = 'pix' then p_comprovante end,
     left(trim(coalesce(p_cliente ->> 'observacao', '')), 300))
  returning * into v_ped;

  for it in select * from jsonb_array_elements(coalesce(p_itens, '[]'::jsonb)) loop
    q := least(greatest(coalesce((it ->> 'qtd')::int, 0), 0), 99);
    continue when q = 0;
    select * into pr from public.ff_produtos
     where id = (it ->> 'id')::uuid and loja_id = l.id and disponivel;
    if not found then raise exception 'produto_indisponivel'; end if;
    insert into public.ff_pedido_itens (pedido_id, produto_id, nome, preco, qtd, obs)
    values (v_ped.id, pr.id, pr.nome, pr.preco, q, left(trim(coalesce(it ->> 'obs', '')), 200));
    v_sub := v_sub + pr.preco * q;
    n := n + 1;
  end loop;

  if n = 0 then raise exception 'carrinho_vazio'; end if;
  if v_sub < l.pedido_minimo then raise exception 'abaixo_do_minimo'; end if;

  if p_pagamento = 'dinheiro' and coalesce(v_troco, 0) > 0 and v_troco < v_sub + v_taxa then
    raise exception 'troco_invalido';
  end if;

  update public.ff_pedidos
     set subtotal = v_sub, total = v_sub + v_taxa,
         troco_para = case when p_pagamento = 'dinheiro' and coalesce(v_troco, 0) > 0 then v_troco end
   where id = v_ped.id returning * into v_ped;

  return json_build_object('token', v_ped.token, 'numero', v_ped.numero, 'total', v_ped.total);
end;
$$;



grant execute on function public.ff_criar_pedido(uuid, jsonb, jsonb, text, text) to anon, authenticated;
