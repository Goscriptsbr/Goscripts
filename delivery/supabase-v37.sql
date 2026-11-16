-- GoPedido · SQL v37 — Nome de verdade na equipe (operador de caixa, garçom e administrador)
-- Rode depois do v36. Pode rodar mais de uma vez.
--
-- • Quem entra na equipe precisa ter o NOME da pessoa (não pode ser e-mail). É o nome que aparece
--   nas vendas, nos itens lançados, nas retiradas e nos fechamentos de caixa.
-- • Só o dono da loja muda o nome de quem é da equipe (a pessoa não consegue mudar o próprio nome).
-- • O dono aparece pelo nome da conta (ou do Google, ou do responsável informado na verificação da loja).

create or replace function public.ff_equipe_nome_tg()
returns trigger language plpgsql as $$
declare v text := regexp_replace(trim(coalesce(new.nome, '')), '\s+', ' ', 'g');
begin
  if tg_op = 'UPDATE' and new.nome is not distinct from old.nome then return new; end if;
  if v like '%@%' or length(v) < 3 or v !~ '[[:alpha:]]{2,}' then raise exception 'nome_pessoa'; end if;
  new.nome := left(v, 60);
  return new;
end $$;
drop trigger if exists ff_equipe_nome_tg on public.ff_equipe;
create trigger ff_equipe_nome_tg before insert or update of nome on public.ff_equipe
  for each row execute function public.ff_equipe_nome_tg();

-- Nome de quem está logado (para registrar quem fez cada coisa)
create or replace function public.ff_nome_usuario()
returns text language sql stable security definer set search_path = public as $$
  select left(coalesce(
    nullif((select nome from public.ff_equipe where user_id = auth.uid() and nome not like '%@%'), ''),
    nullif((select trim(coalesce(raw_user_meta_data ->> 'nome', raw_user_meta_data ->> 'full_name', raw_user_meta_data ->> 'name', ''))
              from auth.users where id = auth.uid()), ''),
    nullif((select v.responsavel_nome from public.ff_verificacoes v join public.ff_lojas l on l.id = v.loja_id
             where l.dono = auth.uid() and coalesce(v.responsavel_nome, '') <> '' order by l.criado_em limit 1), ''),
    (select split_part(email, '@', 1) from auth.users where id = auth.uid()),
    ''), 80)
$$;
revoke all on function public.ff_nome_usuario() from public, anon;

notify pgrst, 'reload schema';
