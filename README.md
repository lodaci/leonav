# LeoNav

App Android e iOS per la navetta aziendale, scritta in Flutter, con backend Supabase.

- **Passeggero**: prenota andata e/o ritorno per giorno e fermata, fino a 5 minuti prima del passaggio; segue la navetta sulla mappa; vede se i posti sono finiti.
- **Autista**: avvia la corsa indicando i posti del veicolo, vede le fermate con chi sale o scende, spunta le presenze, condivide la posizione finché la corsa è attiva.
- **Rilevatore** (account sviluppatore): a bordo registra la posizione reale di ogni fermata, all'andata e al ritorno, e il percorso effettivo.
- **Amministratore**: pannello web (passo 3, in arrivo).

Le specifiche complete sono nel documento di progetto.

## Struttura

| Cartella | Contenuto |
| --- | --- |
| `app/` | App Flutter (Android, iOS, web) |
| `supabase/migrations/` | Schema del database, regole di accesso (RLS) e funzioni |
| `supabase/seed.sql` | Linee e fermate iniziali, generato da `data/fermate.csv` |
| `supabase/tests/` | Prove automatiche della logica del database |
| `data/fermate.csv` | Le 5 linee con fermate e orari del mattino |
| `tools/genera_seed.py` | Rigenera `seed.sql` dal CSV |

## Regole principali (nel database)

- Una sola prenotazione di andata e una di ritorno al giorno, anche su linee diverse.
- Si prenota, cambia o annulla fino a 5 minuti prima dell'orario previsto alla fermata (il ritorno usa la partenza delle 16:45). Il valore è in `impostazioni.minuti_anticipo`.
- Se i prenotati superano i posti indicati dall'autista: all'andata tiene il posto chi sale prima nell'ordine delle fermate, al ritorno chi ha prenotato prima.
- Alla fine della corsa chi non è stato spuntato risulta assente.
- Ritorno: fermate separate dall'andata (stesse fermate in ordine inverso all'inizio, da correggere con il rilevatore dove le strade sono a senso unico).

## Mettere in funzione

### 1. Supabase

1. Crea un progetto gratuito su [supabase.com](https://supabase.com), regione UE.
2. Installa la [CLI di Supabase](https://supabase.com/docs/guides/cli), poi dalla cartella del repository:
   ```
   supabase link --project-ref <id-progetto>
   supabase db push
   psql "<connection string>" -f supabase/seed.sql
   ```
3. In *Authentication → Providers → Email* lascia attiva la conferma email.
4. Facoltativo: limita la registrazione al dominio aziendale:
   ```sql
   update impostazioni set dominio_email = 'azienda.it';
   ```
5. Registrati dall'app, poi rendi admin il tuo account dal *SQL editor*:
   ```sql
   update profili set approvato = true, ruolo = 'admin', sviluppatore = true where email = 'tua@email';
   ```
   Finché non c'è il pannello web, gli altri utenti si approvano allo stesso modo
   (`ruolo` = `passeggero` o `autista`).
6. Facoltativo: pulizia notturna dello storico posizioni con pg_cron:
   ```sql
   select cron.schedule('pulisci-posizioni', '0 3 * * *', 'select public.pulisci_posizioni()');
   ```

### 2. App

Serve [Flutter](https://docs.flutter.dev/get-started/install) stabile.

```
cd app
flutter run --dart-define=SUPABASE_URL=https://<id>.supabase.co --dart-define=SUPABASE_KEY=<publishable key>
```

URL e chiave publishable sono in *Project Settings → API*. La chiave è pubblica per natura: i dati sono protetti dalle regole di accesso.

## Sviluppo

```
cd app && flutter analyze && flutter test       # app
supabase/tests/esegui.sh                        # database (serve Docker)
(cd supabase/tests/e2e && npm i && npm test)    # prova completa, con supabase start
python3 tools/genera_seed.py                    # dopo aver modificato data/fermate.csv
```

Le mappe usano OpenStreetMap tramite `flutter_map`, senza chiavi. Per la pubblicazione si può passare a un fornitore di mappe con quota garantita.
