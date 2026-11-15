-- GoPedido v25 (parte 2) — Lembrete por e-mail 3 horas antes do horário marcado.
-- Rode DEPOIS do supabase-v25.sql e de publicar a função ff-email nova.
-- Liga o agendador do Supabase para chamar a função ff-email de 5 em 5 minutos.
-- Se der erro de permissão nas duas primeiras linhas: Supabase → Database → Extensions,
-- ligue "pg_cron" e "pg_net" e rode este arquivo de novo.

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- tira a versão antiga, se existir, e agenda de novo
do $$ begin
  perform cron.unschedule('gopedido-lembretes');
exception when others then null;
end $$;

select cron.schedule(
  'gopedido-lembretes',
  '*/5 * * * *',
  $$ select net.http_post(
       url     := 'https://ypmtdhcgjyxigkuijmje.supabase.co/functions/v1/ff-email',
       body    := '{"acao":"lembretes"}'::jsonb,
       headers := '{"Content-Type":"application/json"}'::jsonb
     ) $$
);

-- Para conferir: select * from cron.job;   e   select * from cron.job_run_details order by start_time desc limit 5;
