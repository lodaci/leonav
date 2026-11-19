-- I progetti Supabase recenti non danno accesso automatico alle API per le tabelle nuove.
-- Queste concessioni aprono le tabelle agli utenti collegati; le regole RLS decidono poi cosa vede ciascuno.
grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;
grant execute on all functions in schema public to authenticated;

-- Funzioni interne: non richiamabili dall'app.
revoke execute on function public.corsa_per(smallint, date, public.tratta) from public, anon, authenticated;
revoke execute on function public.pulisci_posizioni() from public, anon, authenticated;
