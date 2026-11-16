-- GoPedido · SQL v39 — Histórico de vendas no Financeiro (site + caixa), com recibo
-- Rode depois do v38. Pode rodar mais de uma vez. Só dono e administradores veem.

-- Lista de vendas de qualquer período: pedidos do site (delivery/retirada) e vendas do caixa (balcão e contas)
create or replace function public.ff_fin_vendas(p_loja uuid, p_de date, p_ate date, p_origem text, p_busca text, p_limite int, p_offset int)
returns json language plpgsql stable security definer set search_path = public as $$
declare l public.ff_lojas; v_q text := lower(trim(coalesce(p_busca, ''))); v_lim int := least(greatest(coalesce(p_limite, 50), 1), 200);
begin
  l := public.ff_pdv_loja(p_loja, array['dono', 'admin']);
  if p_de is null or p_ate is null or p_ate < p_de or p_ate - p_de > 400 then raise exception 'periodo_longo'; end if;
  if coalesce(p_origem, 'todas') not in ('todas', 'site', 'balcao', 'mesa') then raise exception 'tipo_invalido'; end if;
  return (
    with todas as (
      select 'site'::text as origem, p.id, p.numero, p.criado_em as quando, p.cliente_nome as cliente, p.total, p.status,
             jsonb_build_array(jsonb_build_object('forma', p.pagamento, 'valor', p.total)) as pagamentos,
             coalesce(p.tipo_entrega, 'entrega') as detalhe, coalesce(p.entregador_nome, '') as usuario,
             (p.nf_path is not null and p.nf_path <> '') as tem_nf, p.token
        from public.ff_pedidos p
       where p.loja_id = p_loja and (p.criado_em at time zone 'America/Sao_Paulo')::date between p_de and p_ate
         and coalesce(p_origem, 'todas') in ('todas', 'site')
      union all
      select v.origem, v.id, v.numero, v.criado_em, v.cliente, v.total, v.status, v.pagamentos,
             v.obs, v.usuario_nome, false, null
        from public.ff_vendas v
       where v.loja_id = p_loja and (v.criado_em at time zone 'America/Sao_Paulo')::date between p_de and p_ate
         and coalesce(p_origem, 'todas') in ('todas', v.origem)
    ), filtradas as (
      select * from todas
       where v_q = '' or lower(coalesce(cliente, '')) like '%' || v_q || '%' or numero::text = v_q or lower(coalesce(usuario, '')) like '%' || v_q || '%'
    )
    select json_build_object(
      'qtd', (select count(*) from filtradas),
      'valor', (select coalesce(sum(total), 0) from filtradas where status in ('entregue', 'concluida')),
      'itens', coalesce((select json_agg(x order by x.quando desc) from (select * from filtradas order by quando desc limit v_lim offset greatest(coalesce(p_offset, 0), 0)) x), '[]'::json))
  );
end $$;
revoke all on function public.ff_fin_vendas(uuid, date, date, text, text, int, int) from public, anon;
grant execute on function public.ff_fin_vendas(uuid, date, date, text, text, int, int) to authenticated;

-- Detalhe de uma venda para ver e imprimir o recibo
create or replace function public.ff_fin_venda(p_origem text, p_id uuid)
returns json language plpgsql stable security definer set search_path = public as $$
declare v_loja uuid; l public.ff_lojas;
begin
  if p_origem = 'site' then
    select loja_id into v_loja from public.ff_pedidos where id = p_id;
    if v_loja is null then raise exception 'venda_nao_encontrada'; end if;
    l := public.ff_pdv_loja(v_loja, array['dono', 'admin']);
    return (select json_build_object('origem', 'site', 'numero', p.numero, 'criado_em', p.criado_em, 'cliente', p.cliente_nome, 'telefone', p.cliente_telefone,
        'endereco', p.endereco, 'tipo_entrega', p.tipo_entrega, 'status', p.status, 'subtotal', p.subtotal, 'desconto', coalesce(p.desconto, 0) + coalesce(p.fidelidade_desc, 0),
        'taxa_entrega', p.taxa_entrega, 'total', p.total, 'pagamento', p.pagamento, 'troco_para', p.troco_para, 'observacao', p.observacao,
        'entregador', p.entregador_nome, 'nf_path', p.nf_path, 'token', p.token,
        'itens', coalesce((select json_agg(json_build_object('nome', i.nome, 'preco', i.preco, 'qtd', i.qtd, 'opcoes', i.opcoes, 'obs', i.obs) order by i.id)
                             from public.ff_pedido_itens i where i.pedido_id = p.id), '[]'::json))
      from public.ff_pedidos p where p.id = p_id);
  end if;
  select loja_id into v_loja from public.ff_vendas where id = p_id;
  if v_loja is null then raise exception 'venda_nao_encontrada'; end if;
  l := public.ff_pdv_loja(v_loja, array['dono', 'admin']);
  return (select json_build_object('origem', v.origem, 'id', v.id, 'numero', v.numero, 'criado_em', v.criado_em, 'cliente', v.cliente, 'obs', v.obs,
      'status', v.status, 'subtotal', v.subtotal, 'desconto', v.desconto, 'taxa_servico', v.taxa_servico, 'total', v.total, 'pagamentos', v.pagamentos,
      'troco', v.troco, 'usuario_nome', v.usuario_nome, 'cancel_motivo', v.cancel_motivo, 'cancelada_por_nome', v.cancelada_por_nome,
      'caixa', (select numero from public.ff_caixas where id = v.caixa_id), 'caixa_status', (select status from public.ff_caixas where id = v.caixa_id),
      'itens', coalesce((select json_agg(json_build_object('nome', i.nome, 'preco', i.preco, 'qtd', i.qtd, 'opcoes', i.opcoes, 'obs', i.obs) order by i.id)
                           from public.ff_venda_itens i where i.venda_id = v.id), '[]'::json))
    from public.ff_vendas v where v.id = p_id);
end $$;
revoke all on function public.ff_fin_venda(text, uuid) from public, anon;
grant execute on function public.ff_fin_venda(text, uuid) to authenticated;

notify pgrst, 'reload schema';
