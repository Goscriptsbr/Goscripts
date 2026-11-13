-- GoPedido v15 — comprovante (opcional) na denúncia
-- Rode depois do v14. Pode rodar mais de uma vez sem problema.

alter table public.ff_denuncias add column if not exists comprovante text;

-- Arquivos da denúncia ficam em ff-comprovantes/denuncias/<id da loja>/...
-- Qualquer pessoa pode enviar (mesmo com a loja fechada ou bloqueada);
-- só o administrador consegue abrir. O lojista denunciado NÃO vê.
drop policy if exists ff_den_enviar   on storage.objects;
drop policy if exists ff_comp_admin   on storage.objects;

create policy ff_den_enviar on storage.objects for insert to anon, authenticated
  with check (bucket_id = 'ff-comprovantes'
              and (storage.foldername(name))[1] = 'denuncias'
              and exists (select 1 from public.ff_lojas l where l.id::text = (storage.foldername(name))[2]));

create policy ff_comp_admin on storage.objects for select to authenticated
  using (bucket_id = 'ff-comprovantes' and public.ff_is_admin());

drop function if exists public.ff_denunciar(uuid, text, text, text);
create or replace function public.ff_denunciar(p_loja uuid, p_motivo text, p_detalhe text default '',
                                               p_contato text default '', p_comprovante text default null)
returns json language plpgsql volatile security definer set search_path = public as $$
declare v_comp text := nullif(trim(coalesce(p_comprovante, '')), '');
begin
  if not exists (select 1 from public.ff_lojas where id = p_loja) then raise exception 'loja_invalida'; end if;
  if length(trim(coalesce(p_motivo, ''))) < 3 then raise exception 'dados_incompletos'; end if;
  if v_comp is not null and (v_comp not like 'denuncias/' || p_loja::text || '/%'
     or not exists (select 1 from storage.objects where bucket_id = 'ff-comprovantes' and name = v_comp)) then
    raise exception 'comprovante_invalido';
  end if;
  insert into public.ff_denuncias (loja_id, motivo, detalhe, contato, comprovante)
  values (p_loja, left(trim(p_motivo), 80), left(trim(coalesce(p_detalhe, '')), 1000),
          left(trim(coalesce(p_contato, '')), 120), v_comp);
  return json_build_object('ok', true);
end;
$$;
revoke all on function public.ff_denunciar(uuid, text, text, text, text) from public;
grant execute on function public.ff_denunciar(uuid, text, text, text, text) to anon, authenticated;

create or replace function public.ff_admin_denuncias()
returns json language plpgsql stable security definer set search_path = public as $$
begin
  if not public.ff_is_admin() then raise exception 'sem_permissao'; end if;
  return coalesce((select json_agg(x order by x.resolvida, x.criado_em desc) from (
    select d.id, d.motivo, d.detalhe, d.contato, d.comprovante, d.resolvida, d.criado_em,
           l.id as loja_id, l.nome as loja_nome, l.slug
      from public.ff_denuncias d join public.ff_lojas l on l.id = d.loja_id) x), '[]'::json);
end;
$$;
