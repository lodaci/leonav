-- LeoNav: schema iniziale
-- Tabelle, regole di accesso (RLS) e funzioni usate dall'app.

-- ---------------------------------------------------------------------------
-- Tipi
-- ---------------------------------------------------------------------------
create type public.ruolo as enum ('passeggero', 'autista', 'admin');
create type public.tratta as enum ('andata', 'ritorno');
create type public.stato_corsa as enum ('programmata', 'in_corso', 'conclusa');
create type public.stato_prenotazione as enum ('attiva', 'annullata');
create type public.presenza as enum ('da_segnare', 'salito', 'assente');

-- ---------------------------------------------------------------------------
-- Impostazioni (una sola riga)
-- ---------------------------------------------------------------------------
create table public.impostazioni (
  id smallint primary key default 1 check (id = 1),
  -- minuti prima del passaggio alla fermata entro cui si puo' annullare o cambiare
  minuti_anticipo integer not null default 5 check (minuti_anticipo >= 0),
  -- giorni di servizio (1 = lunedi' ... 7 = domenica, ISO)
  giorni_servizio smallint[] not null default '{1,2,3,4,5}',
  -- giorni prenotabili in anticipo
  giorni_prenotabili integer not null default 14 check (giorni_prenotabili > 0),
  -- dominio email ammesso alla registrazione, es. 'azienda.it' (null = qualsiasi)
  dominio_email text,
  -- giorni di conservazione dello storico posizioni
  giorni_storico_posizioni integer not null default 3
);
insert into public.impostazioni (id) values (1);

create table public.festivi (
  data date primary key,
  descrizione text
);

-- ---------------------------------------------------------------------------
-- Linee e fermate
-- ---------------------------------------------------------------------------
create table public.linee (
  id smallint primary key,
  nome text not null,
  colore text not null default '#1565C0',
  orario_ritorno time not null default '16:45',
  attiva boolean not null default true
);

create table public.fermate (
  id bigint generated always as identity primary key,
  linea_id smallint not null references public.linee (id) on delete cascade,
  tratta public.tratta not null,
  ordine integer not null,
  nome text not null,
  lat double precision,
  lng double precision,
  -- orario previsto di passaggio (null se non noto)
  orario time,
  -- true se la posizione e' stata registrata sul posto in modalita' rilevatore
  rilevata boolean not null default false,
  -- true per lo stabilimento (arrivo dell'andata, partenza del ritorno)
  stabilimento boolean not null default false,
  unique (linea_id, tratta, ordine) deferrable initially immediate
);
create index on public.fermate (linea_id, tratta, ordine);

-- Tracce registrate in modalita' rilevatore: [[lat, lng], ...]
create table public.percorsi (
  id bigint generated always as identity primary key,
  linea_id smallint not null references public.linee (id) on delete cascade,
  tratta public.tratta not null,
  punti jsonb not null,
  registrato_da uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);
create index on public.percorsi (linea_id, tratta, created_at desc);

-- ---------------------------------------------------------------------------
-- Profili utente
-- ---------------------------------------------------------------------------
create table public.profili (
  id uuid primary key references auth.users (id) on delete cascade,
  nome text not null default '',
  email text not null,
  ruolo public.ruolo not null default 'passeggero',
  -- account sviluppatore: puo' usare la modalita' rilevatore
  sviluppatore boolean not null default false,
  approvato boolean not null default false,
  linea_abituale smallint references public.linee (id) on delete set null,
  fermata_andata bigint references public.fermate (id) on delete set null,
  fermata_ritorno bigint references public.fermate (id) on delete set null,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Corse, prenotazioni, posizioni
-- ---------------------------------------------------------------------------
create table public.corse (
  id bigint generated always as identity primary key,
  linea_id smallint not null references public.linee (id) on delete cascade,
  data date not null,
  tratta public.tratta not null,
  autista_id uuid references public.profili (id) on delete set null,
  -- posti del veicolo di oggi, indicati dall'autista all'avvio (null = non ancora noti)
  posti integer check (posti is null or posti > 0),
  stato public.stato_corsa not null default 'programmata',
  iniziata_at timestamptz,
  conclusa_at timestamptz,
  unique (linea_id, data, tratta)
);
create index on public.corse (data);

create table public.prenotazioni (
  id bigint generated always as identity primary key,
  utente_id uuid not null references public.profili (id) on delete cascade,
  corsa_id bigint not null references public.corse (id) on delete cascade,
  fermata_id bigint not null references public.fermate (id) on delete restrict,
  -- copiati dalla corsa per il vincolo "una andata e un ritorno al giorno"
  data date not null,
  tratta public.tratta not null,
  stato public.stato_prenotazione not null default 'attiva',
  presenza public.presenza not null default 'da_segnare',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index prenotazioni_una_al_giorno
  on public.prenotazioni (utente_id, data, tratta) where stato = 'attiva';
create index on public.prenotazioni (corsa_id);

create table public.posizioni (
  id bigint generated always as identity primary key,
  corsa_id bigint not null references public.corse (id) on delete cascade,
  lat double precision not null,
  lng double precision not null,
  velocita double precision,
  direzione double precision,
  registrata_at timestamptz not null default now()
);
create index on public.posizioni (corsa_id, registrata_at desc);

-- ---------------------------------------------------------------------------
-- Funzioni di supporto per i permessi
-- ---------------------------------------------------------------------------
create or replace function public.mio_profilo()
returns public.profili
language sql stable security definer set search_path = public
as $$ select * from public.profili where id = auth.uid() $$;

create or replace function public.e_approvato()
returns boolean
language sql stable security definer set search_path = public
as $$ select coalesce((select approvato from public.profili where id = auth.uid()), false) $$;

create or replace function public.e_admin()
returns boolean
language sql stable security definer set search_path = public
as $$ select coalesce((select approvato and ruolo = 'admin' from public.profili where id = auth.uid()), false) $$;

create or replace function public.e_staff()
returns boolean
language sql stable security definer set search_path = public
as $$ select coalesce((select approvato and ruolo in ('autista', 'admin') from public.profili where id = auth.uid()), false) $$;

create or replace function public.e_sviluppatore()
returns boolean
language sql stable security definer set search_path = public
as $$ select coalesce((select approvato and (sviluppatore or ruolo = 'admin') from public.profili where id = auth.uid()), false) $$;

-- ---------------------------------------------------------------------------
-- Registrazione: crea il profilo, controlla il dominio email
-- ---------------------------------------------------------------------------
create or replace function public.nuovo_utente()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  dominio text;
begin
  select dominio_email into dominio from public.impostazioni where id = 1;
  if dominio is not null and lower(split_part(new.email, '@', 2)) <> lower(dominio) then
    raise exception 'Registrazione consentita solo con email @%', dominio;
  end if;
  insert into public.profili (id, email, nome)
  values (new.id, new.email, coalesce(new.raw_user_meta_data ->> 'nome', ''));
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.nuovo_utente();

-- Un utente puo' modificare il proprio nome e le preferenze, non ruolo o approvazione.
create or replace function public.proteggi_profilo()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if public.e_admin() or auth.uid() is null then
    return new;
  end if;
  if new.ruolo is distinct from old.ruolo
     or new.approvato is distinct from old.approvato
     or new.sviluppatore is distinct from old.sviluppatore
     or new.email is distinct from old.email then
    raise exception 'Solo un amministratore puo'' cambiare ruolo o approvazione';
  end if;
  return new;
end;
$$;

create trigger profili_protezione
  before update on public.profili
  for each row execute function public.proteggi_profilo();

-- ---------------------------------------------------------------------------
-- Regole di accesso (RLS)
-- ---------------------------------------------------------------------------
alter table public.impostazioni enable row level security;
alter table public.festivi enable row level security;
alter table public.linee enable row level security;
alter table public.fermate enable row level security;
alter table public.percorsi enable row level security;
alter table public.profili enable row level security;
alter table public.corse enable row level security;
alter table public.prenotazioni enable row level security;
alter table public.posizioni enable row level security;

-- Dati di configurazione: leggibili dagli utenti approvati, modificabili dagli admin.
create policy lettura on public.impostazioni for select using (public.e_approvato());
create policy admin on public.impostazioni for all using (public.e_admin()) with check (public.e_admin());
create policy lettura on public.festivi for select using (public.e_approvato());
create policy admin on public.festivi for all using (public.e_admin()) with check (public.e_admin());
create policy lettura on public.linee for select using (public.e_approvato());
create policy admin on public.linee for all using (public.e_admin()) with check (public.e_admin());
create policy lettura on public.fermate for select using (public.e_approvato());
create policy admin on public.fermate for all using (public.e_admin()) with check (public.e_admin());
create policy lettura on public.percorsi for select using (public.e_approvato());
create policy inserimento on public.percorsi for insert with check (public.e_sviluppatore() and registrato_da = auth.uid());
create policy admin on public.percorsi for all using (public.e_admin()) with check (public.e_admin());

-- Profili: ciascuno vede e modifica il proprio; autisti e admin vedono tutti; admin modifica tutti.
create policy proprio on public.profili for select using (id = auth.uid() or public.e_staff());
create policy modifica_proprio on public.profili for update using (id = auth.uid()) with check (id = auth.uid());
create policy admin on public.profili for all using (public.e_admin()) with check (public.e_admin());

-- Corse: leggibili dagli approvati; scritte tramite funzioni o dagli admin.
create policy lettura on public.corse for select using (public.e_approvato());
create policy admin on public.corse for all using (public.e_admin()) with check (public.e_admin());

-- Prenotazioni: proprie, oppure tutte per autisti e admin; scritte tramite funzioni o dagli admin.
create policy lettura on public.prenotazioni for select using (utente_id = auth.uid() or public.e_staff());
create policy admin on public.prenotazioni for all using (public.e_admin()) with check (public.e_admin());

-- Posizioni: le scrive l'autista della corsa in corso; le leggono gli approvati.
create policy lettura on public.posizioni for select using (public.e_approvato());
create policy inserimento on public.posizioni for insert with check (
  exists (
    select 1 from public.corse c
    where c.id = corsa_id and c.autista_id = auth.uid() and c.stato = 'in_corso'
  )
);

-- ---------------------------------------------------------------------------
-- Logica di prenotazione
-- ---------------------------------------------------------------------------

-- Momento oltre il quale una prenotazione non si puo' piu' cambiare:
-- orario previsto alla fermata (o partenza del ritorno) meno i minuti di anticipo.
create or replace function public.limite_modifica(p_fermata_id bigint, p_data date)
returns timestamptz
language sql stable security definer set search_path = public
as $$
  select ((p_data + coalesce(
            f.orario,
            case when f.tratta = 'ritorno' then l.orario_ritorno end,
            (select min(f2.orario) from public.fermate f2
              where f2.linea_id = f.linea_id and f2.tratta = f.tratta),
            time '00:00'))::timestamp at time zone 'Europe/Rome')
         - make_interval(mins => i.minuti_anticipo)
  from public.fermate f
  join public.linee l on l.id = f.linea_id
  cross join public.impostazioni i
  where f.id = p_fermata_id
$$;

-- Restituisce la corsa (la crea se non esiste ancora).
create or replace function public.corsa_per(p_linea smallint, p_data date, p_tratta public.tratta)
returns public.corse
language plpgsql security definer set search_path = public
as $$
declare
  c public.corse;
begin
  insert into public.corse (linea_id, data, tratta)
  values (p_linea, p_data, p_tratta)
  on conflict (linea_id, data, tratta) do nothing;
  select * into c from public.corse
  where linea_id = p_linea and data = p_data and tratta = p_tratta;
  return c;
end;
$$;
revoke execute on function public.corsa_per(smallint, date, public.tratta) from public, anon, authenticated;

-- Prenota (o cambia) andata o ritorno per un giorno, alla fermata scelta.
create or replace function public.prenota(p_data date, p_fermata_id bigint)
returns public.prenotazioni
language plpgsql security definer set search_path = public
as $$
declare
  f public.fermate;
  i public.impostazioni;
  c public.corse;
  p public.prenotazioni;
begin
  if not public.e_approvato() then
    raise exception 'Account non ancora approvato';
  end if;

  select * into f from public.fermate where id = p_fermata_id;
  if f is null then
    raise exception 'Fermata inesistente';
  end if;
  if f.stabilimento then
    raise exception 'Scegli la fermata dove salire o scendere, non lo stabilimento';
  end if;
  if not exists (select 1 from public.linee where id = f.linea_id and attiva) then
    raise exception 'Linea non attiva';
  end if;

  select * into i from public.impostazioni where id = 1;
  if extract(isodow from p_data)::smallint <> all (i.giorni_servizio)
     or exists (select 1 from public.festivi where data = p_data) then
    raise exception 'Il % non c''e'' servizio', to_char(p_data, 'DD/MM/YYYY');
  end if;
  if p_data > (now() at time zone 'Europe/Rome')::date + i.giorni_prenotabili then
    raise exception 'Si puo'' prenotare al massimo % giorni in anticipo', i.giorni_prenotabili;
  end if;
  if now() > public.limite_modifica(p_fermata_id, p_data) then
    raise exception 'Troppo tardi: si prenota fino a % minuti prima del passaggio', i.minuti_anticipo;
  end if;

  c := public.corsa_per(f.linea_id, p_data, f.tratta);
  if c.stato = 'conclusa' then
    raise exception 'La corsa e'' gia'' conclusa';
  end if;

  -- Se esiste gia' una prenotazione per lo stesso giorno e tratta, la si sostituisce,
  -- purche' sia ancora modificabile.
  select * into p from public.prenotazioni
  where utente_id = auth.uid() and data = p_data and tratta = f.tratta and stato = 'attiva';
  if p is not null then
    if now() > public.limite_modifica(p.fermata_id, p_data) then
      raise exception 'La prenotazione esistente non si puo'' piu'' cambiare';
    end if;
    update public.prenotazioni
      set stato = 'annullata', updated_at = now()
      where id = p.id;
  end if;

  insert into public.prenotazioni (utente_id, corsa_id, fermata_id, data, tratta)
  values (auth.uid(), c.id, p_fermata_id, p_data, f.tratta)
  returning * into p;
  return p;
end;
$$;

create or replace function public.annulla_prenotazione(p_id bigint)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  p public.prenotazioni;
begin
  select * into p from public.prenotazioni
  where id = p_id and utente_id = auth.uid() and stato = 'attiva';
  if p is null then
    raise exception 'Prenotazione non trovata';
  end if;
  if now() > public.limite_modifica(p.fermata_id, p.data) then
    raise exception 'Troppo tardi per annullare';
  end if;
  update public.prenotazioni set stato = 'annullata', updated_at = now() where id = p_id;
end;
$$;

-- Lista di una corsa con l'indicazione di chi ha il posto.
-- Andata: ha la precedenza chi sale prima nell'ordine delle fermate (chi abita piu' lontano),
-- a parita' di fermata chi ha prenotato prima. Ritorno: chi ha prenotato prima.
-- Autisti e admin vedono tutta la lista, un passeggero solo la propria riga.
create or replace function public.lista_corsa(p_corsa_id bigint)
returns table (
  prenotazione_id bigint,
  utente_id uuid,
  nome text,
  fermata_id bigint,
  fermata_nome text,
  fermata_ordine integer,
  presenza public.presenza,
  posizione_in_lista integer,
  ha_posto boolean
)
language sql stable security definer set search_path = public
as $$
  with c as (select * from public.corse where id = p_corsa_id),
  ordinate as (
    select p.id, p.utente_id, pr.nome, f.id as fid, f.nome as fnome, f.ordine, p.presenza,
           row_number() over (
             order by
               case when (select tratta from c) = 'andata' then f.ordine end,
               p.created_at, p.id
           )::integer as pos
    from public.prenotazioni p
    join public.fermate f on f.id = p.fermata_id
    join public.profili pr on pr.id = p.utente_id
    where p.corsa_id = p_corsa_id and p.stato = 'attiva'
  )
  select o.id, o.utente_id, o.nome, o.fid, o.fnome, o.ordine, o.presenza, o.pos,
         ((select posti from c) is null or o.pos <= (select posti from c))
  from ordinate o
  where public.e_approvato() and (public.e_staff() or o.utente_id = auth.uid())
  order by o.ordine, o.pos
$$;

-- ---------------------------------------------------------------------------
-- Funzioni per l'autista
-- ---------------------------------------------------------------------------
create or replace function public.avvia_corsa(p_linea smallint, p_data date, p_tratta public.tratta, p_posti integer)
returns public.corse
language plpgsql security definer set search_path = public
as $$
declare
  c public.corse;
begin
  if not public.e_staff() then
    raise exception 'Solo gli autisti possono avviare una corsa';
  end if;
  if p_posti is null or p_posti <= 0 then
    raise exception 'Indica i posti del veicolo';
  end if;
  c := public.corsa_per(p_linea, p_data, p_tratta);
  if c.stato = 'conclusa' then
    raise exception 'La corsa e'' gia'' conclusa';
  end if;
  if c.stato = 'in_corso' and c.autista_id is distinct from auth.uid() then
    raise exception 'La corsa e'' gia'' in corso con un altro autista';
  end if;
  update public.corse
    set autista_id = auth.uid(), posti = p_posti, stato = 'in_corso',
        iniziata_at = coalesce(iniziata_at, now())
    where id = c.id
    returning * into c;
  return c;
end;
$$;

create or replace function public.aggiorna_posti(p_corsa_id bigint, p_posti integer)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if p_posti is null or p_posti <= 0 then
    raise exception 'Numero di posti non valido';
  end if;
  update public.corse set posti = p_posti
  where id = p_corsa_id and (autista_id = auth.uid() or public.e_admin());
  if not found then
    raise exception 'Corsa non trovata';
  end if;
end;
$$;

create or replace function public.segna_presenza(p_prenotazione_id bigint, p_presenza public.presenza)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  update public.prenotazioni p
    set presenza = p_presenza, updated_at = now()
    from public.corse c
    where p.id = p_prenotazione_id and c.id = p.corsa_id
      and (c.autista_id = auth.uid() or public.e_admin());
  if not found then
    raise exception 'Prenotazione non trovata per questa corsa';
  end if;
end;
$$;

-- Chiude la corsa: chi non e' stato spuntato risulta assente.
create or replace function public.concludi_corsa(p_corsa_id bigint)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  update public.corse
    set stato = 'conclusa', conclusa_at = now()
    where id = p_corsa_id and (autista_id = auth.uid() or public.e_admin()) and stato = 'in_corso';
  if not found then
    raise exception 'Corsa non in corso';
  end if;
  update public.prenotazioni
    set presenza = 'assente', updated_at = now()
    where corsa_id = p_corsa_id and stato = 'attiva' and presenza = 'da_segnare';
end;
$$;

-- ---------------------------------------------------------------------------
-- Modalita' rilevatore (account sviluppatore)
-- ---------------------------------------------------------------------------
create or replace function public.salva_posizione_fermata(p_fermata_id bigint, p_lat double precision, p_lng double precision)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if not public.e_sviluppatore() then
    raise exception 'Serve un account sviluppatore';
  end if;
  update public.fermate set lat = p_lat, lng = p_lng, rilevata = true where id = p_fermata_id;
  if not found then
    raise exception 'Fermata inesistente';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Pulizia dello storico posizioni (da pianificare con pg_cron, vedi README)
-- ---------------------------------------------------------------------------
create or replace function public.pulisci_posizioni()
returns void
language sql security definer set search_path = public
as $$
  delete from public.posizioni
  where registrata_at < now() - make_interval(days => (select giorni_storico_posizioni from public.impostazioni where id = 1))
$$;
revoke execute on function public.pulisci_posizioni() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Tempo reale
-- ---------------------------------------------------------------------------
alter publication supabase_realtime add table public.posizioni, public.corse, public.prenotazioni;
