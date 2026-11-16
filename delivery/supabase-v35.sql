-- GoPedido · SQL v35 — Caixa (PDV no balcão), fluxo de caixa e funções da equipe
-- Rode depois do v34. Pode rodar mais de uma vez.
--
-- Tudo é OPCIONAL para a loja:
--   • Financeiro (caixa virtual): quanto entrou por período, juntando delivery, balcão, assinaturas e lançamentos.
--   • Vender no balcão (PDV): busca ou leitor de código de barras, desconto, várias formas de pagamento, troco.
--   • Controlar a gaveta: abrir o caixa com troco, retiradas/reforços e fechar conferindo o dinheiro.
--   • Código de barras no produto: opcional.
-- Equipe ganha FUNÇÃO: administrador (como antes) ou caixa (só o caixa, sem mexer na loja).
-- Os valores são sempre calculados aqui no banco (preço, desconto, troco, estoque): o navegador não decide nada.

-- =====================================================================
-- 1) Funções da equipe
-- =====================================================================
alter table public.ff_equipe add column if not exists funcao text not null default 'admin';
alter table public.ff_equipe drop constraint if exists ff_equipe_funcao_check;
alter table public.ff_equipe add constraint ff_equipe_funcao_check check (funcao in ('admin', 'caixa', 'garcom'));

-- Papel de quem está logado nesta loja: 'dono', 'admin', 'caixa', 'garcom' ou null (sem acesso)
create or replace function public.ff_papel_loja(p_loja uuid)
returns text language sql stable security definer set search_path = public as $$
  select case when l.dono = auth.uid() then 'dono'
              else (select e.funcao from public.ff_equipe e
                     where e.user_id = auth.uid() and e.dono = l.dono and (e.todas or l.id = any (e.lojas)) limit 1) end
    from public.ff_lojas l
   where l.id = p_loja and l.excluida_em is null
$$;
revoke all on function public.ff_papel_loja(uuid) from public, anon;
grant execute on function public.ff_papel_loja(uuid) to authenticated;

-- Gerir a loja (produtos, pedidos, configurações): só dono e administradores.
-- Quem é "caixa" (ou "garçom") usa só as funções próprias do caixa, abaixo.
create or replace function public.ff_minha_loja(p_loja uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.ff_lojas l
     where l.id = p_loja and l.excluida_em is null
       and (l.dono = auth.uid()
            or exists (select 1 from public.ff_equipe e
                        where e.user_id = auth.uid() and e.dono = l.dono and e.funcao = 'admin'
                          and (e.todas or l.id = any (e.lojas))))
  )
$$;

-- Lojas que aparecem para quem está logado (qualquer função)
create or replace function public.ff_minhas_lojas()
returns setof public.ff_lojas language sql stable security definer set search_path = public as $$
  select l.* from public.ff_lojas l where public.ff_papel_loja(l.id) is not null order by l.criado_em
$$;
revoke all on function public.ff_minhas_lojas() from public;
grant execute on function public.ff_minhas_lojas() to authenticated;

-- O dono escolhe a função de cada pessoa da equipe
create or replace function public.ff_equipe_funcao(p_id uuid, p_funcao text)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  if p_funcao not in ('admin', 'caixa') then raise exception 'funcao_invalida'; end if;
  update public.ff_equipe set funcao = p_funcao where id = p_id and dono = auth.uid();
  if not found then raise exception 'membro_invalido'; end if;
end $$;
revoke all on function public.ff_equipe_funcao(uuid, text) from public, anon;
grant execute on function public.ff_equipe_funcao(uuid, text) to authenticated;

-- Nome de quem está logado (para registrar quem fez cada coisa)
create or replace function public.ff_nome_usuario()
returns text language sql stable security definer set search_path = public as $$
  select left(coalesce(nullif((select nome from public.ff_equipe where user_id = auth.uid()), ''),
                       (select coalesce(nullif(raw_user_meta_data ->> 'nome', ''), email) from auth.users where id = auth.uid()), ''), 80)
$$;
revoke all on function public.ff_nome_usuario() from public, anon;

-- =====================================================================
-- 2) Configuração da loja e código de barras
-- =====================================================================
alter table public.ff_lojas add column if not exists pdv_ativo boolean not null default false;
alter table public.ff_lojas add column if not exists pdv_gaveta boolean not null default false;

alter table public.ff_produtos add column if not exists codigo_barras text not null default '';
alter table public.ff_produtos drop constraint if exists ff_produtos_codigo_barras_check;
alter table public.ff_produtos add constraint ff_produtos_codigo_barras_check check (length(codigo_barras) <= 40 and codigo_barras !~ '\s');
create unique index if not exists ff_produtos_codigo_barras_uni on public.ff_produtos (loja_id, codigo_barras) where codigo_barras <> '';

-- =====================================================================
-- 3) Tabelas do caixa
-- =====================================================================
create table if not exists public.ff_caixas (
  id uuid primary key default gen_random_uuid(),
  loja_id uuid not null references public.ff_lojas(id) on delete cascade,
  numero int not null,
  status text not null default 'aberto' check (status in ('aberto', 'fechado')),
  valor_inicial numeric(12,2) not null default 0 check (valor_inicial >= 0),
  aberto_por uuid, aberto_por_nome text not null default '', aberto_em timestamptz not null default now(),
  fechado_por uuid, fechado_por_nome text not null default '', fechado_em timestamptz,
  esperado jsonb not null default '{}'::jsonb,
  contado jsonb not null default '{}'::jsonb,
  diferenca numeric(12,2),
  obs text not null default ''
);
create unique index if not exists ff_caixas_um_aberto on public.ff_caixas (loja_id) where status = 'aberto';
create unique index if not exists ff_caixas_numero on public.ff_caixas (loja_id, numero);

create table if not exists public.ff_vendas (
  id uuid primary key default gen_random_uuid(),
  loja_id uuid not null references public.ff_lojas(id) on delete cascade,
  numero int not null,
  idem uuid not null,
  caixa_id uuid references public.ff_caixas(id),
  origem text not null default 'balcao' check (origem in ('balcao', 'mesa')),
  subtotal numeric(12,2) not null default 0,
  desconto numeric(12,2) not null default 0,
  total numeric(12,2) not null default 0,
  pagamentos jsonb not null default '[]'::jsonb,   -- [{forma, valor}]
  troco numeric(12,2) not null default 0,
  cliente text not null default '',
  obs text not null default '',
  status text not null default 'concluida' check (status in ('concluida', 'cancelada')),
  usuario uuid, usuario_nome text not null default '',
  criado_em timestamptz not null default now(),
  cancelada_em timestamptz, cancelada_por_nome text not null default '', cancel_motivo text not null default ''
);
create unique index if not exists ff_vendas_idem on public.ff_vendas (loja_id, idem);
create unique index if not exists ff_vendas_numero on public.ff_vendas (loja_id, numero);
create index if not exists ff_vendas_data on public.ff_vendas (loja_id, criado_em);
create index if not exists ff_vendas_caixa on public.ff_vendas (caixa_id);

create table if not exists public.ff_venda_itens (
  id uuid primary key default gen_random_uuid(),
  venda_id uuid not null references public.ff_vendas(id) on delete cascade,
  produto_id uuid references public.ff_produtos(id) on delete set null,
  nome text not null,
  preco numeric(12,2) not null,
  qtd int not null default 1,
  peso_g int,
  opcoes jsonb not null default '[]'::jsonb,
  variacao_id text,
  estoque_baixado boolean not null default false,
  obs text not null default ''
);
create index if not exists ff_venda_itens_venda on public.ff_venda_itens (venda_id);

create table if not exists public.ff_caixa_mov (
  id uuid primary key default gen_random_uuid(),
  loja_id uuid not null references public.ff_lojas(id) on delete cascade,
  caixa_id uuid references public.ff_caixas(id),
  tipo text not null check (tipo in ('sangria', 'suprimento', 'despesa', 'receita')),
  forma text not null default 'dinheiro' check (forma in ('dinheiro', 'pix', 'credito', 'debito', 'outro')),
  valor numeric(12,2) not null check (valor > 0),
  descricao text not null default '',
  categoria text not null default '',
  data date not null default ((now() at time zone 'America/Sao_Paulo')::date),
  usuario uuid, usuario_nome text not null default '',
  criado_em timestamptz not null default now(),
  cancelado_em timestamptz, cancelado_por_nome text not null default ''
);
create index if not exists ff_caixa_mov_data on public.ff_caixa_mov (loja_id, data);
create index if not exists ff_caixa_mov_caixa on public.ff_caixa_mov (caixa_id);

-- Leitura direta só para dono e administradores; gravar, só pelas funções abaixo
alter table public.ff_caixas enable row level security;
alter table public.ff_vendas enable row level security;
alter table public.ff_venda_itens enable row level security;
alter table public.ff_caixa_mov enable row level security;
drop policy if exists ff_caixas_ver on public.ff_caixas;
create policy ff_caixas_ver on public.ff_caixas for select to authenticated using (public.ff_minha_loja(loja_id) or public.ff_is_admin());
drop policy if exists ff_vendas_ver on public.ff_vendas;
create policy ff_vendas_ver on public.ff_vendas for select to authenticated using (public.ff_minha_loja(loja_id) or public.ff_is_admin());
drop policy if exists ff_venda_itens_ver on public.ff_venda_itens;
create policy ff_venda_itens_ver on public.ff_venda_itens for select to authenticated
  using (exists (select 1 from public.ff_vendas v where v.id = venda_id and (public.ff_minha_loja(v.loja_id) or public.ff_is_admin())));
drop policy if exists ff_caixa_mov_ver on public.ff_caixa_mov;
create policy ff_caixa_mov_ver on public.ff_caixa_mov for select to authenticated using (public.ff_minha_loja(loja_id) or public.ff_is_admin());
revoke all on public.ff_caixas, public.ff_vendas, public.ff_venda_itens, public.ff_caixa_mov from anon, authenticated;
grant select on public.ff_caixas, public.ff_vendas, public.ff_venda_itens, public.ff_caixa_mov to authenticated;
grant all on public.ff_caixas, public.ff_vendas, public.ff_venda_itens, public.ff_caixa_mov to service_role;

-- =====================================================================
-- 4) Regras internas
-- =====================================================================
-- Confere se quem chamou pode usar o caixa desta loja e devolve a loja
create or replace function public.ff_pdv_loja(p_loja uuid, p_papeis text[])
returns public.ff_lojas language plpgsql stable security definer set search_path = public as $$
declare l public.ff_lojas; v_papel text;
begin
  select * into l from public.ff_lojas where id = p_loja and excluida_em is null;
  if l.id is null then raise exception 'loja_nao_encontrada'; end if;
  v_papel := public.ff_papel_loja(p_loja);
  if v_papel is null or not (v_papel = any (p_papeis)) then raise exception 'sem_permissao'; end if;
  return l;
end $$;
revoke all on function public.ff_pdv_loja(uuid, text[]) from public, anon, authenticated;

-- Resumo de um caixa: o que deveria ter em cada forma de pagamento
create or replace function public.ff_caixa_resumo(p_caixa uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  with c as (select * from public.ff_caixas where id = p_caixa),
  v as (select * from public.ff_vendas where caixa_id = p_caixa and status = 'concluida'),
  pg as (select p ->> 'forma' as forma, sum((p ->> 'valor')::numeric) as valor
           from v, jsonb_array_elements(v.pagamentos) p group by 1),
  m as (select tipo, sum(valor) as valor from public.ff_caixa_mov where caixa_id = p_caixa and cancelado_em is null group by 1)
  select jsonb_build_object(
    'inicial', c.valor_inicial,
    'vendas_qtd', (select count(*) from v),
    'vendas_total', coalesce((select sum(total) from v), 0),
    'canceladas', (select count(*) from public.ff_vendas where caixa_id = p_caixa and status = 'cancelada'),
    'troco', coalesce((select sum(troco) from v), 0),
    'suprimentos', coalesce((select valor from m where tipo = 'suprimento'), 0),
    'sangrias', coalesce((select valor from m where tipo = 'sangria'), 0),
    'pix', coalesce((select valor from pg where forma = 'pix'), 0),
    'credito', coalesce((select valor from pg where forma = 'credito'), 0),
    'debito', coalesce((select valor from pg where forma = 'debito'), 0),
    'outro', coalesce((select valor from pg where forma = 'outro'), 0),
    'dinheiro_vendas', coalesce((select valor from pg where forma = 'dinheiro'), 0) - coalesce((select sum(troco) from v), 0),
    'dinheiro', c.valor_inicial
               + coalesce((select valor from pg where forma = 'dinheiro'), 0) - coalesce((select sum(troco) from v), 0)
               + coalesce((select valor from m where tipo = 'suprimento'), 0)
               - coalesce((select valor from m where tipo = 'sangria'), 0))
  from c
$$;
revoke all on function public.ff_caixa_resumo(uuid) from public, anon, authenticated;

-- Calcula e valida uma linha da venda (mesmas regras do pedido online) e baixa o estoque
create or replace function public.ff_pdv_item(p_loja uuid, it jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare
  pr public.ff_produtos; v_var jsonb := null; v_baixa boolean := false; v_nome text; v_g int := null; q int;
  v_grupos jsonb; gr jsonb; op jsonb; sel jsonb; cnt int; v_unit numeric; v_base numeric; v_snap jsonb := '[]'::jsonb;
begin
  select * into pr from public.ff_produtos where id = (it ->> 'id')::uuid and loja_id = p_loja and disponivel for update;
  if not found then raise exception 'produto_indisponivel'; end if;
  if coalesce(pr.entrega_codigo, false) then raise exception 'produto_codigo_digital'; end if;
  v_nome := pr.nome;
  if coalesce(pr.vende_por, 'un') = 'kg' then
    -- no balcão vale o peso da balança, em gramas (sem mínimo nem passo)
    v_g := coalesce((it ->> 'g')::int, 0);
    if v_g < 1 or v_g > 100000 then raise exception 'peso_invalido'; end if;
    q := 1;
    v_nome := pr.nome || ' (' || case when v_g >= 1000 then replace(trim(to_char(v_g / 1000.0, 'FM999990.999')), '.', ',') || ' kg' else v_g || ' g' end || ')';
  else
    q := coalesce((it ->> 'qtd')::int, 0);
    if q < 1 or q > 999 then raise exception 'quantidade_invalida'; end if;
    if jsonb_array_length(coalesce(pr.variacoes, '[]'::jsonb)) > 0 then
      select v into v_var from jsonb_array_elements(pr.variacoes) v where v ->> 'id' = it ->> 'v' limit 1;
      if v_var is null then raise exception 'escolha_variacao'; end if;
      v_nome := pr.nome || ' (' || (v_var ->> 'nome') || ')';
      if nullif(v_var ->> 'estoque', '') is not null then
        if (v_var ->> 'estoque')::int < q then raise exception 'sem_estoque'; end if;
        update public.ff_produtos
           set variacoes = (select jsonb_agg(case when x ->> 'id' = v_var ->> 'id'
                                                  then jsonb_set(x, '{estoque}', to_jsonb((x ->> 'estoque')::int - q)) else x end order by ord)
                              from jsonb_array_elements(variacoes) with ordinality t(x, ord))
         where id = pr.id;
        v_baixa := true;
      end if;
    elsif pr.estoque is not null then
      if pr.estoque < q then raise exception 'sem_estoque'; end if;
      update public.ff_produtos set estoque = estoque - q where id = pr.id;
      v_baixa := true;
    end if;
  end if;

  v_grupos := coalesce(pr.grupos, '[]'::jsonb) || coalesce((
    select jsonb_agg(jsonb_build_object('id', 'e:' || e.id, 'nome', e.nome, 'min', e.min, 'max', e.max, 'opcoes', e.opcoes)
                     order by array_position(pr.etapas_ids, e.id))
      from public.ff_etapas e where e.loja_id = p_loja and e.id = any (coalesce(pr.etapas_ids, '{}'::uuid[]))), '[]'::jsonb);
  for gr in select * from jsonb_array_elements(v_grupos) loop
    select count(*) into cnt from jsonb_array_elements(coalesce(it -> 'opcoes', '[]'::jsonb)) s where s ->> 'g' = gr ->> 'id';
    if cnt < coalesce((gr ->> 'min')::int, 0) or cnt > coalesce((gr ->> 'max')::int, 99) then raise exception 'opcoes_invalidas'; end if;
  end loop;
  if (select count(*) from jsonb_array_elements(coalesce(it -> 'opcoes', '[]'::jsonb)))
     <> (select count(distinct (s ->> 'g') || ':' || (s ->> 'o')) from jsonb_array_elements(coalesce(it -> 'opcoes', '[]'::jsonb)) s) then
    raise exception 'opcoes_invalidas';
  end if;

  v_unit := case when v_var is not null and nullif(v_var ->> 'preco', '') is not null then (v_var ->> 'preco')::numeric
                 else public.ff_preco_atual(pr.preco, pr.preco_promo, pr.promo_ate) end;
  v_base := v_unit;
  for sel in select * from jsonb_array_elements(coalesce(it -> 'opcoes', '[]'::jsonb)) loop
    gr := null; op := null;
    select g, o into gr, op from jsonb_array_elements(v_grupos) g, jsonb_array_elements(coalesce(g -> 'opcoes', '[]'::jsonb)) o
     where g ->> 'id' = sel ->> 'g' and o ->> 'id' = sel ->> 'o' limit 1;
    if gr is null or op is null then raise exception 'opcoes_invalidas'; end if;
    v_unit := v_unit + coalesce((op ->> 'preco')::numeric, 0);
    v_snap := v_snap || jsonb_build_array(jsonb_build_object('grupo', gr ->> 'nome', 'nome', op ->> 'nome', 'preco', coalesce((op ->> 'preco')::numeric, 0)));
  end loop;
  if v_g is not null then v_unit := round(v_base * v_g / 1000.0, 2) + (v_unit - v_base); end if;

  return jsonb_build_object('produto_id', pr.id, 'nome', left(v_nome, 120), 'preco', round(v_unit, 2), 'qtd', q, 'peso_g', v_g,
    'opcoes', v_snap, 'variacao_id', v_var ->> 'id', 'estoque_baixado', v_baixa, 'obs', left(trim(coalesce(it ->> 'obs', '')), 200));
end $$;
revoke all on function public.ff_pdv_item(uuid, jsonb) from public, anon, authenticated;

-- Devolve ao estoque o que uma venda baixou
create or replace function public.ff_pdv_devolver_estoque(p_venda uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
declare i record;
begin
  for i in select * from public.ff_venda_itens where venda_id = p_venda and estoque_baixado and produto_id is not null loop
    if i.variacao_id is not null then
      update public.ff_produtos
         set variacoes = (select jsonb_agg(case when x ->> 'id' = i.variacao_id and nullif(x ->> 'estoque', '') is not null
                                                then jsonb_set(x, '{estoque}', to_jsonb((x ->> 'estoque')::int + i.qtd)) else x end order by ord)
                            from jsonb_array_elements(variacoes) with ordinality t(x, ord))
       where id = i.produto_id and jsonb_array_length(coalesce(variacoes, '[]'::jsonb)) > 0;
    else
      update public.ff_produtos set estoque = estoque + i.qtd where id = i.produto_id and estoque is not null;
    end if;
  end loop;
end $$;
revoke all on function public.ff_pdv_devolver_estoque(uuid) from public, anon, authenticated;

-- =====================================================================
-- 5) Funções usadas pela tela do caixa
-- =====================================================================
-- Estado do caixa: configuração, caixa aberto (com o resumo) e vendas recentes
create or replace function public.ff_caixa_estado(p_loja uuid)
returns json language plpgsql stable security definer set search_path = public as $$
declare l public.ff_lojas; c public.ff_caixas;
begin
  l := public.ff_pdv_loja(p_loja, array['dono', 'admin', 'caixa']);
  select * into c from public.ff_caixas where loja_id = p_loja and status = 'aberto';
  return json_build_object(
    'papel', public.ff_papel_loja(p_loja), 'usuario', public.ff_nome_usuario(),
    'loja', json_build_object('id', l.id, 'nome', l.nome, 'slug', l.slug, 'cor', l.cor, 'imagem_url', l.imagem_url, 'tipo', l.tipo,
                              'telefone', l.telefone, 'endereco', l.endereco, 'pdv_ativo', l.pdv_ativo, 'pdv_gaveta', l.pdv_gaveta),
    'caixa', case when c.id is null then null else json_build_object(
      'id', c.id, 'numero', c.numero, 'aberto_em', c.aberto_em, 'aberto_por_nome', c.aberto_por_nome,
      'valor_inicial', c.valor_inicial, 'resumo', public.ff_caixa_resumo(c.id)) end,
    'hoje', public.ff_hoje_sp());
end $$;
revoke all on function public.ff_caixa_estado(uuid) from public, anon;
grant execute on function public.ff_caixa_estado(uuid) to authenticated;

-- Produtos para vender no balcão (só os ativos)
create or replace function public.ff_pdv_catalogo(p_loja uuid)
returns json language plpgsql stable security definer set search_path = public as $$
declare l public.ff_lojas;
begin
  l := public.ff_pdv_loja(p_loja, array['dono', 'admin', 'caixa', 'garcom']);
  return coalesce((select json_agg(json_build_object(
      'id', p.id, 'nome', p.nome, 'categoria', p.categoria, 'imagem_url', p.imagem_url,
      'preco', public.ff_preco_atual(p.preco, p.preco_promo, p.promo_ate), 'preco_cheio', p.preco,
      'codigo_barras', p.codigo_barras, 'vende_por', coalesce(p.vende_por, 'un'), 'estoque', p.estoque, 'variacoes', p.variacoes,
      'entrega_codigo', coalesce(p.entrega_codigo, false),
      'grupos', coalesce(p.grupos, '[]'::jsonb) || coalesce((
        select jsonb_agg(jsonb_build_object('id', 'e:' || e.id, 'nome', e.nome, 'min', e.min, 'max', e.max, 'opcoes', e.opcoes)
                         order by array_position(p.etapas_ids, e.id))
          from public.ff_etapas e where e.loja_id = p.loja_id and e.id = any (coalesce(p.etapas_ids, '{}'::uuid[]))), '[]'::jsonb))
      order by p.categoria, p.ordem, p.nome)
    from public.ff_produtos p where p.loja_id = p_loja and p.disponivel), '[]'::json);
end $$;
revoke all on function public.ff_pdv_catalogo(uuid) from public, anon;
grant execute on function public.ff_pdv_catalogo(uuid) to authenticated;

-- Abrir o caixa (com o dinheiro que ficou na gaveta para troco)
create or replace function public.ff_caixa_abrir(p_loja uuid, p_valor numeric)
returns json language plpgsql volatile security definer set search_path = public as $$
declare l public.ff_lojas; v_num int; c public.ff_caixas;
begin
  l := public.ff_pdv_loja(p_loja, array['dono', 'admin', 'caixa']);
  if not l.pdv_ativo then raise exception 'pdv_desligado'; end if;
  if not l.pdv_gaveta then raise exception 'gaveta_desligada'; end if;
  if p_valor is null or p_valor < 0 or p_valor > 1000000 then raise exception 'valor_invalido'; end if;
  perform pg_advisory_xact_lock(hashtext('caixa:' || p_loja::text));
  if exists (select 1 from public.ff_caixas where loja_id = p_loja and status = 'aberto') then raise exception 'caixa_ja_aberto'; end if;
  select coalesce(max(numero), 0) + 1 into v_num from public.ff_caixas where loja_id = p_loja;
  insert into public.ff_caixas (loja_id, numero, valor_inicial, aberto_por, aberto_por_nome)
  values (p_loja, v_num, round(p_valor, 2), auth.uid(), public.ff_nome_usuario()) returning * into c;
  return json_build_object('id', c.id, 'numero', c.numero);
end $$;
revoke all on function public.ff_caixa_abrir(uuid, numeric) from public, anon;
grant execute on function public.ff_caixa_abrir(uuid, numeric) to authenticated;

-- Retirada (sangria) ou reforço (suprimento) de dinheiro da gaveta
create or replace function public.ff_caixa_movimentar(p_loja uuid, p_tipo text, p_valor numeric, p_desc text)
returns json language plpgsql volatile security definer set search_path = public as $$
declare l public.ff_lojas; c public.ff_caixas;
begin
  l := public.ff_pdv_loja(p_loja, array['dono', 'admin', 'caixa']);
  if p_tipo not in ('sangria', 'suprimento') then raise exception 'tipo_invalido'; end if;
  if p_valor is null or p_valor <= 0 or p_valor > 1000000 then raise exception 'valor_invalido'; end if;
  perform pg_advisory_xact_lock(hashtext('caixa:' || p_loja::text));
  select * into c from public.ff_caixas where loja_id = p_loja and status = 'aberto';
  if c.id is null then raise exception 'caixa_fechado'; end if;
  if p_tipo = 'sangria' and round(p_valor, 2) > (public.ff_caixa_resumo(c.id) ->> 'dinheiro')::numeric then raise exception 'sangria_maior'; end if;
  insert into public.ff_caixa_mov (loja_id, caixa_id, tipo, forma, valor, descricao, usuario, usuario_nome)
  values (p_loja, c.id, p_tipo, 'dinheiro', round(p_valor, 2), left(trim(coalesce(p_desc, '')), 200), auth.uid(), public.ff_nome_usuario());
  return json_build_object('resumo', public.ff_caixa_resumo(c.id));
end $$;
revoke all on function public.ff_caixa_movimentar(uuid, text, numeric, text) from public, anon;
grant execute on function public.ff_caixa_movimentar(uuid, text, numeric, text) to authenticated;

-- Registrar uma venda no balcão. p_idem é um código único gerado na tela: se a internet falhar e a tela
-- mandar de novo, a venda NÃO é registrada duas vezes (devolve a mesma).
create or replace function public.ff_pdv_vender(p_loja uuid, p_itens jsonb, p_desconto numeric, p_pagamentos jsonb,
                                                p_cliente text, p_idem uuid, p_obs text default '')
returns json language plpgsql volatile security definer set search_path = public as $$
declare
  l public.ff_lojas; c public.ff_caixas; ve public.ff_vendas; it jsonb; li jsonb; v_linhas jsonb := '[]'::jsonb;
  v_sub numeric := 0; v_desc numeric; v_tot numeric; pg jsonb; v_pags jsonb := '[]'::jsonb; v_soma numeric := 0; v_din numeric := 0;
  v_outros numeric := 0; v_troco numeric := 0; v_num int; n int := 0;
begin
  l := public.ff_pdv_loja(p_loja, array['dono', 'admin', 'caixa']);
  if not l.pdv_ativo then raise exception 'pdv_desligado'; end if;
  if p_idem is null then raise exception 'venda_invalida'; end if;
  select * into ve from public.ff_vendas where loja_id = p_loja and idem = p_idem;
  if ve.id is not null then
    return json_build_object('id', ve.id, 'numero', ve.numero, 'total', ve.total, 'troco', ve.troco, 'repetida', true);
  end if;
  perform pg_advisory_xact_lock(hashtext('caixa:' || p_loja::text));
  select * into ve from public.ff_vendas where loja_id = p_loja and idem = p_idem;   -- confere de novo já com a trava
  if ve.id is not null then
    return json_build_object('id', ve.id, 'numero', ve.numero, 'total', ve.total, 'troco', ve.troco, 'repetida', true);
  end if;
  select * into c from public.ff_caixas where loja_id = p_loja and status = 'aberto';
  if l.pdv_gaveta and c.id is null then raise exception 'caixa_fechado'; end if;

  if jsonb_typeof(coalesce(p_itens, 'null'::jsonb)) <> 'array' or jsonb_array_length(p_itens) = 0 then raise exception 'carrinho_vazio'; end if;
  if jsonb_array_length(p_itens) > 300 then raise exception 'venda_grande'; end if;
  for it in select * from jsonb_array_elements(p_itens) loop
    li := public.ff_pdv_item(p_loja, it);
    v_linhas := v_linhas || jsonb_build_array(li);
    v_sub := v_sub + (li ->> 'preco')::numeric * (li ->> 'qtd')::int;
    n := n + 1;
  end loop;
  v_sub := round(v_sub, 2);
  v_desc := round(coalesce(p_desconto, 0), 2);
  if v_desc < 0 or v_desc > v_sub then raise exception 'desconto_invalido'; end if;
  v_tot := v_sub - v_desc;

  -- pagamentos: cartão/Pix/outro não podem passar do total; troco só sai do dinheiro
  if jsonb_typeof(coalesce(p_pagamentos, '[]'::jsonb)) <> 'array' or jsonb_array_length(coalesce(p_pagamentos, '[]'::jsonb)) > 6 then raise exception 'pagamento_invalido'; end if;
  for pg in select * from jsonb_array_elements(coalesce(p_pagamentos, '[]'::jsonb)) loop
    if coalesce(pg ->> 'forma', '') not in ('dinheiro', 'pix', 'credito', 'debito', 'outro')
       or coalesce((pg ->> 'valor')::numeric, 0) <= 0 or (pg ->> 'valor')::numeric > 1000000 then
      raise exception 'pagamento_invalido';
    end if;
    v_pags := v_pags || jsonb_build_array(jsonb_build_object('forma', pg ->> 'forma', 'valor', round((pg ->> 'valor')::numeric, 2)));
    v_soma := v_soma + round((pg ->> 'valor')::numeric, 2);
    if pg ->> 'forma' = 'dinheiro' then v_din := v_din + round((pg ->> 'valor')::numeric, 2); else v_outros := v_outros + round((pg ->> 'valor')::numeric, 2); end if;
  end loop;
  if v_soma < v_tot then raise exception 'pagamento_menor'; end if;
  if v_outros > v_tot then raise exception 'pagamento_maior'; end if;
  v_troco := v_soma - v_tot;
  if v_troco > v_din then raise exception 'pagamento_maior'; end if;

  select coalesce(max(numero), 0) + 1 into v_num from public.ff_vendas where loja_id = p_loja;
  insert into public.ff_vendas (loja_id, numero, idem, caixa_id, subtotal, desconto, total, pagamentos, troco, cliente, obs, usuario, usuario_nome)
  values (p_loja, v_num, p_idem, c.id, v_sub, v_desc, v_tot, v_pags, v_troco, left(trim(coalesce(p_cliente, '')), 80),
          left(trim(coalesce(p_obs, '')), 300), auth.uid(), public.ff_nome_usuario())
  returning * into ve;
  insert into public.ff_venda_itens (venda_id, produto_id, nome, preco, qtd, peso_g, opcoes, variacao_id, estoque_baixado, obs)
  select ve.id, (x ->> 'produto_id')::uuid, x ->> 'nome', (x ->> 'preco')::numeric, (x ->> 'qtd')::int, (x ->> 'peso_g')::int,
         coalesce(x -> 'opcoes', '[]'::jsonb), x ->> 'variacao_id', (x ->> 'estoque_baixado')::boolean, coalesce(x ->> 'obs', '')
    from jsonb_array_elements(v_linhas) x;
  return json_build_object('id', ve.id, 'numero', ve.numero, 'subtotal', ve.subtotal, 'desconto', ve.desconto, 'total', ve.total,
                           'troco', ve.troco, 'pagamentos', ve.pagamentos, 'itens', v_linhas, 'criado_em', ve.criado_em,
                           'usuario_nome', ve.usuario_nome, 'repetida', false);
end $$;
revoke all on function public.ff_pdv_vender(uuid, jsonb, numeric, jsonb, text, uuid, text) from public, anon;
grant execute on function public.ff_pdv_vender(uuid, jsonb, numeric, jsonb, text, uuid, text) to authenticated;

-- Cancelar uma venda (só dono ou administrador, com motivo). Devolve o estoque.
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
  return json_build_object('ok', true);
end $$;
revoke all on function public.ff_venda_cancelar(uuid, text) from public, anon;
grant execute on function public.ff_venda_cancelar(uuid, text) to authenticated;

-- Vendas para a lista da tela: do caixa aberto (ou do dia, sem gaveta). Quem é "caixa" vê só isso.
create or replace function public.ff_pdv_vendas(p_loja uuid, p_caixa uuid default null)
returns json language plpgsql stable security definer set search_path = public as $$
declare l public.ff_lojas; v_hoje date := public.ff_hoje_sp();
begin
  l := public.ff_pdv_loja(p_loja, array['dono', 'admin', 'caixa']);
  return coalesce((select json_agg(x order by x.numero desc) from (
    select v.id, v.numero, v.total, v.subtotal, v.desconto, v.troco, v.pagamentos, v.status, v.cliente, v.usuario_nome, v.criado_em,
           v.cancel_motivo, v.cancelada_por_nome,
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

-- Fechar o caixa: quem fecha conta o dinheiro (e, se quiser, confere cartão e Pix com a maquininha)
create or replace function public.ff_caixa_fechar(p_loja uuid, p_contado jsonb, p_obs text)
returns json language plpgsql volatile security definer set search_path = public as $$
declare l public.ff_lojas; c public.ff_caixas; v_res jsonb; v_cont jsonb := '{}'::jsonb; k text; v_dif numeric;
begin
  l := public.ff_pdv_loja(p_loja, array['dono', 'admin', 'caixa']);
  perform pg_advisory_xact_lock(hashtext('caixa:' || p_loja::text));
  select * into c from public.ff_caixas where loja_id = p_loja and status = 'aberto' for update;
  if c.id is null then raise exception 'caixa_fechado'; end if;
  if p_contado is null or nullif(p_contado ->> 'dinheiro', '') is null then raise exception 'conte_o_dinheiro'; end if;
  foreach k in array array['dinheiro', 'pix', 'credito', 'debito', 'outro'] loop
    if nullif(p_contado ->> k, '') is not null then
      if (p_contado ->> k)::numeric < 0 or (p_contado ->> k)::numeric > 10000000 then raise exception 'valor_invalido'; end if;
      v_cont := v_cont || jsonb_build_object(k, round((p_contado ->> k)::numeric, 2));
    end if;
  end loop;
  v_res := public.ff_caixa_resumo(c.id);
  v_dif := (v_cont ->> 'dinheiro')::numeric - (v_res ->> 'dinheiro')::numeric;
  update public.ff_caixas set status = 'fechado', fechado_em = now(), fechado_por = auth.uid(), fechado_por_nome = public.ff_nome_usuario(),
         esperado = v_res, contado = v_cont, diferenca = v_dif, obs = left(trim(coalesce(p_obs, '')), 300)
   where id = c.id;
  return json_build_object('numero', c.numero, 'esperado', v_res, 'contado', v_cont, 'diferenca', v_dif);
end $$;
revoke all on function public.ff_caixa_fechar(uuid, jsonb, text) from public, anon;
grant execute on function public.ff_caixa_fechar(uuid, jsonb, text) to authenticated;

-- =====================================================================
-- 6) Financeiro (caixa virtual) — só dono e administradores
-- =====================================================================
create or replace function public.ff_lancar(p_loja uuid, p_tipo text, p_valor numeric, p_desc text, p_categoria text, p_forma text, p_data date)
returns json language plpgsql volatile security definer set search_path = public as $$
declare l public.ff_lojas; m public.ff_caixa_mov;
begin
  l := public.ff_pdv_loja(p_loja, array['dono', 'admin']);
  if p_tipo not in ('despesa', 'receita') then raise exception 'tipo_invalido'; end if;
  if p_valor is null or p_valor <= 0 or p_valor > 10000000 then raise exception 'valor_invalido'; end if;
  if coalesce(p_forma, 'dinheiro') not in ('dinheiro', 'pix', 'credito', 'debito', 'outro') then raise exception 'pagamento_invalido'; end if;
  if length(trim(coalesce(p_desc, ''))) < 2 then raise exception 'descricao_obrigatoria'; end if;
  if p_data is null or p_data < public.ff_hoje_sp() - 3660 or p_data > public.ff_hoje_sp() + 366 then raise exception 'data_invalida'; end if;
  insert into public.ff_caixa_mov (loja_id, tipo, forma, valor, descricao, categoria, data, usuario, usuario_nome)
  values (p_loja, p_tipo, coalesce(p_forma, 'dinheiro'), round(p_valor, 2), left(trim(p_desc), 200), left(trim(coalesce(p_categoria, '')), 40),
          p_data, auth.uid(), public.ff_nome_usuario())
  returning * into m;
  return json_build_object('id', m.id);
end $$;
revoke all on function public.ff_lancar(uuid, text, numeric, text, text, text, date) from public, anon;
grant execute on function public.ff_lancar(uuid, text, numeric, text, text, text, date) to authenticated;

create or replace function public.ff_lanc_cancelar(p_id uuid)
returns json language plpgsql volatile security definer set search_path = public as $$
declare m public.ff_caixa_mov; l public.ff_lojas;
begin
  select * into m from public.ff_caixa_mov where id = p_id for update;
  if m.id is null or m.tipo not in ('despesa', 'receita') then raise exception 'lancamento_invalido'; end if;
  l := public.ff_pdv_loja(m.loja_id, array['dono', 'admin']);
  if m.cancelado_em is not null then raise exception 'lancamento_invalido'; end if;
  update public.ff_caixa_mov set cancelado_em = now(), cancelado_por_nome = public.ff_nome_usuario() where id = p_id;
  return json_build_object('ok', true);
end $$;
revoke all on function public.ff_lanc_cancelar(uuid) from public, anon;
grant execute on function public.ff_lanc_cancelar(uuid) to authenticated;

-- Tudo o que entrou e saiu no período (datas no horário de Brasília)
create or replace function public.ff_financeiro(p_loja uuid, p_de date, p_ate date)
returns json language plpgsql stable security definer set search_path = public as $$
declare l public.ff_lojas; v_ass json := null; v_ass_dia json := '[]'::json;
begin
  l := public.ff_pdv_loja(p_loja, array['dono', 'admin']);
  if p_de is null or p_ate is null or p_ate < p_de or p_ate - p_de > 400 then raise exception 'periodo_longo'; end if;
  begin
    select json_build_object('qtd', count(*), 'total', coalesce(sum(valor), 0)) into v_ass
      from public.ff_assin_pagamentos where loja_id = p_loja and status = 'aprovado'
       and (coalesce(pago_em, criado_em) at time zone 'America/Sao_Paulo')::date between p_de and p_ate;
    select coalesce(json_agg(json_build_object('dia', d, 'total', t) order by d), '[]'::json) into v_ass_dia from (
      select (coalesce(pago_em, criado_em) at time zone 'America/Sao_Paulo')::date d, sum(valor) t
        from public.ff_assin_pagamentos where loja_id = p_loja and status = 'aprovado'
         and (coalesce(pago_em, criado_em) at time zone 'America/Sao_Paulo')::date between p_de and p_ate group by 1) s;
  exception when undefined_table then v_ass := null;
  end;
  return json_build_object(
    'de', p_de, 'ate', p_ate,
    'delivery', (select json_build_object('qtd', count(*), 'total', coalesce(sum(total), 0), 'taxas', coalesce(sum(taxa_entrega), 0),
                        'descontos', coalesce(sum(desconto), 0),
                        'formas', json_build_object('pix', coalesce(sum(total) filter (where pagamento = 'pix'), 0),
                                                    'mp', coalesce(sum(total) filter (where pagamento = 'mp'), 0),
                                                    'credito', coalesce(sum(total) filter (where pagamento = 'credito'), 0),
                                                    'debito', coalesce(sum(total) filter (where pagamento = 'debito'), 0),
                                                    'dinheiro', coalesce(sum(total) filter (where pagamento = 'dinheiro'), 0)))
                   from public.ff_pedidos where loja_id = p_loja and status = 'entregue'
                    and (criado_em at time zone 'America/Sao_Paulo')::date between p_de and p_ate),
    'delivery_cancelados', (select count(*) from public.ff_pedidos where loja_id = p_loja and status = 'cancelado'
                    and (criado_em at time zone 'America/Sao_Paulo')::date between p_de and p_ate),
    'balcao', (select json_build_object('qtd', count(*), 'total', coalesce(sum(total), 0), 'descontos', coalesce(sum(desconto), 0))
                 from public.ff_vendas where loja_id = p_loja and status = 'concluida'
                  and (criado_em at time zone 'America/Sao_Paulo')::date between p_de and p_ate),
    'balcao_cancelados', (select count(*) from public.ff_vendas where loja_id = p_loja and status = 'cancelada'
                  and (criado_em at time zone 'America/Sao_Paulo')::date between p_de and p_ate),
    'balcao_formas', (select coalesce(json_object_agg(forma, valor), '{}'::json) from (
                  select p ->> 'forma' forma, sum((p ->> 'valor')::numeric) valor
                    from public.ff_vendas v, jsonb_array_elements(v.pagamentos) p
                   where v.loja_id = p_loja and v.status = 'concluida' and (v.criado_em at time zone 'America/Sao_Paulo')::date between p_de and p_ate
                   group by 1) s),
    'balcao_troco', (select coalesce(sum(troco), 0) from public.ff_vendas where loja_id = p_loja and status = 'concluida'
                  and (criado_em at time zone 'America/Sao_Paulo')::date between p_de and p_ate),
    'assinaturas', v_ass,
    'receitas', (select coalesce(sum(valor), 0) from public.ff_caixa_mov where loja_id = p_loja and tipo = 'receita' and cancelado_em is null and data between p_de and p_ate),
    'despesas', (select coalesce(sum(valor), 0) from public.ff_caixa_mov where loja_id = p_loja and tipo = 'despesa' and cancelado_em is null and data between p_de and p_ate),
    'despesas_cat', (select coalesce(json_agg(json_build_object('categoria', categoria, 'total', t) order by t desc), '[]'::json) from (
                  select coalesce(nullif(categoria, ''), 'Outros') categoria, sum(valor) t from public.ff_caixa_mov
                   where loja_id = p_loja and tipo = 'despesa' and cancelado_em is null and data between p_de and p_ate group by 1) s),
    'lancamentos', (select coalesce(json_agg(json_build_object('id', id, 'tipo', tipo, 'forma', forma, 'valor', valor, 'descricao', descricao,
                        'categoria', categoria, 'data', data, 'usuario_nome', usuario_nome, 'cancelado', cancelado_em is not null) order by data desc, criado_em desc), '[]'::json)
                    from (select * from public.ff_caixa_mov where loja_id = p_loja and tipo in ('despesa', 'receita') and data between p_de and p_ate
                           order by data desc, criado_em desc limit 500) m),
    'por_dia', (select coalesce(json_agg(json_build_object('dia', d, 'delivery', dl, 'balcao', bc, 'receitas', rc, 'despesas', dp) order by d), '[]'::json) from (
                  select g::date d,
                    (select coalesce(sum(total), 0) from public.ff_pedidos where loja_id = p_loja and status = 'entregue' and (criado_em at time zone 'America/Sao_Paulo')::date = g::date) dl,
                    (select coalesce(sum(total), 0) from public.ff_vendas where loja_id = p_loja and status = 'concluida' and (criado_em at time zone 'America/Sao_Paulo')::date = g::date) bc,
                    (select coalesce(sum(valor), 0) from public.ff_caixa_mov where loja_id = p_loja and tipo = 'receita' and cancelado_em is null and data = g::date) rc,
                    (select coalesce(sum(valor), 0) from public.ff_caixa_mov where loja_id = p_loja and tipo = 'despesa' and cancelado_em is null and data = g::date) dp
                  from generate_series(p_de, p_ate, interval '1 day') g) s),
    'assinaturas_dia', v_ass_dia,
    'caixas', (select coalesce(json_agg(json_build_object('id', id, 'numero', numero, 'status', status, 'aberto_em', aberto_em, 'fechado_em', fechado_em,
                        'aberto_por_nome', aberto_por_nome, 'fechado_por_nome', fechado_por_nome, 'valor_inicial', valor_inicial,
                        'esperado', case when status = 'aberto' then public.ff_caixa_resumo(id) else esperado end,
                        'contado', contado, 'diferenca', diferenca, 'obs', obs) order by numero desc), '[]'::json)
                 from public.ff_caixas where loja_id = p_loja and (aberto_em at time zone 'America/Sao_Paulo')::date between p_de and p_ate),
    'pdv_ativo', l.pdv_ativo, 'pdv_gaveta', l.pdv_gaveta);
end $$;
revoke all on function public.ff_financeiro(uuid, date, date) from public, anon;
grant execute on function public.ff_financeiro(uuid, date, date) to authenticated;

-- Liga/desliga o caixa da loja (dono ou administrador). Não deixa desligar a gaveta com caixa aberto.
create or replace function public.ff_pdv_config(p_loja uuid, p_ativo boolean, p_gaveta boolean)
returns json language plpgsql volatile security definer set search_path = public as $$
declare l public.ff_lojas;
begin
  l := public.ff_pdv_loja(p_loja, array['dono', 'admin']);
  if (not coalesce(p_ativo, false) or not coalesce(p_gaveta, false))
     and exists (select 1 from public.ff_caixas where loja_id = p_loja and status = 'aberto') then
    raise exception 'feche_o_caixa';
  end if;
  update public.ff_lojas set pdv_ativo = coalesce(p_ativo, false), pdv_gaveta = coalesce(p_ativo, false) and coalesce(p_gaveta, false) where id = p_loja;
  return json_build_object('pdv_ativo', coalesce(p_ativo, false), 'pdv_gaveta', coalesce(p_ativo, false) and coalesce(p_gaveta, false));
end $$;
revoke all on function public.ff_pdv_config(uuid, boolean, boolean) from public, anon;
grant execute on function public.ff_pdv_config(uuid, boolean, boolean) to authenticated;

-- =====================================================================
-- 7) Plano: a função de quem está logado (para o painel abrir a tela certa)
-- =====================================================================
create or replace function public.ff_meu_plano()
returns json language sql stable security definer set search_path = public as $$
  with d as (select public.ff_dono_de(auth.uid()) as dono)
  select json_build_object(
    'plano', pl.plano,
    'valido_ate', (select a.valido_ate from public.ff_assinaturas a join auth.users u on lower(u.email) = lower(a.email) where u.id = d.dono),
    'plano_pago', (select a.plano from public.ff_assinaturas a join auth.users u on lower(u.email) = lower(a.email) where u.id = d.dono),
    'hoje', public.ff_hoje_sp(),
    'lojas_max', li.lojas, 'produtos_max', li.produtos + public.ff_extras_de(d.dono), 'extras', public.ff_extras_de(d.dono),
    'extras_ate', (select min(g.valido_ate) from public.ff_plano_pagamentos g join auth.users u on lower(u.email) = g.email
                    where u.id = d.dono and g.plano = 'extra' and g.status = 'aprovado' and g.valido_ate >= public.ff_hoje_sp()),
    'lojas', (select count(*) from public.ff_lojas where dono = d.dono and excluida_em is null),
    'produtos', (select count(*) from public.ff_produtos p join public.ff_lojas l on l.id = p.loja_id where l.dono = d.dono and l.excluida_em is null),
    'produtos_ativos', (select count(*) from public.ff_produtos p join public.ff_lojas l on l.id = p.loja_id where l.dono = d.dono and l.excluida_em is null and p.disponivel),
    'lojas_bloqueadas', coalesce((select json_agg(x.id) from (select id, row_number() over (order by criado_em, id) rk from public.ff_lojas where dono = d.dono and excluida_em is null) x where x.rk > li.lojas), '[]'::json),
    'assinantes', public.ff_assin_usados(d.dono), 'assinantes_max', public.ff_assin_max(d.dono), 'extras_assin', public.ff_extras_assin_de(d.dono),
    'equipe', (select count(*) from public.ff_equipe where dono = d.dono),
    'equipe_max', public.ff_equipe_max(pl.plano),
    'sou_dono', d.dono = auth.uid(),
    'funcao', coalesce((select funcao from public.ff_equipe where user_id = auth.uid()), 'dono'))
  from d, lateral (select public.ff_plano_de(d.dono) as plano) pl, lateral public.ff_limites(pl.plano) li
$$;
revoke all on function public.ff_meu_plano() from public;
grant execute on function public.ff_meu_plano() to authenticated;

notify pgrst, 'reload schema';
