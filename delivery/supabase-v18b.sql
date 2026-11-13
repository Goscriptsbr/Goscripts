-- GoPedido v18b — correção urgente: a página inicial não mostrava as lojas para quem não está logado
-- (permission denied for function ff_minha_loja). Rode este arquivo uma vez.
grant execute on function public.ff_minha_loja(uuid) to anon;
