-- =====================================================================
--  GoPedido — ATUALIZAÇÃO 3: CNPJ da loja e várias lojas por conta
--  Rode DEPOIS do supabase.sql e do supabase-v2.sql. Pode rodar de novo.
-- =====================================================================

alter table public.ff_lojas add column if not exists cnpj text not null default '';

-- Permite mais de uma loja na mesma conta
alter table public.ff_lojas drop constraint if exists ff_lojas_dono_key;
create index if not exists ff_lojas_dono_idx on public.ff_lojas (dono);

-- Código do motoboy agora é por loja escolhida
drop function if exists public.ff_codigo_entregador(boolean);
create or replace function public.ff_codigo_entregador(p_loja uuid, p_novo boolean default false)
returns json language plpgsql volatile security definer set search_path = public as $$
declare
  a public.ff_entregador_acesso;
begin
  if not exists (select 1 from public.ff_lojas where id = p_loja and dono = auth.uid()) then
    raise exception 'sem_loja';
  end if;
  select * into a from public.ff_entregador_acesso where loja_id = p_loja;
  if not found or p_novo or a.expira <= now() then
    insert into public.ff_entregador_acesso (loja_id, codigo, expira)
    values (p_loja, public.ff_gera_codigo(), now() + interval '8 hours')
    on conflict (loja_id) do update set codigo = excluded.codigo, expira = excluded.expira
    returning * into a;
  end if;
  return json_build_object('codigo', a.codigo, 'expira', a.expira);
end;
$$;
revoke all on function public.ff_codigo_entregador(uuid, boolean) from public;
grant execute on function public.ff_codigo_entregador(uuid, boolean) to authenticated;

-- Acompanhar pedido: inclui o CNPJ da loja
create or replace function public.ff_acompanhar(p_token text)
returns json language sql stable security definer set search_path = public as $$
  select json_build_object(
    'numero', p.numero, 'status', p.status, 'criado_em', p.criado_em,
    'atualizado_em', p.atualizado_em, 'cliente_nome', p.cliente_nome,
    'endereco', p.endereco, 'complemento', p.complemento,
    'distancia_km', p.distancia_km, 'taxa_entrega', p.taxa_entrega,
    'subtotal', p.subtotal, 'total', p.total, 'pagamento', p.pagamento,
    'observacao', p.observacao, 'entregador_nome', p.entregador_nome,
    'loja', json_build_object('nome', l.nome, 'slug', l.slug, 'imagem_url', l.imagem_url,
                              'telefone', l.telefone, 'tempo_entrega', l.tempo_entrega, 'cnpj', l.cnpj),
    'itens', coalesce((select json_agg(json_build_object(
                         'nome', i.nome, 'preco', i.preco, 'qtd', i.qtd, 'obs', i.obs))
                       from public.ff_pedido_itens i where i.pedido_id = p.id), '[]'::json))
  from public.ff_pedidos p join public.ff_lojas l on l.id = p.loja_id
  where p.token = p_token;
$$;
