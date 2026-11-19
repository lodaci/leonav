-- Prova della logica di prenotazione. Eseguire dopo stub, migrazione e seed.
\set ON_ERROR_STOP on
create or replace function pg_temp.come(u uuid) returns void language sql as
  $$ select set_config('request.jwt.claim.sub', u::text, false); $$;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-00000000000a', 'admin@azienda.it', '{"nome":"Admin"}'),
  ('00000000-0000-0000-0000-00000000000b', 'autista@azienda.it', '{"nome":"Autista"}'),
  ('00000000-0000-0000-0000-000000000001', 'lontano@azienda.it', '{"nome":"Lontano"}'),
  ('00000000-0000-0000-0000-000000000002', 'vicino@azienda.it', '{"nome":"Vicino"}'),
  ('00000000-0000-0000-0000-000000000003', 'nuovo@azienda.it', '{"nome":"Nuovo"}');
update profili set approvato = true where email <> 'nuovo@azienda.it';
update profili set ruolo = 'admin' where email = 'admin@azienda.it';
update profili set ruolo = 'autista' where email = 'autista@azienda.it';

set role authenticated;

-- Domani alle 12 non e' detto sia giorno di servizio: scegliamo il prossimo lunedi'.
create temp table g as select (current_date + ((8 - extract(isodow from current_date)::int) % 7 + 7))::date as giorno;

-- Un utente non approvato non puo' prenotare
select pg_temp.come('00000000-0000-0000-0000-000000000003');
do $$ begin
  perform prenota((select giorno from g), (select id from fermate where linea_id = 1 and tratta = 'andata' and ordine = 2));
  raise exception 'ERRORE: non approvato ha prenotato';
exception when others then
  if sqlerrm like 'ERRORE%' then raise; end if;
  raise notice 'ok non approvato bloccato: %', sqlerrm;
end $$;

-- Vicino prenota per primo alla fermata 20, Lontano dopo alla fermata 2
select pg_temp.come('00000000-0000-0000-0000-000000000002');
select id from prenota((select giorno from g), (select id from fermate where linea_id = 1 and tratta = 'andata' and ordine = 20));
select pg_temp.come('00000000-0000-0000-0000-000000000001');
select id from prenota((select giorno from g), (select id from fermate where linea_id = 1 and tratta = 'andata' and ordine = 2));
-- Lontano cambia fermata: la vecchia viene annullata, resta una sola attiva
select id from prenota((select giorno from g), (select id from fermate where linea_id = 1 and tratta = 'andata' and ordine = 3));
do $$ begin
  if (select count(*) from prenotazioni where stato = 'attiva' and utente_id = auth.uid()) <> 1 then
    raise exception 'ERRORE: piu'' prenotazioni attive';
  end if;
end $$;
-- Un'andata su un'altra linea lo stesso giorno sostituisce quella esistente
select id from prenota((select giorno from g), (select id from fermate where linea_id = 2 and tratta = 'andata' and ordine = 1));
select id from prenota((select giorno from g), (select id from fermate where linea_id = 1 and tratta = 'andata' and ordine = 3));
-- Ritorno sullo stesso giorno: ammesso
select id from prenota((select giorno from g), (select id from fermate where linea_id = 1 and tratta = 'ritorno' and ordine = 5));
-- Stabilimento non prenotabile
do $$ begin
  perform prenota((select giorno from g), (select id from fermate where linea_id = 1 and tratta = 'andata' and stabilimento));
  raise exception 'ERRORE: stabilimento prenotato';
exception when others then
  if sqlerrm like 'ERRORE%' then raise; end if;
  raise notice 'ok stabilimento bloccato';
end $$;
-- Il passeggero vede solo la propria riga
do $$ begin
  if (select count(*) from prenotazioni where utente_id <> auth.uid()) <> 0 then raise exception 'ERRORE: vede prenotazioni altrui'; end if;
end $$;
-- Non puo' promuoversi admin
do $$ begin
  update profili set ruolo = 'admin' where id = auth.uid();
  raise exception 'ERRORE: auto-promozione riuscita';
exception when others then
  if sqlerrm like 'ERRORE%' then raise; end if;
  raise notice 'ok auto-promozione bloccata';
end $$;

-- L'autista avvia la corsa con 1 posto: all'andata vince chi sale prima (Lontano)
select pg_temp.come('00000000-0000-0000-0000-00000000000b');
select id, posti, stato from avvia_corsa(1::smallint, (select giorno from g), 'andata', 1);
select nome, fermata_ordine, posizione_in_lista, ha_posto from lista_corsa((select id from corse where linea_id = 1 and tratta = 'andata'));
do $$ begin
  if (select nome from lista_corsa((select id from corse where linea_id = 1 and tratta = 'andata')) where ha_posto) <> 'Lontano' then
    raise exception 'ERRORE: precedenza andata sbagliata';
  end if;
end $$;
insert into posizioni (corsa_id, lat, lng) values ((select id from corse where linea_id = 1 and tratta = 'andata'), 45.8, 8.8);
select segna_presenza((select prenotazione_id from lista_corsa((select id from corse where linea_id = 1 and tratta = 'andata')) where nome = 'Lontano'), 'salito');
select concludi_corsa((select id from corse where linea_id = 1 and tratta = 'andata'));
select nome, presenza from lista_corsa((select id from corse where linea_id = 1 and tratta = 'andata'));
do $$ begin
  if (select presenza from lista_corsa((select id from corse where linea_id = 1 and tratta = 'andata')) where nome = 'Vicino') <> 'assente' then
    raise exception 'ERRORE: non spuntato non e'' assente';
  end if;
end $$;

-- Un passeggero non puo' scrivere posizioni
select pg_temp.come('00000000-0000-0000-0000-000000000001');
do $$ begin
  insert into posizioni (corsa_id, lat, lng) values ((select id from corse where linea_id = 1 and tratta = 'andata'), 1, 1);
  raise exception 'ERRORE: passeggero ha scritto una posizione';
exception when others then
  if sqlerrm like 'ERRORE%' then raise; end if;
  raise notice 'ok posizione del passeggero bloccata';
end $$;
-- Senza account sviluppatore niente rilevatore
do $$ begin
  perform salva_posizione_fermata(1, 45.0, 8.0);
  raise exception 'ERRORE: rilevatore senza permesso';
exception when others then
  if sqlerrm like 'ERRORE%' then raise; end if;
  raise notice 'ok rilevatore bloccato';
end $$;

select 'TUTTI I TEST SUPERATI' as esito;
