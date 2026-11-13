-- =====================================================================
--  GoPedido — ATUALIZAÇÃO 14
--  Avaliações · verificação de lojas (anti-fraude) · denúncias · painel do
--  administrador · retirar no local
--  Rode DEPOIS das atualizações anteriores. Pode rodar de novo.
-- =====================================================================

-- ---------- Administradores (quem aprova lojas) ----------
create table if not exists public.ff_admins (email text primary key);
alter table public.ff_admins enable row level security;
revoke all on public.ff_admins from anon, authenticated;

create or replace function public.ff_is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.ff_admins a join auth.users u on lower(u.email) = lower(a.email)
                 where u.id = auth.uid())
$$;
grant execute on function public.ff_is_admin() to authenticated;

-- ---------- Verificação da loja ----------
do $$
begin
  if not exists (select 1 from information_schema.columns
                 where table_schema = 'public' and table_name = 'ff_lojas' and column_name = 'verificacao') then
    alter table public.ff_lojas add column verificacao text not null default 'pendente';
    -- lojas que já existiam antes desta atualização entram como verificadas
    update public.ff_lojas set verificacao = 'verificada';
  end if;
end $$;
alter table public.ff_lojas drop constraint if exists ff_lojas_verificacao_check;
alter table public.ff_lojas add constraint ff_lojas_verificacao_check check (verificacao in ('pendente','verificada','recusada'));
alter table public.ff_lojas add column if not exists verificacao_motivo text not null default '';
alter table public.ff_lojas add column if not exists aceita_retirada boolean not null default true;
alter table public.ff_lojas add column if not exists nota_media numeric(2,1);
alter table public.ff_lojas add column if not exists nota_qtd int not null default 0;

-- O lojista não consegue se auto-aprovar nem mexer nas notas
create or replace function public.ff_protege_loja()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  -- admin ou atualização automática (ex.: média das avaliações) podem mudar
  if public.ff_is_admin() or pg_trigger_depth() > 1 then return new; end if;
  if tg_op = 'INSERT' then
    new.verificacao := 'pendente'; new.verificacao_motivo := '';
    new.nota_media := null; new.nota_qtd := 0;
  else
    new.verificacao := old.verificacao; new.verificacao_motivo := old.verificacao_motivo;
    new.nota_media := old.nota_media; new.nota_qtd := old.nota_qtd;
  end if;
  return new;
end;
$$;
drop trigger if exists ff_lojas_protege on public.ff_lojas;
create trigger ff_lojas_protege before insert or update on public.ff_lojas
  for each row execute function public.ff_protege_loja();

-- Só lojas verificadas aparecem para o público
drop policy if exists ff_lojas_ver on public.ff_lojas;
create policy ff_lojas_ver on public.ff_lojas for select to anon, authenticated
  using ((ativa and verificacao = 'verificada') or dono = auth.uid() or public.ff_is_admin());

-- Dados privados para a verificação (só o dono e o admin veem)
create table if not exists public.ff_verificacoes (
  loja_id          uuid primary key references public.ff_lojas(id) on delete cascade,
  responsavel_nome text not null default '',
  responsavel_cpf  text not null default '',
  atualizado_em    timestamptz not null default now()
);
alter table public.ff_verificacoes enable row level security;
drop policy if exists ff_verif_dono on public.ff_verificacoes;
create policy ff_verif_dono on public.ff_verificacoes for all to authenticated
  using (public.ff_minha_loja(loja_id)) with check (public.ff_minha_loja(loja_id));
revoke all on public.ff_verificacoes from anon;
grant select, insert, update on public.ff_verificacoes to authenticated;

-- Cupons públicos só de loja verificada
create or replace function public.ff_cupons_publicos(p_loja uuid default null)
returns json language sql stable security definer set search_path = public as $$
  select coalesce(json_agg(json_build_object(
           'loja_id', c.loja_id, 'codigo', c.codigo, 'tipo', c.tipo, 'valor', c.valor,
           'minimo', c.minimo, 'validade', c.validade, 'por_cliente', c.por_cliente,
           'restantes', case when c.limite is null then null else greatest(c.limite - c.usos, 0) end)
         order by c.criado_em desc), '[]'::json)
    from public.ff_cupons c
    join public.ff_lojas l on l.id = c.loja_id and l.ativa and l.verificacao = 'verificada'
   where c.ativo and c.publico
     and (p_loja is null or c.loja_id = p_loja)
     and (c.validade is null or c.validade >= public.ff_hoje_sp())
     and (c.limite is null or c.usos < c.limite)
$$;

-- ---------- Retirar no local ----------
alter table public.ff_pedidos add column if not exists tipo_entrega text not null default 'entrega';
alter table public.ff_pedidos drop constraint if exists ff_pedidos_tipo_entrega_check;
alter table public.ff_pedidos add constraint ff_pedidos_tipo_entrega_check check (tipo_entrega in ('entrega','retirada'));

-- ---------- Avaliações ----------
create table if not exists public.ff_avaliacoes (
  id          uuid primary key default gen_random_uuid(),
  pedido_id   uuid not null unique references public.ff_pedidos(id) on delete cascade,
  loja_id     uuid not null references public.ff_lojas(id) on delete cascade,
  nota        int not null check (nota between 1 and 5),
  comentario  text not null default '',
  nome        text not null default '',
  resposta    text not null default '',
  resposta_em timestamptz,
  criado_em   timestamptz not null default now()
);
create index if not exists ff_avaliacoes_loja_idx on public.ff_avaliacoes (loja_id, criado_em desc);
alter table public.ff_avaliacoes enable row level security;
drop policy if exists ff_aval_dono on public.ff_avaliacoes;
create policy ff_aval_dono on public.ff_avaliacoes for select to authenticated
  using (public.ff_minha_loja(loja_id));
revoke all on public.ff_avaliacoes from anon;
grant select on public.ff_avaliacoes to authenticated;

create or replace function public.ff_atualiza_nota()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_loja uuid := coalesce(new.loja_id, old.loja_id);
begin
  update public.ff_lojas set
    nota_media = (select round(avg(nota)::numeric, 1) from public.ff_avaliacoes where loja_id = v_loja),
    nota_qtd   = (select count(*) from public.ff_avaliacoes where loja_id = v_loja)
  where id = v_loja;
  return null;
end;
$$;
drop trigger if exists ff_avaliacoes_nota on public.ff_avaliacoes;
create trigger ff_avaliacoes_nota after insert or delete or update of nota on public.ff_avaliacoes
  for each row execute function public.ff_atualiza_nota();

-- Cliente avalia pelo link do pedido (só depois de entregue, 1 vez, até 15 dias)
create or replace function public.ff_avaliar(p_token text, p_nota int, p_comentario text default '')
returns json language plpgsql volatile security definer set search_path = public as $$
declare p public.ff_pedidos;
begin
  select * into p from public.ff_pedidos where token = p_token;
  if not found then raise exception 'pedido_invalido'; end if;
  if p.status <> 'entregue' then raise exception 'avaliacao_cedo'; end if;
  if p.atualizado_em < now() - interval '15 days' then raise exception 'avaliacao_expirada'; end if;
  if exists (select 1 from public.ff_avaliacoes where pedido_id = p.id) then raise exception 'avaliacao_feita'; end if;
  if p_nota < 1 or p_nota > 5 then raise exception 'avaliacao_invalida'; end if;
  insert into public.ff_avaliacoes (pedido_id, loja_id, nota, comentario, nome)
  values (p.id, p.loja_id, p_nota, left(trim(coalesce(p_comentario, '')), 500), split_part(trim(p.cliente_nome), ' ', 1));
  return json_build_object('ok', true);
end;
$$;

-- Avaliações públicas de uma loja
create or replace function public.ff_avaliacoes_loja(p_loja uuid, p_limite int default 20)
returns json language sql stable security definer set search_path = public as $$
  select coalesce(json_agg(x), '[]'::json) from (
    select a.nome, a.nota, a.comentario, a.resposta, a.criado_em
      from public.ff_avaliacoes a join public.ff_lojas l on l.id = a.loja_id and l.verificacao = 'verificada'
     where a.loja_id = p_loja
     order by a.criado_em desc limit least(coalesce(p_limite, 20), 50)) x
$$;

-- Lojista responde uma avaliação
create or replace function public.ff_responder_avaliacao(p_id uuid, p_texto text)
returns json language plpgsql volatile security definer set search_path = public as $$
begin
  update public.ff_avaliacoes set resposta = left(trim(coalesce(p_texto, '')), 500), resposta_em = now()
   where id = p_id and public.ff_minha_loja(loja_id);
  if not found then raise exception 'pedido_invalido'; end if;
  return json_build_object('ok', true);
end;
$$;

-- Acompanhar pedido: inclui tipo de entrega e a avaliação (se houver)
create or replace function public.ff_acompanhar(p_token text)
returns json language sql stable security definer set search_path = public as $$
  select json_build_object(
    'numero', p.numero, 'status', p.status, 'criado_em', p.criado_em,
    'atualizado_em', p.atualizado_em, 'cliente_nome', p.cliente_nome,
    'endereco', p.endereco, 'complemento', p.complemento, 'tipo_entrega', p.tipo_entrega,
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

-- Motoboy: não mostra pedidos de retirada
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
    where p.loja_id = v_loja and p.tipo_entrega = 'entrega'
      and (p.status in ('preparando', 'saiu')
           or (p.status = 'entregue' and p.atualizado_em > now() - interval '12 hours'))
  ), '[]'::json);
end;
$$;

-- ---------- Denúncias ----------
create table if not exists public.ff_denuncias (
  id         uuid primary key default gen_random_uuid(),
  loja_id    uuid not null references public.ff_lojas(id) on delete cascade,
  motivo     text not null,
  detalhe    text not null default '',
  contato    text not null default '',
  resolvida  boolean not null default false,
  criado_em  timestamptz not null default now()
);
alter table public.ff_denuncias enable row level security;
revoke all on public.ff_denuncias from anon, authenticated;

create or replace function public.ff_denunciar(p_loja uuid, p_motivo text, p_detalhe text default '', p_contato text default '')
returns json language plpgsql volatile security definer set search_path = public as $$
begin
  if not exists (select 1 from public.ff_lojas where id = p_loja) then raise exception 'loja_invalida'; end if;
  if length(trim(coalesce(p_motivo, ''))) < 3 then raise exception 'dados_incompletos'; end if;
  insert into public.ff_denuncias (loja_id, motivo, detalhe, contato)
  values (p_loja, left(trim(p_motivo), 80), left(trim(coalesce(p_detalhe, '')), 1000), left(trim(coalesce(p_contato, '')), 120));
  return json_build_object('ok', true);
end;
$$;

-- ---------- Funções do administrador ----------
create or replace function public.ff_admin_lojas()
returns json language plpgsql stable security definer set search_path = public as $$
begin
  if not public.ff_is_admin() then raise exception 'sem_permissao'; end if;
  return coalesce((select json_agg(x order by x.ordem, x.criado_em desc) from (
    select l.id, l.slug, l.nome, l.descricao, l.imagem_url, l.cnpj, l.telefone, l.endereco, l.pix_tipo, l.pix_chave, l.pix_nome,
           l.verificacao, l.verificacao_motivo, l.ativa, l.aberta, l.criado_em, l.nota_media, l.nota_qtd,
           u.email as dono_email, v.responsavel_nome, v.responsavel_cpf,
           (select count(*) from public.ff_pedidos p where p.loja_id = l.id) as pedidos,
           (select count(*) from public.ff_produtos p where p.loja_id = l.id) as produtos,
           (select count(*) from public.ff_denuncias d where d.loja_id = l.id and not d.resolvida) as denuncias,
           case l.verificacao when 'pendente' then 0 when 'recusada' then 2 else 1 end as ordem
      from public.ff_lojas l
      left join auth.users u on u.id = l.dono
      left join public.ff_verificacoes v on v.loja_id = l.id) x), '[]'::json);
end;
$$;

create or replace function public.ff_admin_verificar(p_loja uuid, p_status text, p_motivo text default '')
returns json language plpgsql volatile security definer set search_path = public as $$
begin
  if not public.ff_is_admin() then raise exception 'sem_permissao'; end if;
  if p_status not in ('pendente','verificada','recusada') then raise exception 'dados_incompletos'; end if;
  update public.ff_lojas set verificacao = p_status, verificacao_motivo = left(trim(coalesce(p_motivo, '')), 300),
         aberta = case when p_status = 'verificada' then aberta else false end
   where id = p_loja;
  return json_build_object('ok', true);
end;
$$;

create or replace function public.ff_admin_ativar(p_loja uuid, p_ativa boolean)
returns json language plpgsql volatile security definer set search_path = public as $$
begin
  if not public.ff_is_admin() then raise exception 'sem_permissao'; end if;
  update public.ff_lojas set ativa = p_ativa, aberta = case when p_ativa then aberta else false end where id = p_loja;
  return json_build_object('ok', true);
end;
$$;

create or replace function public.ff_admin_denuncias()
returns json language plpgsql stable security definer set search_path = public as $$
begin
  if not public.ff_is_admin() then raise exception 'sem_permissao'; end if;
  return coalesce((select json_agg(x order by x.resolvida, x.criado_em desc) from (
    select d.id, d.motivo, d.detalhe, d.contato, d.resolvida, d.criado_em, l.id as loja_id, l.nome as loja_nome, l.slug
      from public.ff_denuncias d join public.ff_lojas l on l.id = d.loja_id) x), '[]'::json);
end;
$$;

create or replace function public.ff_admin_resolver_denuncia(p_id uuid, p_resolvida boolean default true)
returns json language plpgsql volatile security definer set search_path = public as $$
begin
  if not public.ff_is_admin() then raise exception 'sem_permissao'; end if;
  update public.ff_denuncias set resolvida = p_resolvida where id = p_id;
  return json_build_object('ok', true);
end;
$$;

create or replace function public.ff_admin_lojistas()
returns json language plpgsql stable security definer set search_path = public as $$
begin
  if not public.ff_is_admin() then raise exception 'sem_permissao'; end if;
  return coalesce((select json_agg(x order by x.email) from (
    select u.email, public.ff_plano_de(u.id) as plano,
           (select a.valido_ate from public.ff_assinaturas a where lower(a.email) = lower(u.email)) as valido_ate,
           (select count(*) from public.ff_lojas l where l.dono = u.id) as lojas,
           (select count(*) from public.ff_produtos p join public.ff_lojas l on l.id = p.loja_id where l.dono = u.id) as produtos
      from auth.users u
     where exists (select 1 from public.ff_lojas l where l.dono = u.id)) x), '[]'::json);
end;
$$;

create or replace function public.ff_admin_set_plano(p_email text, p_plano text, p_valido_ate date default null)
returns json language plpgsql volatile security definer set search_path = public as $$
begin
  if not public.ff_is_admin() then raise exception 'sem_permissao'; end if;
  if p_plano not in ('gratis','profissional','premium') then raise exception 'dados_incompletos'; end if;
  insert into public.ff_assinaturas (email, plano, valido_ate) values (lower(trim(p_email)), p_plano, p_valido_ate)
  on conflict (email) do update set plano = excluded.plano, valido_ate = excluded.valido_ate;
  return json_build_object('ok', true);
end;
$$;

-- ---------- Criar pedido: loja verificada + retirada no local ----------
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
begin
  select * into l from public.ff_lojas where id = p_loja and ativa;
  if not found then raise exception 'loja_invalida'; end if;
  if not public.ff_aberta_agora(l.horario_auto, l.aberta, l.horarios) then raise exception 'loja_fechada'; end if;
  if l.verificacao <> 'verificada' then raise exception 'loja_em_analise'; end if;
  if l.lat is null or l.lng is null then raise exception 'loja_sem_localizacao'; end if;
  if v_ret and not l.aceita_retirada then raise exception 'retirada_indisponivel'; end if;

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
     distancia_km, taxa_entrega, pagamento, comprovante_path, observacao, tipo_entrega)
  values
    (l.id, auth.uid(), left(trim(p_cliente ->> 'nome'), 80), left(trim(p_cliente ->> 'telefone'), 30),
     case when v_ret then 'Retirada no local' else left(trim(p_cliente ->> 'endereco'), 200) end,
     case when v_ret then '' else left(trim(coalesce(p_cliente ->> 'complemento', '')), 120) end,
     v_lat, v_lng, v_dist, v_taxa, p_pagamento,
     case when p_pagamento = 'pix' then p_comprovante end,
     left(trim(coalesce(p_cliente ->> 'observacao', '')), 300),
     case when v_ret then 'retirada' else 'entrega' end)
  returning * into v_ped;

  for it in select * from jsonb_array_elements(coalesce(p_itens, '[]'::jsonb)) loop
    q := least(greatest(coalesce((it ->> 'qtd')::int, 0), 0), 99);
    continue when q = 0;
    select * into pr from public.ff_produtos
     where id = (it ->> 'id')::uuid and loja_id = l.id and disponivel;
    if not found then raise exception 'produto_indisponivel'; end if;

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

    v_unit := public.ff_preco_atual(pr.preco, pr.preco_promo, pr.promo_ate);
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

    insert into public.ff_pedido_itens (pedido_id, produto_id, nome, preco, qtd, obs, opcoes)
    values (v_ped.id, pr.id, pr.nome, v_unit, q, left(trim(coalesce(it ->> 'obs', '')), 200), v_snap);
    v_sub := v_sub + v_unit * q;
    n := n + 1;
  end loop;

  if n = 0 then raise exception 'carrinho_vazio'; end if;
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



-- ---------- Permissões ----------
revoke all on function public.ff_avaliar(text, int, text) from public;
revoke all on function public.ff_avaliacoes_loja(uuid, int) from public;
revoke all on function public.ff_responder_avaliacao(uuid, text) from public;
revoke all on function public.ff_denunciar(uuid, text, text, text) from public;
revoke all on function public.ff_admin_lojas() from public;
revoke all on function public.ff_admin_verificar(uuid, text, text) from public;
revoke all on function public.ff_admin_ativar(uuid, boolean) from public;
revoke all on function public.ff_admin_denuncias() from public;
revoke all on function public.ff_admin_resolver_denuncia(uuid, boolean) from public;
revoke all on function public.ff_admin_lojistas() from public;
revoke all on function public.ff_admin_set_plano(text, text, date) from public;
grant execute on function public.ff_avaliar(text, int, text) to anon, authenticated;
grant execute on function public.ff_avaliacoes_loja(uuid, int) to anon, authenticated;
grant execute on function public.ff_responder_avaliacao(uuid, text) to authenticated;
grant execute on function public.ff_denunciar(uuid, text, text, text) to anon, authenticated;
grant execute on function public.ff_admin_lojas() to authenticated;
grant execute on function public.ff_admin_verificar(uuid, text, text) to authenticated;
grant execute on function public.ff_admin_ativar(uuid, boolean) to authenticated;
grant execute on function public.ff_admin_denuncias() to authenticated;
grant execute on function public.ff_admin_resolver_denuncia(uuid, boolean) to authenticated;
grant execute on function public.ff_admin_lojistas() to authenticated;
grant execute on function public.ff_admin_set_plano(text, text, date) to authenticated;
grant execute on function public.ff_criar_pedido(uuid, jsonb, jsonb, text, text) to anon, authenticated;
grant execute on function public.ff_acompanhar(text) to anon, authenticated;
grant execute on function public.ff_entregador_pedidos(text) to anon, authenticated;
