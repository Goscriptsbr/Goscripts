-- GoPedido v18b — correções do v18. Pode rodar mais de uma vez.
-- 1) A página inicial não mostrava as lojas para quem não está logado (permission denied for function ff_minha_loja)
grant execute on function public.ff_minha_loja(uuid) to anon;
-- 2) A Edge Function "ff-equipe" (papel service_role) precisa usar a tabela da equipe e as funções do plano
grant all on public.ff_equipe to service_role;
grant execute on function public.ff_plano_de(uuid), public.ff_equipe_max(text), public.ff_minhas_lojas() to service_role;
