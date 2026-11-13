-- GoPedido v18c — dá ao papel de administrador (service_role, usado pela Edge Function "ff-equipe")
-- acesso às tabelas e funções do GoPedido. É o padrão do Supabase; alguns projetos novos não fazem isso sozinhos.
-- Pode rodar mais de uma vez.
grant usage on schema public to service_role;
grant all on all tables in schema public to service_role;
grant all on all sequences in schema public to service_role;
grant execute on all functions in schema public to service_role;
-- e para as tabelas/funções criadas daqui pra frente
alter default privileges in schema public grant all on tables to service_role;
alter default privileges in schema public grant all on sequences to service_role;
alter default privileges in schema public grant execute on functions to service_role;
