-- GoPedido v20 — envio para outras cidades pelo Melhor Envio (só lojas de Variedades)
-- Rode depois do v19. Pode rodar mais de uma vez sem problema.
--
-- • Cada lojista conecta a própria conta do Melhor Envio (as chaves ficam numa tabela trancada, só o servidor lê).
-- • Produtos ganham peso e medidas.
-- • O frete vem de uma cotação guardada pelo servidor; o pedido só aceita esse valor.
-- • Pedido de envio: pagamento só por Pix, com CPF/CNPJ do destinatário (exigido nas etiquetas).

alter table public.ff_lojas add column if not exists me_conectado boolean not null default false;
alter table public.ff_lojas add column if not exists me_conta text not null default '';

-- Chaves de acesso do Melhor Envio de cada loja: ninguém lê pelo site, só a Edge Function
create table if not exists public.ff_me_contas (
  loja_id       uuid primary key references public.ff_lojas(id) on delete cascade,
  access_token  text not null,
  refresh_token text not null default '',
  expira        timestamptz not null,
  conta         text not null default '',
  atualizado_em timestamptz not null default now()
);
alter table public.ff_me_contas enable row level security;
revoke all on public.ff_me_contas from anon, authenticated;
grant all on public.ff_me_contas to service_role;

-- Peso e medidas (para calcular o frete)
alter table public.ff_produtos add column if not exists peso_kg numeric(8,3);
alter table public.ff_produtos add column if not exists altura_cm numeric(6,1);
alter table public.ff_produtos add column if not exists largura_cm numeric(6,1);
alter table public.ff_produtos add column if not exists comprimento_cm numeric(6,1);

-- Cotações de frete guardadas pelo servidor (valem 2 horas)
create table if not exists public.ff_cotacoes (
  id           uuid primary key default gen_random_uuid(),
  loja_id      uuid not null references public.ff_lojas(id) on delete cascade,
  cep_destino  text not null,
  servico_id   int not null,
  servico_nome text not null,
  preco        numeric(10,2) not null,
  prazo        int,
  itens_chave  text not null,
  criado_em    timestamptz not null default now(),
  expira       timestamptz not null default now() + interval '2 hours'
);
create index if not exists ff_cotacoes_loja_idx on public.ff_cotacoes (loja_id, criado_em desc);
alter table public.ff_cotacoes enable row level security;
revoke all on public.ff_cotacoes from anon, authenticated;
grant all on public.ff_cotacoes to service_role;

-- Pedido: dados do envio
alter table public.ff_pedidos add column if not exists frete_servico   int;
alter table public.ff_pedidos add column if not exists frete_nome      text not null default '';
alter table public.ff_pedidos add column if not exists frete_prazo     int;
alter table public.ff_pedidos add column if not exists cep_destino     text not null default '';
alter table public.ff_pedidos add column if not exists cliente_doc     text not null default '';
alter table public.ff_pedidos add column if not exists endereco_partes jsonb not null default '{}'::jsonb;
alter table public.ff_pedidos add column if not exists me_pedido_id    text not null default '';
alter table public.ff_pedidos add column if not exists etiqueta_status text not null default '';
alter table public.ff_pedidos add column if not exists rastreio        text not null default '';
alter table public.ff_pedidos drop constraint if exists ff_pedidos_tipo_entrega_check;
alter table public.ff_pedidos add constraint ff_pedidos_tipo_entrega_check check (tipo_entrega in ('entrega','retirada','envio'));

-- Criar pedido: igual ao v19, agora com o tipo "envio"
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
  v_grupos jsonb;
  v_dist  numeric;
  v_reta  numeric;
  v_rota  numeric := nullif(p_cliente ->> 'distancia_km', '')::numeric;
  v_taxa  numeric;
  v_desc  numeric := 0;
  v_cup   text := upper(trim(coalesce(p_cliente ->> 'cupom', '')));
  v_info  json;
  v_lat   double precision := nullif(p_cliente ->> 'lat', '')::double precision;
  v_lng   double precision := nullif(p_cliente ->> 'lng', '')::double precision;
  v_ped   public.ff_pedidos;
  v_ret   boolean := coalesce(p_cliente ->> 'tipo', 'entrega') = 'retirada';
  v_troco numeric := nullif(p_cliente ->> 'troco_para', '')::numeric;
  v_var   jsonb;
  v_env   boolean := coalesce(p_cliente ->> 'tipo', 'entrega') = 'envio';
  v_cot   public.ff_cotacoes;
  v_lin   text[] := '{}';
  v_chave text;
  v_baixa boolean;
  v_nome  text;
begin
  select * into l from public.ff_lojas where id = p_loja and ativa;
  if not found then raise exception 'loja_invalida'; end if;
  if not public.ff_aberta_agora(l.horario_auto, l.aberta, l.horarios) then raise exception 'loja_fechada'; end if;
  if l.verificacao <> 'verificada' then raise exception 'loja_em_analise'; end if;
  if l.lat is null or l.lng is null then raise exception 'loja_sem_localizacao'; end if;
  if v_ret and not l.aceita_retirada then raise exception 'retirada_indisponivel'; end if;
  -- envio pelo Melhor Envio: só lojas de Variedades com envio ligado, cotação válida e pagamento por Pix
  if v_env then
    if l.tipo <> 'variedades' or not l.envio_externo or not l.me_conectado then raise exception 'envio_indisponivel'; end if;
    if p_pagamento <> 'pix' then raise exception 'pagamento_envio'; end if;
    select * into v_cot from public.ff_cotacoes
     where id = nullif(p_cliente ->> 'cotacao', '')::uuid and loja_id = l.id and expira > now();
    if not found then raise exception 'cotacao_vencida'; end if;
    if length(regexp_replace(coalesce(p_cliente ->> 'cpf', ''), '\D', '', 'g')) not in (11, 14) then raise exception 'cpf_obrigatorio'; end if;
  end if;

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
     or (not v_ret and length(trim(coalesce(p_cliente ->> 'endereco', ''))) < 5) then
    raise exception 'dados_incompletos';
  end if;

  if v_ret then
    -- retirada no local: sem taxa e sem endereço
    v_lat := l.lat; v_lng := l.lng; v_dist := 0; v_taxa := 0;
  elsif v_env then
    -- envio: o frete é o da cotação que o servidor guardou (não dá para mudar pelo navegador)
    v_dist := 0; v_taxa := v_cot.preco;
    if v_lat is null or v_lng is null then v_lat := l.lat; v_lng := l.lng; end if;
  else
    if v_lat is null or v_lng is null then raise exception 'localizacao_obrigatoria'; end if;
    -- distância pela rota (calculada no site); se não vier ou for impossível, estima linha reta + 30%
    v_reta := public.ff_distancia_km(l.lat, l.lng, v_lat, v_lng);
    v_dist := case when v_rota is not null and v_rota >= v_reta and v_rota <= v_reta * 3 + 1 then round(v_rota, 2)
                   else round(v_reta * 1.3, 2) end;
    v_taxa := public.ff_taxa_entrega(l.taxa_modo, l.taxa_km, l.taxa_minima, l.km_arredonda, l.taxa_tabela, l.raio_km, v_dist);
    if v_taxa is null then raise exception 'fora_da_area'; end if;
  end if;

  insert into public.ff_pedidos
    (loja_id, cliente_id, cliente_nome, cliente_telefone, endereco, complemento, lat, lng,
     distancia_km, taxa_entrega, pagamento, comprovante_path, observacao, tipo_entrega,
     frete_servico, frete_nome, frete_prazo, cep_destino, cliente_doc, endereco_partes)
  values
    (l.id, auth.uid(), left(trim(p_cliente ->> 'nome'), 80), left(trim(p_cliente ->> 'telefone'), 30),
     case when v_ret then 'Retirada no local' else left(trim(p_cliente ->> 'endereco'), 200) end,
     case when v_ret then '' else left(trim(coalesce(p_cliente ->> 'complemento', '')), 120) end,
     v_lat, v_lng, v_dist, v_taxa, p_pagamento,
     case when p_pagamento = 'pix' then p_comprovante end,
     left(trim(coalesce(p_cliente ->> 'observacao', '')), 300),
     case when v_ret then 'retirada' when v_env then 'envio' else 'entrega' end,
     case when v_env then v_cot.servico_id end,
     case when v_env then v_cot.servico_nome end,
     case when v_env then v_cot.prazo end,
     case when v_env then v_cot.cep_destino end,
     case when v_env then regexp_replace(coalesce(p_cliente ->> 'cpf', ''), '\D', '', 'g') else '' end,
     case when v_env then coalesce(p_cliente -> 'partes', '{}'::jsonb) else '{}'::jsonb end)
  returning * into v_ped;

  for it in select * from jsonb_array_elements(coalesce(p_itens, '[]'::jsonb)) loop
    q := least(greatest(coalesce((it ->> 'qtd')::int, 0), 0), 99);
    continue when q = 0;
    -- "for update": trava o produto até o fim do pedido, para o estoque não ser vendido duas vezes
    select * into pr from public.ff_produtos
     where id = (it ->> 'id')::uuid and loja_id = l.id and disponivel for update;
    if not found then raise exception 'produto_indisponivel'; end if;

    -- variação (tamanho, cor, sabor…) e estoque
    v_var := null; v_baixa := false; v_nome := pr.nome;
    if jsonb_array_length(coalesce(pr.variacoes, '[]'::jsonb)) > 0 then
      select v into v_var from jsonb_array_elements(pr.variacoes) v where v ->> 'id' = it ->> 'v' limit 1;
      if v_var is null then raise exception 'escolha_variacao'; end if;
      v_nome := pr.nome || ' (' || (v_var ->> 'nome') || ')';
      if nullif(v_var ->> 'estoque', '') is not null then
        if (v_var ->> 'estoque')::int < q then raise exception 'sem_estoque'; end if;
        update public.ff_produtos
           set variacoes = (select jsonb_agg(case when x ->> 'id' = v_var ->> 'id'
                                                  then jsonb_set(x, '{estoque}', to_jsonb((x ->> 'estoque')::int - q)) else x end
                                             order by ord)
                              from jsonb_array_elements(variacoes) with ordinality t(x, ord))
         where id = pr.id;
        v_baixa := true;
      end if;
    elsif pr.estoque is not null then
      if pr.estoque < q then raise exception 'sem_estoque'; end if;
      update public.ff_produtos set estoque = estoque - q where id = pr.id;
      v_baixa := true;
    end if;

    -- etapas do produto + adicionais compartilhados da loja ligados a ele
    v_grupos := coalesce(pr.grupos, '[]'::jsonb) || coalesce((
      select jsonb_agg(jsonb_build_object('id', 'e:' || e.id, 'nome', e.nome, 'min', e.min, 'max', e.max, 'opcoes', e.opcoes)
                       order by array_position(pr.etapas_ids, e.id))
        from public.ff_etapas e
       where e.loja_id = l.id and e.id = any(coalesce(pr.etapas_ids, '{}'::uuid[]))), '[]'::jsonb);

    -- quantidade escolhida em cada grupo precisa respeitar mínimo e máximo
    for gr in select * from jsonb_array_elements(v_grupos) loop
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

    -- variação com preço próprio substitui o preço do produto
    v_unit := case when v_var is not null and nullif(v_var ->> 'preco', '') is not null
                   then (v_var ->> 'preco')::numeric
                   else public.ff_preco_atual(pr.preco, pr.preco_promo, pr.promo_ate) end;
    v_snap := '[]'::jsonb;
    for sel in select * from jsonb_array_elements(coalesce(it -> 'opcoes', '[]'::jsonb)) loop
      select g, o into gr, op
        from jsonb_array_elements(v_grupos) g,
             jsonb_array_elements(coalesce(g -> 'opcoes', '[]'::jsonb)) o
       where g ->> 'id' = sel ->> 'g' and o ->> 'id' = sel ->> 'o'
       limit 1;
      if gr is null or op is null then raise exception 'opcoes_invalidas'; end if;
      v_unit := v_unit + coalesce((op ->> 'preco')::numeric, 0);
      v_snap := v_snap || jsonb_build_array(jsonb_build_object(
                  'grupo', gr ->> 'nome', 'nome', op ->> 'nome', 'preco', coalesce((op ->> 'preco')::numeric, 0)));
      gr := null; op := null;
    end loop;

    insert into public.ff_pedido_itens (pedido_id, produto_id, nome, preco, qtd, obs, opcoes, variacao_id, estoque_baixado)
    values (v_ped.id, pr.id, left(v_nome, 120), v_unit, q, left(trim(coalesce(it ->> 'obs', '')), 200), v_snap,
            v_var ->> 'id', v_baixa);
    v_sub := v_sub + v_unit * q;
    v_lin := v_lin || ((pr.id::text) || '|' || coalesce(v_var ->> 'id', '') || '|' || q::text);
    n := n + 1;
  end loop;

  if n = 0 then raise exception 'carrinho_vazio'; end if;
  -- a cotação precisa ser exatamente destes produtos e quantidades
  if v_env then
    select string_agg(k || '|' || t::text, ',' order by k) into v_chave
      from (select split_part(x, '|', 1) || '|' || split_part(x, '|', 2) as k, sum(split_part(x, '|', 3)::int) as t
              from unnest(v_lin) x group by 1) s;
    if v_chave is distinct from v_cot.itens_chave then raise exception 'cotacao_vencida'; end if;
  end if;
  if v_sub < l.pedido_minimo then raise exception 'abaixo_do_minimo'; end if;

  if v_cup <> '' then
    v_info := public.ff_cupom_info(l.id, v_cup, v_sub, v_taxa, p_cliente ->> 'telefone');
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

-- Acompanhar pedido: inclui transportadora, prazo e rastreio
create or replace function public.ff_acompanhar(p_token text)
returns json language sql stable security definer set search_path = public as $$
  select json_build_object(
    'numero', p.numero, 'status', p.status, 'criado_em', p.criado_em,
    'atualizado_em', p.atualizado_em, 'cliente_nome', p.cliente_nome,
    'endereco', p.endereco, 'complemento', p.complemento, 'tipo_entrega', p.tipo_entrega,
    'frete_nome', p.frete_nome, 'frete_prazo', p.frete_prazo, 'rastreio', p.rastreio,
    'distancia_km', p.distancia_km, 'taxa_entrega', p.taxa_entrega,
    'subtotal', p.subtotal, 'desconto', p.desconto, 'cupom', p.cupom, 'total', p.total,
    'pagamento', p.pagamento, 'troco_para', p.troco_para,
    'observacao', p.observacao, 'entregador_nome', p.entregador_nome,
    'loja', json_build_object('nome', l.nome, 'slug', l.slug, 'imagem_url', l.imagem_url,
                              'telefone', l.telefone, 'tempo_entrega', l.tempo_entrega, 'cnpj', l.cnpj,
                              'endereco', l.endereco, 'lat', l.lat, 'lng', l.lng),
    'avaliacao', (select json_build_object('nota', a.nota, 'comentario', a.comentario, 'resposta', a.resposta)
                    from public.ff_avaliacoes a where a.pedido_id = p.id),
    'itens', coalesce((select json_agg(json_build_object(
                         'nome', i.nome, 'preco', i.preco, 'qtd', i.qtd, 'obs', i.obs, 'opcoes', i.opcoes))
                       from public.ff_pedido_itens i where i.pedido_id = p.id), '[]'::json))
  from public.ff_pedidos p join public.ff_lojas l on l.id = p.loja_id
  where p.token = p_token;
$$;
grant execute on function public.ff_acompanhar(text) to anon, authenticated;

grant execute on all functions in schema public to service_role;

-- Proteção da loja: "conta do Melhor Envio conectada" só o servidor marca; envio para fora só o dono liga
create or replace function public.ff_protege_loja()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if public.ff_is_admin() or pg_trigger_depth() > 1 then return new; end if;
  if tg_op = 'INSERT' then
    new.verificacao := 'pendente'; new.verificacao_motivo := '';
    new.nota_media := null; new.nota_qtd := 0;
    if auth.uid() is not null then new.me_conectado := false; new.me_conta := ''; new.envio_externo := false; end if;
  else
    new.verificacao := old.verificacao; new.verificacao_motivo := old.verificacao_motivo;
    new.nota_media := old.nota_media; new.nota_qtd := old.nota_qtd;
    if auth.uid() is not null then
      new.me_conectado := old.me_conectado; new.me_conta := old.me_conta;
      if not old.me_conectado then new.envio_externo := false; end if;
    end if;
    if auth.uid() is not null and auth.uid() <> old.dono then
      -- alguém da equipe (não o dono): não muda dono, bloqueio, Pix, formas de pagamento nem o envio
      new.dono := old.dono; new.ativa := old.ativa;
      new.pix_tipo := old.pix_tipo; new.pix_chave := old.pix_chave;
      new.pix_nome := old.pix_nome; new.pix_cidade := old.pix_cidade;
      new.aceita_pix := old.aceita_pix; new.aceita_debito := old.aceita_debito;
      new.aceita_credito := old.aceita_credito; new.aceita_dinheiro := old.aceita_dinheiro;
      new.envio_externo := old.envio_externo;
    elsif auth.uid() is not null then
      new.dono := old.dono; new.ativa := old.ativa;   -- o dono também não troca o dono nem se desbloqueia
    end if;
  end if;
  return new;
end;
$$;
