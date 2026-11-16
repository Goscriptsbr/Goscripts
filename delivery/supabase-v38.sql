-- GoPedido · SQL v38 — Caixa sem internet e impressão para a cozinha
-- Rode depois do v37. Pode rodar mais de uma vez.
--
-- • Venda feita SEM INTERNET: fica guardada no aparelho do caixa e, quando a internet volta, é enviada com a
--   hora em que aconteceu. O código único da venda garante que ela não entra duas vezes.
--   Como a venda já aconteceu de verdade, vale o preço que foi cobrado na hora; o estoque é baixado
--   (sem ficar negativo) e a venda vai para o caixa que estava aberto naquele horário.
-- • "Pagar depois" no caixa: lança os itens no nome do cliente (sem mesa), vai para a cozinha e fica em
--   "Contas abertas" até pagar. Funciona mesmo se a loja não usa mesas.
-- • Cozinha: o computador do caixa pode imprimir sozinho os itens que os garçons lançam nas mesas.
--   Cada item é "pego" uma vez só: mesmo com dois aparelhos ligados, não imprime repetido.

-- Venda registrada sem internet (enviada depois)
create or replace function public.ff_pdv_vender_offline(p_loja uuid, p_itens jsonb, p_desconto numeric, p_pagamentos jsonb,
                                                        p_cliente text, p_idem uuid, p_quando timestamptz)
returns json language plpgsql volatile security definer set search_path = public as $$
declare
  l public.ff_lojas; c public.ff_caixas; ve public.ff_vendas; it jsonb; pr public.ff_produtos; v_q int; v_g int; v_preco numeric;
  v_sub numeric := 0; v_desc numeric; v_tot numeric; v_pg jsonb; v_num int; v_quando timestamptz; v_baixa boolean; v_var text;
begin
  l := public.ff_pdv_loja(p_loja, array['dono', 'admin', 'caixa']);
  if p_idem is null then raise exception 'venda_invalida'; end if;
  perform pg_advisory_xact_lock(hashtext('caixa:' || p_loja::text));
  select * into ve from public.ff_vendas where loja_id = p_loja and idem = p_idem;
  if ve.id is not null then
    return json_build_object('id', ve.id, 'numero', ve.numero, 'total', ve.total, 'troco', ve.troco, 'repetida', true);
  end if;
  v_quando := case when p_quando is null or p_quando > now() + interval '10 minutes' or p_quando < now() - interval '15 days' then now() else p_quando end;
  -- o caixa que estava aberto naquela hora (ou o aberto agora)
  select * into c from public.ff_caixas where loja_id = p_loja and aberto_em <= v_quando and (fechado_em is null or fechado_em >= v_quando)
   order by aberto_em desc limit 1;
  if c.id is null then select * into c from public.ff_caixas where loja_id = p_loja and status = 'aberto'; end if;

  if jsonb_typeof(coalesce(p_itens, 'null'::jsonb)) <> 'array' or jsonb_array_length(p_itens) = 0 then raise exception 'carrinho_vazio'; end if;
  if jsonb_array_length(p_itens) > 300 then raise exception 'venda_grande'; end if;
  for it in select * from jsonb_array_elements(p_itens) loop
    v_preco := round(coalesce((it ->> 'preco')::numeric, -1), 2);
    v_q := coalesce((it ->> 'qtd')::int, 1);
    v_g := nullif(it ->> 'g', '')::int;
    if v_preco < 0 or v_preco > 1000000 or v_q < 1 or v_q > 999 or length(trim(coalesce(it ->> 'nome', ''))) < 1 then raise exception 'venda_invalida'; end if;
    if v_g is not null then v_q := 1; end if;
    v_sub := v_sub + v_preco * v_q;
  end loop;
  v_sub := round(v_sub, 2);
  v_desc := round(coalesce(p_desconto, 0), 2);
  if v_desc < 0 or v_desc > v_sub then raise exception 'desconto_invalido'; end if;
  v_tot := v_sub - v_desc;
  v_pg := public.ff_pdv_pagamentos(p_pagamentos, v_tot);

  select coalesce(max(numero), 0) + 1 into v_num from public.ff_vendas where loja_id = p_loja;
  insert into public.ff_vendas (loja_id, numero, idem, caixa_id, subtotal, desconto, total, pagamentos, troco, cliente, obs, usuario, usuario_nome, criado_em)
  values (p_loja, v_num, p_idem, c.id, v_sub, v_desc, v_tot, v_pg -> 'pagamentos', (v_pg ->> 'troco')::numeric, left(trim(coalesce(p_cliente, '')), 80),
          'Registrada sem internet', auth.uid(), public.ff_nome_usuario(), v_quando)
  returning * into ve;

  for it in select * from jsonb_array_elements(p_itens) loop
    v_q := case when nullif(it ->> 'g', '') is not null then 1 else coalesce((it ->> 'qtd')::int, 1) end;
    v_baixa := false; v_var := nullif(it ->> 'v', '');
    select * into pr from public.ff_produtos where id = nullif(it ->> 'id', '')::uuid and loja_id = p_loja for update;
    if pr.id is not null and nullif(it ->> 'g', '') is null then
      -- baixa o estoque sem deixar negativo (a venda já aconteceu)
      if v_var is not null and jsonb_array_length(coalesce(pr.variacoes, '[]'::jsonb)) > 0 then
        update public.ff_produtos
           set variacoes = (select jsonb_agg(case when x ->> 'id' = v_var and nullif(x ->> 'estoque', '') is not null
                                                  then jsonb_set(x, '{estoque}', to_jsonb(greatest((x ->> 'estoque')::int - v_q, 0))) else x end order by ord)
                              from jsonb_array_elements(variacoes) with ordinality t(x, ord))
         where id = pr.id;
        v_baixa := exists (select 1 from jsonb_array_elements(pr.variacoes) x where x ->> 'id' = v_var and nullif(x ->> 'estoque', '') is not null);
      elsif pr.estoque is not null then
        update public.ff_produtos set estoque = greatest(estoque - v_q, 0) where id = pr.id;
        v_baixa := true;
      end if;
    end if;
    insert into public.ff_venda_itens (venda_id, produto_id, nome, preco, qtd, peso_g, opcoes, variacao_id, estoque_baixado, obs)
    values (ve.id, pr.id, left(trim(it ->> 'nome'), 120), round((it ->> 'preco')::numeric, 2), v_q, nullif(it ->> 'g', '')::int,
            coalesce(it -> 'opcoes', '[]'::jsonb), v_var, v_baixa, left(trim(coalesce(it ->> 'obs', '')), 200));
    pr := null;
  end loop;
  return json_build_object('id', ve.id, 'numero', ve.numero, 'total', ve.total, 'troco', ve.troco, 'repetida', false);
end $$;
revoke all on function public.ff_pdv_vender_offline(uuid, jsonb, numeric, jsonb, text, uuid, timestamptz) from public, anon;
grant execute on function public.ff_pdv_vender_offline(uuid, jsonb, numeric, jsonb, text, uuid, timestamptz) to authenticated;

-- Cozinha: pega os itens novos das mesas (marca como "preparando") para imprimir. Cada item sai uma vez só.
create or replace function public.ff_cozinha_pegar(p_loja uuid)
returns json language plpgsql volatile security definer set search_path = public as $$
declare l public.ff_lojas; v_ids uuid[];
begin
  l := public.ff_pdv_loja(p_loja, array['dono', 'admin', 'caixa']);
  select array_agg(id) into v_ids from (
    select i.id from public.ff_comanda_itens i join public.ff_comandas c on c.id = i.comanda_id
     where i.loja_id = p_loja and i.status = 'ativo' and i.cozinha = 'novo' and c.status in ('aberta', 'conta')
     order by i.criado_em limit 200 for update of i skip locked) a;
  if v_ids is null then return '[]'::json; end if;
  update public.ff_comanda_itens set cozinha = 'preparando' where id = any (v_ids);
  return coalesce((select json_agg(g order by g.primeiro) from (
    select c.id, c.numero, coalesce(m.nome, nullif(c.identificador, ''), 'Comanda ' || c.numero) as onde, min(i.criado_em) as primeiro,
           string_agg(distinct i.lancado_por_nome, ', ') as garcom,
           json_agg(json_build_object('nome', i.nome, 'qtd', i.qtd, 'opcoes', i.opcoes, 'obs', i.obs) order by i.criado_em) as itens
      from public.ff_comanda_itens i join public.ff_comandas c on c.id = i.comanda_id left join public.ff_mesas m on m.id = c.mesa_id
     where i.id = any (v_ids)
     group by c.id, c.numero, m.nome, c.identificador) g), '[]'::json);
end $$;
revoke all on function public.ff_cozinha_pegar(uuid) from public, anon;
grant execute on function public.ff_cozinha_pegar(uuid) to authenticated;

-- Abrir conta: mesa (precisa das mesas ligadas) ou conta avulsa no nome do cliente (mesas OU caixa ligado)
create or replace function public.ff_comanda_abrir(p_loja uuid, p_mesa uuid, p_identificador text, p_pessoas int)
returns json language plpgsql volatile security definer set search_path = public as $$
declare l public.ff_lojas; c public.ff_comandas; v_num int; v_id text := left(trim(coalesce(p_identificador, '')), 40);
begin
  l := public.ff_pdv_loja(p_loja, array['dono', 'admin', 'caixa', 'garcom']);
  if p_mesa is not null and not l.mesas_ativo then raise exception 'mesas_desligadas'; end if;
  if p_mesa is null and not (l.mesas_ativo or l.pdv_ativo) then raise exception 'mesas_desligadas'; end if;
  perform pg_advisory_xact_lock(hashtext('comanda:' || p_loja::text));
  if p_mesa is not null then
    if not exists (select 1 from public.ff_mesas where id = p_mesa and loja_id = p_loja and ativa) then raise exception 'mesa_invalida'; end if;
    select * into c from public.ff_comandas where mesa_id = p_mesa and status in ('aberta', 'conta');
    if c.id is not null then return public.ff_comanda_json(c.id); end if;
    v_id := '';
  else
    if length(v_id) < 1 then raise exception 'identifique_comanda'; end if;
    select * into c from public.ff_comandas where loja_id = p_loja and mesa_id is null and lower(identificador) = lower(v_id) and status in ('aberta', 'conta');
    if c.id is not null then return public.ff_comanda_json(c.id); end if;
  end if;
  select coalesce(max(numero), 0) + 1 into v_num from public.ff_comandas where loja_id = p_loja;
  insert into public.ff_comandas (loja_id, numero, mesa_id, identificador, pessoas, aberta_por, aberta_por_nome)
  values (p_loja, v_num, p_mesa, v_id, greatest(1, least(coalesce(p_pessoas, 1), 99)), auth.uid(), public.ff_nome_usuario())
  returning * into c;
  return public.ff_comanda_json(c.id);
end $$;
revoke all on function public.ff_comanda_abrir(uuid, uuid, text, int) from public, anon;
grant execute on function public.ff_comanda_abrir(uuid, uuid, text, int) to authenticated;

notify pgrst, 'reload schema';
