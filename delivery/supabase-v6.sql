-- =====================================================================
--  GoPedido — ATUALIZAÇÃO 6: montagem do produto, promoções e cupons
--  Rode DEPOIS das atualizações anteriores. Pode rodar de novo.
-- =====================================================================

-- Montagem: grupos de opções do produto
-- grupos = [{"id":"g1","nome":"Tamanho do copo","min":1,"max":1,
--            "opcoes":[{"id":"o1","nome":"300 ml","preco":0},{"id":"o2","nome":"500 ml","preco":5}]}]
alter table public.ff_produtos add column if not exists grupos jsonb not null default '[]'::jsonb;

-- Preço promocional (opcional) e até quando vale
alter table public.ff_produtos add column if not exists preco_promo numeric(10,2);
alter table public.ff_produtos add column if not exists promo_ate date;

-- Item do pedido guarda as opções escolhidas (com o preço da hora)
alter table public.ff_pedido_itens add column if not exists opcoes jsonb not null default '[]'::jsonb;

-- Pedido guarda cupom e desconto
alter table public.ff_pedidos add column if not exists cupom text not null default '';
alter table public.ff_pedidos add column if not exists desconto numeric(10,2) not null default 0;

-- Cupons de desconto da loja
create table if not exists public.ff_cupons (
  id         uuid primary key default gen_random_uuid(),
  loja_id    uuid not null references public.ff_lojas(id) on delete cascade,
  codigo     text not null,
  tipo       text not null check (tipo in ('percentual','valor','frete')),
  valor      numeric(10,2) not null default 0,
  minimo     numeric(10,2) not null default 0,
  validade   date,
  limite     int,
  usos       int not null default 0,
  ativo      boolean not null default true,
  criado_em  timestamptz not null default now(),
  unique (loja_id, codigo)
);
alter table public.ff_cupons enable row level security;
drop policy if exists ff_cupons_dono on public.ff_cupons;
create policy ff_cupons_dono on public.ff_cupons for all to authenticated
  using (public.ff_minha_loja(loja_id)) with check (public.ff_minha_loja(loja_id));
revoke all on public.ff_cupons from anon;
grant select, insert, update, delete on public.ff_cupons to authenticated;

-- Data de hoje no horário de Brasília
create or replace function public.ff_hoje_sp()
returns date language sql stable as $$ select (now() at time zone 'America/Sao_Paulo')::date $$;

-- Preço que vale agora (promoção válida ou preço normal)
create or replace function public.ff_preco_atual(p_preco numeric, p_promo numeric, p_ate date)
returns numeric language sql stable as $$
  select case when p_promo is not null and p_promo < p_preco
               and (p_ate is null or p_ate >= public.ff_hoje_sp())
              then p_promo else p_preco end
$$;

-- Confere um cupom e calcula o desconto (não dá erro: devolve "erro" no JSON)
create or replace function public.ff_cupom_info(p_loja uuid, p_codigo text, p_sub numeric, p_taxa numeric)
returns json language plpgsql stable security definer set search_path = public as $$
declare
  c public.ff_cupons;
  v_desc numeric;
begin
  select * into c from public.ff_cupons
   where loja_id = p_loja and codigo = upper(trim(coalesce(p_codigo, ''))) and ativo;
  if not found then return json_build_object('erro', 'cupom_invalido'); end if;
  if c.validade is not null and c.validade < public.ff_hoje_sp() then return json_build_object('erro', 'cupom_vencido'); end if;
  if c.limite is not null and c.usos >= c.limite then return json_build_object('erro', 'cupom_esgotado'); end if;
  if coalesce(p_sub, 0) < c.minimo then return json_build_object('erro', 'cupom_minimo', 'minimo', c.minimo); end if;
  v_desc := case c.tipo
              when 'percentual' then round(coalesce(p_sub, 0) * least(c.valor, 100) / 100, 2)
              when 'valor'      then least(c.valor, coalesce(p_sub, 0))
              else coalesce(p_taxa, 0) end;
  return json_build_object('codigo', c.codigo, 'tipo', c.tipo, 'valor', c.valor,
                           'minimo', c.minimo, 'desconto', v_desc);
end;
$$;
revoke all on function public.ff_cupom_info(uuid, text, numeric, numeric) from public;
grant execute on function public.ff_cupom_info(uuid, text, numeric, numeric) to anon, authenticated;

-- ---------- Criar pedido: opções, promoção e cupom calculados no servidor ----------
create or replace function public.ff_criar_pedido(
  p_loja uuid, p_cliente jsonb, p_itens jsonb, p_pagamento text, p_comprovante text default null)
returns json language plpgsql volatile security definer set search_path = public as $$
declare
  l       public.ff_lojas;
  pr      public.ff_produtos;
  it      jsonb;
  sel     jsonb;
  gr      jsonb;
  op      jsonb;
  q       int;
  n       int := 0;
  cnt     int;
  v_sub   numeric := 0;
  v_unit  numeric;
  v_snap  jsonb;
  v_dist  numeric;
  v_taxa  numeric;
  v_desc  numeric := 0;
  v_cup   text := upper(trim(coalesce(p_cliente ->> 'cupom', '')));
  v_info  json;
  v_lat   double precision := nullif(p_cliente ->> 'lat', '')::double precision;
  v_lng   double precision := nullif(p_cliente ->> 'lng', '')::double precision;
  v_ped   public.ff_pedidos;
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

    -- quantidade escolhida em cada grupo precisa respeitar mínimo e máximo
    for gr in select * from jsonb_array_elements(coalesce(pr.grupos, '[]'::jsonb)) loop
      select count(*) into cnt from jsonb_array_elements(coalesce(it -> 'opcoes', '[]'::jsonb)) s
       where s ->> 'g' = gr ->> 'id';
      if cnt < coalesce((gr ->> 'min')::int, 0) or cnt > coalesce((gr ->> 'max')::int, 99) then
        raise exception 'opcoes_invalidas';
      end if;
    end loop;
    -- não pode repetir a mesma opção
    if (select count(*) from jsonb_array_elements(coalesce(it -> 'opcoes', '[]'::jsonb)))
       <> (select count(distinct (s ->> 'g') || ':' || (s ->> 'o')) from jsonb_array_elements(coalesce(it -> 'opcoes', '[]'::jsonb)) s) then
      raise exception 'opcoes_invalidas';
    end if;

    v_unit := public.ff_preco_atual(pr.preco, pr.preco_promo, pr.promo_ate);
    v_snap := '[]'::jsonb;
    for sel in select * from jsonb_array_elements(coalesce(it -> 'opcoes', '[]'::jsonb)) loop
      select g, o into gr, op
        from jsonb_array_elements(coalesce(pr.grupos, '[]'::jsonb)) g,
             jsonb_array_elements(coalesce(g -> 'opcoes', '[]'::jsonb)) o
       where g ->> 'id' = sel ->> 'g' and o ->> 'id' = sel ->> 'o'
       limit 1;
      if gr is null or op is null then raise exception 'opcoes_invalidas'; end if;
      v_unit := v_unit + coalesce((op ->> 'preco')::numeric, 0);
      v_snap := v_snap || jsonb_build_array(jsonb_build_object(
                  'grupo', gr ->> 'nome', 'nome', op ->> 'nome', 'preco', coalesce((op ->> 'preco')::numeric, 0)));
      gr := null; op := null;
    end loop;

    insert into public.ff_pedido_itens (pedido_id, produto_id, nome, preco, qtd, obs, opcoes)
    values (v_ped.id, pr.id, pr.nome, v_unit, q, left(trim(coalesce(it ->> 'obs', '')), 200), v_snap);
    v_sub := v_sub + v_unit * q;
    n := n + 1;
  end loop;

  if n = 0 then raise exception 'carrinho_vazio'; end if;
  if v_sub < l.pedido_minimo then raise exception 'abaixo_do_minimo'; end if;

  if v_cup <> '' then
    v_info := public.ff_cupom_info(l.id, v_cup, v_sub, v_taxa);
    if v_info ->> 'erro' is not null then raise exception '%', v_info ->> 'erro'; end if;
    v_desc := least((v_info ->> 'desconto')::numeric, v_sub + v_taxa);
    update public.ff_cupons set usos = usos + 1 where loja_id = l.id and codigo = v_cup;
  end if;

  if p_pagamento = 'dinheiro' and coalesce(v_troco, 0) > 0 and v_troco < v_sub + v_taxa - v_desc then
    raise exception 'troco_invalido';
  end if;

  update public.ff_pedidos
     set subtotal = v_sub, desconto = v_desc, cupom = v_cup,
         total = greatest(v_sub + v_taxa - v_desc, 0),
         troco_para = case when p_pagamento = 'dinheiro' and coalesce(v_troco, 0) > 0 then v_troco end
   where id = v_ped.id returning * into v_ped;

  return json_build_object('token', v_ped.token, 'numero', v_ped.numero, 'total', v_ped.total);
end;
$$;
grant execute on function public.ff_criar_pedido(uuid, jsonb, jsonb, text, text) to anon, authenticated;

-- Acompanhar pedido (com opções e desconto)
create or replace function public.ff_acompanhar(p_token text)
returns json language sql stable security definer set search_path = public as $$
  select json_build_object(
    'numero', p.numero, 'status', p.status, 'criado_em', p.criado_em,
    'atualizado_em', p.atualizado_em, 'cliente_nome', p.cliente_nome,
    'endereco', p.endereco, 'complemento', p.complemento,
    'distancia_km', p.distancia_km, 'taxa_entrega', p.taxa_entrega,
    'subtotal', p.subtotal, 'desconto', p.desconto, 'cupom', p.cupom, 'total', p.total,
    'pagamento', p.pagamento, 'troco_para', p.troco_para,
    'observacao', p.observacao, 'entregador_nome', p.entregador_nome,
    'loja', json_build_object('nome', l.nome, 'slug', l.slug, 'imagem_url', l.imagem_url,
                              'telefone', l.telefone, 'tempo_entrega', l.tempo_entrega, 'cnpj', l.cnpj),
    'itens', coalesce((select json_agg(json_build_object(
                         'nome', i.nome, 'preco', i.preco, 'qtd', i.qtd, 'obs', i.obs, 'opcoes', i.opcoes))
                       from public.ff_pedido_itens i where i.pedido_id = p.id), '[]'::json))
  from public.ff_pedidos p join public.ff_lojas l on l.id = p.loja_id
  where p.token = p_token;
$$;

-- Motoboy: entregas (com opções e desconto, para o comprovante)
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
      'criado_em', p.criado_em, 'atualizado_em', p.atualizado_em,
      'itens', coalesce((select json_agg(json_build_object('nome', i.nome, 'qtd', i.qtd, 'preco', i.preco, 'obs', i.obs, 'opcoes', i.opcoes))
                         from public.ff_pedido_itens i where i.pedido_id = p.id), '[]'::json))
      order by p.criado_em)
    from public.ff_pedidos p
    where p.loja_id = v_loja
      and (p.status in ('preparando', 'saiu')
           or (p.status = 'entregue' and p.atualizado_em > now() - interval '12 hours'))
  ), '[]'::json);
end;
$$;
grant execute on function public.ff_acompanhar(text)         to anon, authenticated;
grant execute on function public.ff_entregador_pedidos(text) to anon, authenticated;
