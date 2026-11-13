-- GoPedido v18d — formas de pagamento só o dono muda (a equipe vê, mas não altera).
-- Pode rodar mais de uma vez.
create or replace function public.ff_protege_loja()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if public.ff_is_admin() or pg_trigger_depth() > 1 then return new; end if;
  if tg_op = 'INSERT' then
    new.verificacao := 'pendente'; new.verificacao_motivo := '';
    new.nota_media := null; new.nota_qtd := 0;
  else
    new.verificacao := old.verificacao; new.verificacao_motivo := old.verificacao_motivo;
    new.nota_media := old.nota_media; new.nota_qtd := old.nota_qtd;
    if auth.uid() is not null and auth.uid() <> old.dono then
      -- alguém da equipe (não o dono): não muda dono, bloqueio nem Pix
      new.dono := old.dono; new.ativa := old.ativa;
      new.pix_tipo := old.pix_tipo; new.pix_chave := old.pix_chave;
      new.pix_nome := old.pix_nome; new.pix_cidade := old.pix_cidade;
      new.aceita_pix := old.aceita_pix; new.aceita_debito := old.aceita_debito;
      new.aceita_credito := old.aceita_credito; new.aceita_dinheiro := old.aceita_dinheiro;
    elsif auth.uid() is not null then
      new.dono := old.dono; new.ativa := old.ativa;   -- o dono também não troca o dono nem se desbloqueia
    end if;
  end if;
  return new;
end;
$$;
