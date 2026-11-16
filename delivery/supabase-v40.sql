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
