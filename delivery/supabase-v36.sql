-- GoPedido · SQL v36 — Mesas, comandas e garçom (ligados ao caixa do v35)
-- Rode depois do v35. Pode rodar mais de uma vez.
--
-- • A loja liga "Mesas e comandas" (opcional) e cadastra as mesas.
-- • Garçom (função nova na equipe) abre a mesa ou uma comanda avulsa, lança itens pelo celular e pede a conta.
-- • Cada item lançado tem um código único gerado no celular: se a internet falhar e reenviar, NÃO duplica.
-- • O caixa recebe e fecha a comanda (desconto, taxa de serviço, várias formas de pagamento, troco).
--   Ao fechar vira uma venda do caixa (origem "mesa") e entra no Financeiro.
-- • Preço e estoque sempre calculados aqui no banco. Item cancelado devolve o estoque e fica registrado.

-- =====================================================================
-- 1) Configuração
-- =====================================================================
alter table public.ff_lojas add column if not exists mesas_ativo boolean not null default false;
alter table public.ff_lojas add column if not exists taxa_servico numeric(5,2) not null default 0;
alter table public.ff_lojas drop constraint if exists ff_lojas_taxa_servico_check;
alter table public.ff_lojas add constraint ff_lojas_taxa_servico_check check (taxa_servico between 0 and 30);

-- garçom agora pode ser escolhido na equipe
create or replace function public.ff_equipe_funcao(p_id uuid, p_funcao text)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  if p_funcao not in ('admin', 'caixa', 'garcom') then raise exception 'funcao_invalida'; end if;
  update public.ff_equipe set funcao = p_funcao where id = p_id and dono = auth.uid();
  if not found then raise exception 'membro_invalido'; end if;
end $$;
revoke all on function public.ff_equipe_funcao(uuid, text) from public, anon;
grant execute on function public.ff_equipe_funcao(uuid, text) to authenticated;

-- =====================================================================
-- 2) Tabelas
-- =====================================================================
create table if not exists public.ff_mesas (
  id uuid primary key default gen_random_uuid(),
  loja_id uuid not null references public.ff_lojas(id) on delete cascade,
  nome text not null check (length(trim(nome)) between 1 and 30),
  ordem int not null default 0,
  ativa boolean not null default true,
  criado_em timestamptz not null default now()
);
create index if not exists ff_mesas_loja on public.ff_mesas (loja_id, ordem);
create unique index if not exists ff_mesas_nome on public.ff_mesas (loja_id, lower(trim(nome))) where ativa;

create table if not exists public.ff_comandas (
  id uuid primary key default gen_random_uuid(),
  loja_id uuid not null references public.ff_lojas(id) on delete cascade,
  numero int not null,
  mesa_id uuid references public.ff_mesas(id) on delete set null,
  identificador text not null default '',          -- comanda avulsa: número do cartão ou nome do cliente
  status text not null default 'aberta' check (status in ('aberta', 'conta', 'fechada', 'cancelada')),
  pessoas int not null default 1 check (pessoas between 1 and 99),
  obs text not null default '',
  aberta_por uuid, aberta_por_nome text not null default '', aberta_em timestamptz not null default now(),
  conta_em timestamptz,
  fechada_em timestamptz, fechada_por_nome text not null default '',
  venda_id uuid references public.ff_vendas(id),
  cancel_motivo text not null default ''
);
create unique index if not exists ff_comandas_numero on public.ff_comandas (loja_id, numero);
create unique index if not exists ff_comandas_mesa_aberta on public.ff_comandas (mesa_id) where status in ('aberta', 'conta') and mesa_id is not null;
create unique index if not exists ff_comandas_ident_aberta on public.ff_comandas (loja_id, lower(identificador)) where status in ('aberta', 'conta') and mesa_id is null;
create index if not exists ff_comandas_loja_status on public.ff_comandas (loja_id, status);

create table if not exists public.ff_comanda_itens (
  id uuid primary key default gen_random_uuid(),
  comanda_id uuid not null references public.ff_comandas(id) on delete cascade,
  loja_id uuid not null,
  idem uuid not null,
  produto_id uuid references public.ff_produtos(id) on delete set null,
  nome text not null,
  preco numeric(12,2) not null,
  qtd int not null default 1,
  peso_g int,
  opcoes jsonb not null default '[]'::jsonb,
  variacao_id text,
  estoque_baixado boolean not null default false,
  obs text not null default '',
  status text not null default 'ativo' check (status in ('ativo', 'cancelado')),
  cozinha text not null default 'novo' check (cozinha in ('novo', 'preparando', 'pronto', 'entregue')),
  lancado_por uuid, lancado_por_nome text not null default '', criado_em timestamptz not null default now(),
  cancelado_em timestamptz, cancelado_por_nome text not null default '', cancel_motivo text not null default ''
);
create unique index if not exists ff_comanda_itens_idem on public.ff_comanda_itens (loja_id, idem);
create index if not exists ff_comanda_itens_comanda on public.ff_comanda_itens (comanda_id);

alter table public.ff_vendas add column if not exists taxa_servico numeric(12,2) not null default 0;
alter table public.ff_vendas add column if not exists comanda_id uuid;

alter table public.ff_mesas enable row level security;
alter table public.ff_comandas enable row level security;
alter table public.ff_comanda_itens enable row level security;
drop policy if exists ff_mesas_ver on public.ff_mesas;
create policy ff_mesas_ver on public.ff_mesas for select to authenticated using (public.ff_minha_loja(loja_id) or public.ff_is_admin());
drop policy if exists ff_comandas_ver on public.ff_comandas;
create policy ff_comandas_ver on public.ff_comandas for select to authenticated using (public.ff_minha_loja(loja_id) or public.ff_is_admin());
drop policy if exists ff_comanda_itens_ver on public.ff_comanda_itens;
create policy ff_comanda_itens_ver on public.ff_comanda_itens for select to authenticated using (public.ff_minha_loja(loja_id) or public.ff_is_admin());
revoke all on public.ff_mesas, public.ff_comandas, public.ff_comanda_itens from anon, authenticated;
grant select on public.ff_mesas, public.ff_comandas, public.ff_comanda_itens to authenticated;
grant all on public.ff_mesas, public.ff_comandas, public.ff_comanda_itens to service_role;

-- =====================================================================
-- 3) Regras internas
-- =====================================================================
-- Total de uma comanda (só itens ativos)
create or replace function public.ff_comanda_total(p_comanda uuid)
returns numeric language sql stable security definer set search_path = public as $$
  select coalesce(round(sum(preco * qtd), 2), 0) from public.ff_comanda_itens where comanda_id = p_comanda and status = 'ativo'
$$;
revoke all on function public.ff_comanda_total(uuid) from public, anon, authenticated;

-- Comanda completa (para as telas)
create or replace function public.ff_comanda_json(p_comanda uuid)
returns json language sql stable security definer set search_path = public as $$
  select json_build_object(
    'id', c.id, 'numero', c.numero, 'mesa_id', c.mesa_id, 'mesa', m.nome, 'identificador', c.identificador, 'status', c.status,
    'pessoas', c.pessoas, 'obs', c.obs, 'aberta_em', c.aberta_em, 'aberta_por_nome', c.aberta_por_nome, 'conta_em', c.conta_em,
    'total', public.ff_comanda_total(c.id), 'taxa_servico', l.taxa_servico,
    'itens', coalesce((select json_agg(json_build_object('id', i.id, 'nome', i.nome, 'preco', i.preco, 'qtd', i.qtd, 'peso_g', i.peso_g,
                'opcoes', i.opcoes, 'obs', i.obs, 'status', i.status, 'cozinha', i.cozinha, 'lancado_por_nome', i.lancado_por_nome,
                'lancado_por', i.lancado_por, 'criado_em', i.criado_em, 'cancelado_por_nome', i.cancelado_por_nome, 'cancel_motivo', i.cancel_motivo)
              order by i.criado_em, i.id) from public.ff_comanda_itens i where i.comanda_id = c.id), '[]'::json))
  from public.ff_comandas c join public.ff_lojas l on l.id = c.loja_id left join public.ff_mesas m on m.id = c.mesa_id
  where c.id = p_comanda
$$;
revoke all on function public.ff_comanda_json(uuid) from public, anon, authenticated;

-- Pagamentos: confere e calcula o troco (mesma regra do balcão)
create or replace function public.ff_pdv_pagamentos(p_pagamentos jsonb, p_total numeric)
returns jsonb language plpgsql immutable as $$
declare pg jsonb; v_pags jsonb := '[]'::jsonb; v_soma numeric := 0; v_din numeric := 0; v_outros numeric := 0; v numeric;
begin
  if jsonb_typeof(coalesce(p_pagamentos, '[]'::jsonb)) <> 'array' or jsonb_array_length(coalesce(p_pagamentos, '[]'::jsonb)) > 6 then raise exception 'pagamento_invalido'; end if;
  for pg in select * from jsonb_array_elements(coalesce(p_pagamentos, '[]'::jsonb)) loop
    if coalesce(pg ->> 'forma', '') not in ('dinheiro', 'pix', 'credito', 'debito', 'outro')
       or coalesce((pg ->> 'valor')::numeric, 0) <= 0 or (pg ->> 'valor')::numeric > 1000000 then raise exception 'pagamento_invalido'; end if;
    v := round((pg ->> 'valor')::numeric, 2);
    v_pags := v_pags || jsonb_build_array(jsonb_build_object('forma', pg ->> 'forma', 'valor', v));
    v_soma := v_soma + v;
    if pg ->> 'forma' = 'dinheiro' then v_din := v_din + v; else v_outros := v_outros + v; end if;
  end loop;
  if v_soma < p_total then raise exception 'pagamento_menor'; end if;
  if v_outros > p_total then raise exception 'pagamento_maior'; end if;
  if v_soma - p_total > v_din then raise exception 'pagamento_maior'; end if;
  return jsonb_build_object('pagamentos', v_pags, 'troco', v_soma - p_total);
end $$;
revoke all on function public.ff_pdv_pagamentos(jsonb, numeric) from public, anon, authenticated;

-- Devolve ao estoque um item da comanda
create or replace function public.ff_comanda_item_devolver(p_item uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
declare i public.ff_comanda_itens;
begin
  select * into i from public.ff_comanda_itens where id = p_item;
  if i.id is null or not i.estoque_baixado or i.produto_id is null then return; end if;
  if i.variacao_id is not null then
    update public.ff_produtos
       set variacoes = (select jsonb_agg(case when x ->> 'id' = i.variacao_id and nullif(x ->> 'estoque', '') is not null
                                              then jsonb_set(x, '{estoque}', to_jsonb((x ->> 'estoque')::int + i.qtd)) else x end order by ord)
                          from jsonb_array_elements(variacoes) with ordinality t(x, ord))
     where id = i.produto_id and jsonb_array_length(coalesce(variacoes, '[]'::jsonb)) > 0;
  else
    update public.ff_produtos set estoque = estoque + i.qtd where id = i.produto_id and estoque is not null;
  end if;
end $$;
revoke all on function public.ff_comanda_item_devolver(uuid) from public, anon, authenticated;

-- Confere a comanda e o acesso de quem chamou
create or replace function public.ff_comanda_acesso(p_comanda uuid, p_papeis text[])
returns public.ff_comandas language plpgsql volatile security definer set search_path = public as $$
declare c public.ff_comandas; l public.ff_lojas;
begin
  select * into c from public.ff_comandas where id = p_comanda for update;
  if c.id is null then raise exception 'comanda_nao_encontrada'; end if;
  l := public.ff_pdv_loja(c.loja_id, p_papeis);
  return c;
end $$;
revoke all on function public.ff_comanda_acesso(uuid, text[]) from public, anon, authenticated;

-- =====================================================================
-- 4) Funções das telas (garçom e caixa)
-- =====================================================================
-- Mapa das mesas e comandas abertas
create or replace function public.ff_mesas_estado(p_loja uuid)
returns json language plpgsql stable security definer set search_path = public as $$
declare l public.ff_lojas;
begin
  l := public.ff_pdv_loja(p_loja, array['dono', 'admin', 'caixa', 'garcom']);
  return json_build_object(
    'papel', public.ff_papel_loja(p_loja), 'usuario', public.ff_nome_usuario(), 'hoje', public.ff_hoje_sp(),
    'loja', json_build_object('id', l.id, 'nome', l.nome, 'cor', l.cor, 'imagem_url', l.imagem_url, 'endereco', l.endereco,
                              'mesas_ativo', l.mesas_ativo, 'pdv_ativo', l.pdv_ativo, 'pdv_gaveta', l.pdv_gaveta, 'taxa_servico', l.taxa_servico),
    'mesas', coalesce((select json_agg(json_build_object('id', m.id, 'nome', m.nome) order by m.ordem, m.nome)
                         from public.ff_mesas m where m.loja_id = p_loja and m.ativa), '[]'::json),
    'comandas', coalesce((select json_agg(json_build_object('id', c.id, 'numero', c.numero, 'mesa_id', c.mesa_id, 'identificador', c.identificador,
                           'status', c.status, 'pessoas', c.pessoas, 'aberta_em', c.aberta_em, 'aberta_por_nome', c.aberta_por_nome, 'conta_em', c.conta_em,
                           'total', public.ff_comanda_total(c.id),
                           'itens', (select count(*) from public.ff_comanda_itens i where i.comanda_id = c.id and i.status = 'ativo'))
                           order by c.numero)
                         from public.ff_comandas c where c.loja_id = p_loja and c.status in ('aberta', 'conta')), '[]'::json));
end $$;
revoke all on function public.ff_mesas_estado(uuid) from public, anon;
grant execute on function public.ff_mesas_estado(uuid) to authenticated;

-- Abrir mesa (ou comanda avulsa). Se a mesa já tiver comanda aberta, devolve a mesma.
create or replace function public.ff_comanda_abrir(p_loja uuid, p_mesa uuid, p_identificador text, p_pessoas int)
returns json language plpgsql volatile security definer set search_path = public as $$
declare l public.ff_lojas; c public.ff_comandas; v_num int; v_id text := left(trim(coalesce(p_identificador, '')), 40);
begin
  l := public.ff_pdv_loja(p_loja, array['dono', 'admin', 'caixa', 'garcom']);
  if not l.mesas_ativo then raise exception 'mesas_desligadas'; end if;
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

create or replace function public.ff_comanda_ver(p_comanda uuid)
returns json language plpgsql stable security definer set search_path = public as $$
declare v_loja uuid; l public.ff_lojas;
begin
  select loja_id into v_loja from public.ff_comandas where id = p_comanda;
  if v_loja is null then raise exception 'comanda_nao_encontrada'; end if;
  l := public.ff_pdv_loja(v_loja, array['dono', 'admin', 'caixa', 'garcom']);
  return public.ff_comanda_json(p_comanda);
end $$;
revoke all on function public.ff_comanda_ver(uuid) from public, anon;
grant execute on function public.ff_comanda_ver(uuid) to authenticated;

-- Lançar itens. Cada item traz "idem" (código único do celular): o que já foi lançado é ignorado.
create or replace function public.ff_comanda_lancar(p_comanda uuid, p_itens jsonb)
returns json language plpgsql volatile security definer set search_path = public as $$
declare c public.ff_comandas; it jsonb; li jsonb; v_idem uuid; n int := 0;
begin
  c := public.ff_comanda_acesso(p_comanda, array['dono', 'admin', 'caixa', 'garcom']);
  if jsonb_typeof(coalesce(p_itens, 'null'::jsonb)) <> 'array' or jsonb_array_length(p_itens) = 0 then raise exception 'carrinho_vazio'; end if;
  if jsonb_array_length(p_itens) > 100 then raise exception 'venda_grande'; end if;
  -- confere se já foi tudo lançado antes (reenvio depois de falha de internet)
  if not exists (select 1 from jsonb_array_elements(p_itens) x
                  where not exists (select 1 from public.ff_comanda_itens i where i.loja_id = c.loja_id and i.idem = (x ->> 'idem')::uuid)) then
    return public.ff_comanda_json(c.id);
  end if;
  if c.status = 'conta' then raise exception 'comanda_na_conta'; end if;
  if c.status <> 'aberta' then raise exception 'comanda_fechada'; end if;
  for it in select * from jsonb_array_elements(p_itens) loop
    v_idem := nullif(it ->> 'idem', '')::uuid;
    if v_idem is null then raise exception 'venda_invalida'; end if;
    continue when exists (select 1 from public.ff_comanda_itens where loja_id = c.loja_id and idem = v_idem);
    li := public.ff_pdv_item(c.loja_id, it);
    insert into public.ff_comanda_itens (comanda_id, loja_id, idem, produto_id, nome, preco, qtd, peso_g, opcoes, variacao_id, estoque_baixado, obs, lancado_por, lancado_por_nome)
    values (c.id, c.loja_id, v_idem, (li ->> 'produto_id')::uuid, li ->> 'nome', (li ->> 'preco')::numeric, (li ->> 'qtd')::int, (li ->> 'peso_g')::int,
            coalesce(li -> 'opcoes', '[]'::jsonb), li ->> 'variacao_id', (li ->> 'estoque_baixado')::boolean, coalesce(li ->> 'obs', ''),
            auth.uid(), public.ff_nome_usuario());
    n := n + 1;
  end loop;
  return public.ff_comanda_json(c.id);
end $$;
revoke all on function public.ff_comanda_lancar(uuid, jsonb) from public, anon;
grant execute on function public.ff_comanda_lancar(uuid, jsonb) to authenticated;

-- Cancelar um item: dono, administrador ou caixa a qualquer momento (com motivo);
-- o garçom só o item que ele mesmo lançou, até 5 minutos depois (para corrigir engano).
create or replace function public.ff_comanda_item_cancelar(p_item uuid, p_motivo text)
returns json language plpgsql volatile security definer set search_path = public as $$
declare i public.ff_comanda_itens; c public.ff_comandas; v_papel text;
begin
  select * into i from public.ff_comanda_itens where id = p_item for update;
  if i.id is null then raise exception 'item_nao_encontrado'; end if;
  c := public.ff_comanda_acesso(i.comanda_id, array['dono', 'admin', 'caixa', 'garcom']);
  if c.status not in ('aberta', 'conta') then raise exception 'comanda_fechada'; end if;
  if i.status <> 'ativo' then raise exception 'item_ja_cancelado'; end if;
  if length(trim(coalesce(p_motivo, ''))) < 3 then raise exception 'motivo_obrigatorio'; end if;
  v_papel := public.ff_papel_loja(c.loja_id);
  if v_papel = 'garcom' and (i.lancado_por is distinct from auth.uid() or i.criado_em < now() - interval '5 minutes') then
    raise exception 'cancelar_so_gerente';
  end if;
  perform public.ff_comanda_item_devolver(i.id);
  update public.ff_comanda_itens set status = 'cancelado', cancelado_em = now(), cancelado_por_nome = public.ff_nome_usuario(),
         cancel_motivo = left(trim(p_motivo), 200)
   where id = i.id;
  return public.ff_comanda_json(c.id);
end $$;
revoke all on function public.ff_comanda_item_cancelar(uuid, text) from public, anon;
grant execute on function public.ff_comanda_item_cancelar(uuid, text) to authenticated;

-- Pedir a conta (avisa o caixa) ou reabrir para lançar mais
create or replace function public.ff_comanda_conta(p_comanda uuid, p_pedir boolean)
returns json language plpgsql volatile security definer set search_path = public as $$
declare c public.ff_comandas;
begin
  c := public.ff_comanda_acesso(p_comanda, array['dono', 'admin', 'caixa', 'garcom']);
  if c.status not in ('aberta', 'conta') then raise exception 'comanda_fechada'; end if;
  if p_pedir and public.ff_comanda_total(c.id) <= 0 then raise exception 'comanda_vazia'; end if;
  update public.ff_comandas set status = case when p_pedir then 'conta' else 'aberta' end,
         conta_em = case when p_pedir then now() else null end
   where id = c.id;
  return public.ff_comanda_json(c.id);
end $$;
revoke all on function public.ff_comanda_conta(uuid, boolean) from public, anon;
grant execute on function public.ff_comanda_conta(uuid, boolean) to authenticated;

-- Pessoas na mesa e observação
create or replace function public.ff_comanda_dados(p_comanda uuid, p_pessoas int, p_obs text)
returns json language plpgsql volatile security definer set search_path = public as $$
declare c public.ff_comandas;
begin
  c := public.ff_comanda_acesso(p_comanda, array['dono', 'admin', 'caixa', 'garcom']);
  if c.status not in ('aberta', 'conta') then raise exception 'comanda_fechada'; end if;
  update public.ff_comandas set pessoas = greatest(1, least(coalesce(p_pessoas, 1), 99)), obs = left(trim(coalesce(p_obs, '')), 200) where id = c.id;
  return public.ff_comanda_json(c.id);
end $$;
revoke all on function public.ff_comanda_dados(uuid, int, text) from public, anon;
grant execute on function public.ff_comanda_dados(uuid, int, text) to authenticated;

-- Trocar de mesa: se a mesa de destino estiver livre, só muda; se estiver ocupada, junta tudo na comanda dela.
create or replace function public.ff_comanda_transferir(p_comanda uuid, p_mesa uuid)
returns json language plpgsql volatile security definer set search_path = public as $$
declare c public.ff_comandas; d public.ff_comandas;
begin
  c := public.ff_comanda_acesso(p_comanda, array['dono', 'admin', 'caixa', 'garcom']);
  if c.status not in ('aberta', 'conta') then raise exception 'comanda_fechada'; end if;
  if not exists (select 1 from public.ff_mesas where id = p_mesa and loja_id = c.loja_id and ativa) then raise exception 'mesa_invalida'; end if;
  if c.mesa_id = p_mesa then return public.ff_comanda_json(c.id); end if;
  perform pg_advisory_xact_lock(hashtext('comanda:' || c.loja_id::text));
  select * into d from public.ff_comandas where mesa_id = p_mesa and status in ('aberta', 'conta') for update;
  if d.id is null then
    update public.ff_comandas set mesa_id = p_mesa, identificador = '' where id = c.id;
    return public.ff_comanda_json(c.id);
  end if;
  update public.ff_comanda_itens set comanda_id = d.id where comanda_id = c.id;
  update public.ff_comandas set pessoas = least(99, d.pessoas + c.pessoas), status = 'aberta', conta_em = null where id = d.id;
  update public.ff_comandas set status = 'cancelada', fechada_em = now(), fechada_por_nome = public.ff_nome_usuario(),
         cancel_motivo = 'Juntada com a comanda nº ' || d.numero where id = c.id;
  return public.ff_comanda_json(d.id);
end $$;
revoke all on function public.ff_comanda_transferir(uuid, uuid) from public, anon;
grant execute on function public.ff_comanda_transferir(uuid, uuid) to authenticated;

-- Cancelar a comanda inteira (só dono ou administrador). Devolve o estoque.
create or replace function public.ff_comanda_cancelar(p_comanda uuid, p_motivo text)
returns json language plpgsql volatile security definer set search_path = public as $$
declare c public.ff_comandas; i record;
begin
  c := public.ff_comanda_acesso(p_comanda, array['dono', 'admin']);
  if c.status not in ('aberta', 'conta') then raise exception 'comanda_fechada'; end if;
  if length(trim(coalesce(p_motivo, ''))) < 3 then raise exception 'motivo_obrigatorio'; end if;
  for i in select id from public.ff_comanda_itens where comanda_id = c.id and status = 'ativo' loop
    perform public.ff_comanda_item_devolver(i.id);
  end loop;
  update public.ff_comanda_itens set status = 'cancelado', cancelado_em = now(), cancelado_por_nome = public.ff_nome_usuario(),
         cancel_motivo = 'Comanda cancelada: ' || left(trim(p_motivo), 150)
   where comanda_id = c.id and status = 'ativo';
  update public.ff_comandas set status = 'cancelada', fechada_em = now(), fechada_por_nome = public.ff_nome_usuario(),
         cancel_motivo = left(trim(p_motivo), 200) where id = c.id;
  return json_build_object('ok', true);
end $$;
revoke all on function public.ff_comanda_cancelar(uuid, text) from public, anon;
grant execute on function public.ff_comanda_cancelar(uuid, text) to authenticated;

-- Receber e fechar a comanda no caixa. p_idem: código único da tela (não registra duas vezes).
create or replace function public.ff_comanda_fechar(p_comanda uuid, p_desconto numeric, p_taxa boolean, p_pagamentos jsonb, p_idem uuid, p_cliente text default '')
returns json language plpgsql volatile security definer set search_path = public as $$
declare c public.ff_comandas; l public.ff_lojas; cx public.ff_caixas; ve public.ff_vendas; v_sub numeric; v_desc numeric; v_taxa numeric := 0;
        v_tot numeric; v_pg jsonb; v_num int;
begin
  if p_idem is null then raise exception 'venda_invalida'; end if;
  select * into c from public.ff_comandas where id = p_comanda;
  if c.id is null then raise exception 'comanda_nao_encontrada'; end if;
  l := public.ff_pdv_loja(c.loja_id, array['dono', 'admin', 'caixa']);
  -- já fechada por esta mesma tela (reenvio): devolve a venda
  select * into ve from public.ff_vendas where loja_id = c.loja_id and idem = p_idem;
  if ve.id is not null then
    return json_build_object('id', ve.id, 'numero', ve.numero, 'total', ve.total, 'troco', ve.troco, 'repetida', true);
  end if;
  if not l.pdv_ativo then raise exception 'pdv_desligado'; end if;
  perform pg_advisory_xact_lock(hashtext('caixa:' || c.loja_id::text));
  select * into c from public.ff_comandas where id = p_comanda for update;
  if c.status not in ('aberta', 'conta') then raise exception 'comanda_fechada'; end if;
  select * into cx from public.ff_caixas where loja_id = c.loja_id and status = 'aberto';
  if l.pdv_gaveta and cx.id is null then raise exception 'caixa_fechado'; end if;

  v_sub := public.ff_comanda_total(c.id);
  if v_sub <= 0 then raise exception 'comanda_vazia'; end if;
  v_desc := round(coalesce(p_desconto, 0), 2);
  if v_desc < 0 or v_desc > v_sub then raise exception 'desconto_invalido'; end if;
  if coalesce(p_taxa, false) and l.taxa_servico > 0 then v_taxa := round((v_sub - v_desc) * l.taxa_servico / 100, 2); end if;
  v_tot := v_sub - v_desc + v_taxa;
  v_pg := public.ff_pdv_pagamentos(p_pagamentos, v_tot);

  select coalesce(max(numero), 0) + 1 into v_num from public.ff_vendas where loja_id = c.loja_id;
  insert into public.ff_vendas (loja_id, numero, idem, caixa_id, origem, subtotal, desconto, taxa_servico, total, pagamentos, troco,
                                cliente, obs, usuario, usuario_nome, comanda_id)
  values (c.loja_id, v_num, p_idem, cx.id, 'mesa', v_sub, v_desc, v_taxa, v_tot, v_pg -> 'pagamentos', (v_pg ->> 'troco')::numeric,
          left(trim(coalesce(nullif(p_cliente, ''), c.identificador, '')), 80),
          coalesce((select 'Mesa ' || nome from public.ff_mesas where id = c.mesa_id), 'Comanda ' || c.numero), auth.uid(), public.ff_nome_usuario(), c.id)
  returning * into ve;
  -- os itens vão para a venda (o estoque já foi baixado no lançamento; cancelar a venda devolve)
  insert into public.ff_venda_itens (venda_id, produto_id, nome, preco, qtd, peso_g, opcoes, variacao_id, estoque_baixado, obs)
  select ve.id, produto_id, nome, preco, qtd, peso_g, opcoes, variacao_id, estoque_baixado, obs
    from public.ff_comanda_itens where comanda_id = c.id and status = 'ativo';
  update public.ff_comandas set status = 'fechada', fechada_em = now(), fechada_por_nome = public.ff_nome_usuario(), venda_id = ve.id where id = c.id;
  return json_build_object('id', ve.id, 'numero', ve.numero, 'subtotal', ve.subtotal, 'desconto', ve.desconto, 'taxa_servico', ve.taxa_servico,
    'total', ve.total, 'troco', ve.troco, 'pagamentos', ve.pagamentos, 'criado_em', ve.criado_em, 'usuario_nome', ve.usuario_nome,
    'itens', (select json_agg(json_build_object('nome', nome, 'preco', preco, 'qtd', qtd, 'opcoes', opcoes)) from public.ff_venda_itens where venda_id = ve.id),
    'repetida', false);
end $$;
revoke all on function public.ff_comanda_fechar(uuid, numeric, boolean, jsonb, uuid, text) from public, anon;
grant execute on function public.ff_comanda_fechar(uuid, numeric, boolean, jsonb, uuid, text) to authenticated;

-- Configuração das mesas (dono ou administrador)
create or replace function public.ff_mesas_config(p_loja uuid, p_ativo boolean, p_taxa numeric, p_mesas jsonb)
returns json language plpgsql volatile security definer set search_path = public as $$
declare l public.ff_lojas; m jsonb; v_ord int := 0; v_ids uuid[] := '{}'; v_id uuid;
begin
  l := public.ff_pdv_loja(p_loja, array['dono', 'admin']);
  if p_taxa is null or p_taxa < 0 or p_taxa > 30 then raise exception 'taxa_invalida'; end if;
  if not coalesce(p_ativo, false) and exists (select 1 from public.ff_comandas where loja_id = p_loja and status in ('aberta', 'conta')) then
    raise exception 'feche_as_comandas';
  end if;
  if p_mesas is not null then
    if jsonb_typeof(p_mesas) <> 'array' or jsonb_array_length(p_mesas) > 300 then raise exception 'mesas_invalidas'; end if;
    for m in select * from jsonb_array_elements(p_mesas) loop
      v_ord := v_ord + 1;
      if length(trim(coalesce(m ->> 'nome', ''))) < 1 then raise exception 'mesas_invalidas'; end if;
      v_id := nullif(m ->> 'id', '')::uuid;
      if v_id is not null and exists (select 1 from public.ff_mesas where id = v_id and loja_id = p_loja) then
        update public.ff_mesas set nome = left(trim(m ->> 'nome'), 30), ordem = v_ord, ativa = true where id = v_id;
      else
        insert into public.ff_mesas (loja_id, nome, ordem) values (p_loja, left(trim(m ->> 'nome'), 30), v_ord) returning id into v_id;
      end if;
      v_ids := v_ids || v_id;
    end loop;
    -- mesas tiradas da lista: ficam inativas (não pode tirar mesa com comanda aberta)
    if exists (select 1 from public.ff_comandas c where c.loja_id = p_loja and c.status in ('aberta', 'conta') and c.mesa_id is not null and not (c.mesa_id = any (v_ids))) then
      raise exception 'mesa_com_comanda';
    end if;
    update public.ff_mesas set ativa = false where loja_id = p_loja and not (id = any (v_ids));
  end if;
  update public.ff_lojas set mesas_ativo = coalesce(p_ativo, false), taxa_servico = round(p_taxa, 2),
         pdv_ativo = case when coalesce(p_ativo, false) then true else pdv_ativo end
   where id = p_loja;
  return json_build_object('mesas_ativo', coalesce(p_ativo, false), 'taxa_servico', round(p_taxa, 2),
    'pdv_ativo', (select pdv_ativo from public.ff_lojas where id = p_loja),
    'mesas', coalesce((select json_agg(json_build_object('id', id, 'nome', nome) order by ordem) from public.ff_mesas where loja_id = p_loja and ativa), '[]'::json));
end $$;
revoke all on function public.ff_mesas_config(uuid, boolean, numeric, jsonb) from public, anon;
grant execute on function public.ff_mesas_config(uuid, boolean, numeric, jsonb) to authenticated;

-- Não deixa desligar o caixa com mesas ligadas (as comandas fecham nele)
create or replace function public.ff_pdv_config(p_loja uuid, p_ativo boolean, p_gaveta boolean)
returns json language plpgsql volatile security definer set search_path = public as $$
declare l public.ff_lojas;
begin
  l := public.ff_pdv_loja(p_loja, array['dono', 'admin']);
  if (not coalesce(p_ativo, false) or not coalesce(p_gaveta, false))
     and exists (select 1 from public.ff_caixas where loja_id = p_loja and status = 'aberto') then
    raise exception 'feche_o_caixa';
  end if;
  if not coalesce(p_ativo, false) and l.mesas_ativo then raise exception 'desligue_as_mesas'; end if;
  update public.ff_lojas set pdv_ativo = coalesce(p_ativo, false), pdv_gaveta = coalesce(p_ativo, false) and coalesce(p_gaveta, false) where id = p_loja;
  return json_build_object('pdv_ativo', coalesce(p_ativo, false), 'pdv_gaveta', coalesce(p_ativo, false) and coalesce(p_gaveta, false));
end $$;
revoke all on function public.ff_pdv_config(uuid, boolean, boolean) from public, anon;
grant execute on function public.ff_pdv_config(uuid, boolean, boolean) to authenticated;

-- Fechar o caixa avisa se ainda tem mesa aberta (não impede: o caixa pode ter trocado de turno)
create or replace function public.ff_caixa_estado(p_loja uuid)
returns json language plpgsql stable security definer set search_path = public as $$
declare l public.ff_lojas; c public.ff_caixas;
begin
  l := public.ff_pdv_loja(p_loja, array['dono', 'admin', 'caixa']);
  select * into c from public.ff_caixas where loja_id = p_loja and status = 'aberto';
  return json_build_object(
    'papel', public.ff_papel_loja(p_loja), 'usuario', public.ff_nome_usuario(),
    'loja', json_build_object('id', l.id, 'nome', l.nome, 'slug', l.slug, 'cor', l.cor, 'imagem_url', l.imagem_url, 'tipo', l.tipo,
                              'telefone', l.telefone, 'endereco', l.endereco, 'pdv_ativo', l.pdv_ativo, 'pdv_gaveta', l.pdv_gaveta,
                              'mesas_ativo', l.mesas_ativo, 'taxa_servico', l.taxa_servico),
    'caixa', case when c.id is null then null else json_build_object(
      'id', c.id, 'numero', c.numero, 'aberto_em', c.aberto_em, 'aberto_por_nome', c.aberto_por_nome,
      'valor_inicial', c.valor_inicial, 'resumo', public.ff_caixa_resumo(c.id)) end,
    'comandas_abertas', (select count(*) from public.ff_comandas where loja_id = p_loja and status in ('aberta', 'conta')),
    'comandas_conta', (select count(*) from public.ff_comandas where loja_id = p_loja and status = 'conta'),
    'hoje', public.ff_hoje_sp());
end $$;
revoke all on function public.ff_caixa_estado(uuid) from public, anon;
grant execute on function public.ff_caixa_estado(uuid) to authenticated;

-- Lista de vendas mostra a taxa de serviço e de onde veio
create or replace function public.ff_pdv_vendas(p_loja uuid, p_caixa uuid default null)
returns json language plpgsql stable security definer set search_path = public as $$
declare l public.ff_lojas; v_hoje date := public.ff_hoje_sp();
begin
  l := public.ff_pdv_loja(p_loja, array['dono', 'admin', 'caixa']);
  return coalesce((select json_agg(x order by x.numero desc) from (
    select v.id, v.numero, v.total, v.subtotal, v.desconto, v.taxa_servico, v.troco, v.pagamentos, v.status, v.cliente, v.obs, v.origem,
           v.usuario_nome, v.criado_em, v.cancel_motivo, v.cancelada_por_nome,
           (select json_agg(json_build_object('nome', i.nome, 'preco', i.preco, 'qtd', i.qtd, 'opcoes', i.opcoes, 'obs', i.obs))
              from public.ff_venda_itens i where i.venda_id = v.id) as itens
      from public.ff_vendas v
     where v.loja_id = p_loja
       and (case when p_caixa is not null then v.caixa_id = p_caixa
                 else (v.criado_em at time zone 'America/Sao_Paulo')::date = v_hoje end)
     order by v.numero desc limit 300) x), '[]'::json);
end $$;
revoke all on function public.ff_pdv_vendas(uuid, uuid) from public, anon;
grant execute on function public.ff_pdv_vendas(uuid, uuid) to authenticated;

-- Cancelar venda de mesa: a comanda fica marcada como cancelada também (o estoque volta pela venda)
create or replace function public.ff_venda_cancelar(p_venda uuid, p_motivo text)
returns json language plpgsql volatile security definer set search_path = public as $$
declare ve public.ff_vendas; l public.ff_lojas; v_st text;
begin
  select * into ve from public.ff_vendas where id = p_venda for update;
  if ve.id is null then raise exception 'venda_nao_encontrada'; end if;
  l := public.ff_pdv_loja(ve.loja_id, array['dono', 'admin']);
  if ve.status <> 'concluida' then raise exception 'venda_ja_cancelada'; end if;
  if length(trim(coalesce(p_motivo, ''))) < 3 then raise exception 'motivo_obrigatorio'; end if;
  if ve.caixa_id is not null then
    select status into v_st from public.ff_caixas where id = ve.caixa_id;
    if v_st = 'fechado' then raise exception 'caixa_ja_fechado'; end if;
  end if;
  perform public.ff_pdv_devolver_estoque(ve.id);
  update public.ff_vendas set status = 'cancelada', cancelada_em = now(), cancelada_por_nome = public.ff_nome_usuario(),
         cancel_motivo = left(trim(p_motivo), 200)
   where id = ve.id;
  if ve.comanda_id is not null then
    update public.ff_comandas set status = 'cancelada', cancel_motivo = 'Venda nº ' || ve.numero || ' cancelada: ' || left(trim(p_motivo), 150) where id = ve.comanda_id;
  end if;
  return json_build_object('ok', true);
end $$;
revoke all on function public.ff_venda_cancelar(uuid, text) from public, anon;
grant execute on function public.ff_venda_cancelar(uuid, text) to authenticated;

-- Plano: devolve também a função (já existia no v35); nada muda aqui.

notify pgrst, 'reload schema';
