// Uso: supabase start, poi SB_URL=http://127.0.0.1:54321 SB_ANON=<anon key> SB_SERVICE=<service role key> npm test
// Prova end-to-end contro Supabase locale: utenti reali, RLS, funzioni, tempo reale.
import { createClient } from '@supabase/supabase-js';
const URL = process.env.SB_URL, ANON = process.env.SB_ANON, SERVICE = process.env.SB_SERVICE;
const admin = createClient(URL, SERVICE, { auth: { persistSession: false } });
const ok = (c, m) => { if (!c) { console.error('FALLITO:', m); process.exit(1); } console.log('ok -', m); };

async function utente(email, nome) {
  await admin.auth.admin.createUser({ email, password: 'password123', email_confirm: true, user_metadata: { nome } });
  const c = createClient(URL, ANON, { auth: { persistSession: false } });
  const { error } = await c.auth.signInWithPassword({ email, password: 'password123' });
  if (error) throw error;
  return c;
}
const giorno = (() => { const d = new Date(); d.setDate(d.getDate() + ((8 - (d.getDay() || 7)) % 7 || 7)); return d.toISOString().slice(0, 10); })();

const pass = await utente('mario@azienda.it', 'Mario Rossi');
const pass2 = await utente('lucia@azienda.it', 'Lucia Bianchi');
const aut = await utente('gino@azienda.it', 'Gino Autista');
let r = await pass.rpc('prenota', { p_data: giorno, p_fermata_id: 2 });
ok(r.error?.message.includes('approvato'), 'non approvato bloccato: ' + r.error?.message);
await admin.from('profili').update({ approvato: true }).neq('email', 'x');
await admin.from('profili').update({ ruolo: 'autista' }).eq('email', 'gino@azienda.it');
const { data: f } = await pass.from('fermate').select('id,ordine,nome').eq('linea_id', 1).eq('tratta', 'andata').order('ordine');
ok(f.length === 23, 'il passeggero legge 23 fermate della linea 1');
r = await pass2.rpc('prenota', { p_data: giorno, p_fermata_id: f[15].id }); ok(!r.error, 'Lucia prenota ' + f[15].nome);
r = await pass.rpc('prenota', { p_data: giorno, p_fermata_id: f[1].id }); ok(!r.error, 'Mario prenota ' + f[1].nome);
const corsaId = r.data.corsa_id;
r = await pass.from('prenotazioni').select('*'); ok(r.data.every(p => p.utente_id === r.data[0].utente_id), 'Mario vede solo le sue prenotazioni');
r = await pass.from('profili').update({ ruolo: 'admin' }).eq('email', 'mario@azienda.it'); ok(r.error, 'Mario non puo\' promuoversi');

// tempo reale: Mario ascolta la posizione
const ricevute = [];
const ch = pass.channel('t').on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'posizioni', filter: `corsa_id=eq.${corsaId}` }, p => ricevute.push(p.new)).subscribe();
await new Promise(res => setTimeout(res, 2500));
r = await aut.rpc('avvia_corsa', { p_linea: 1, p_data: giorno, p_tratta: 'andata', p_posti: 1 }); ok(!r.error && r.data.stato === 'in_corso', 'autista avvia con 1 posto');
r = await aut.rpc('lista_corsa', { p_corsa_id: corsaId });
ok(r.data.length === 2 && r.data.find(x => x.ha_posto).nome === 'Mario Rossi', 'andata: il posto va a chi sale prima (Mario)');
r = await pass2.rpc('lista_corsa', { p_corsa_id: corsaId }); ok(r.data.length === 1 && r.data[0].ha_posto === false, 'Lucia vede solo la sua riga: senza posto');
r = await aut.from('posizioni').insert({ corsa_id: corsaId, lat: 45.82, lng: 8.76 }); ok(!r.error, 'autista invia posizione');
r = await pass.from('posizioni').insert({ corsa_id: corsaId, lat: 1, lng: 1 }); ok(r.error, 'passeggero non puo\' inviare posizioni');
await new Promise(res => setTimeout(res, 3000));
ok(ricevute.length === 1 && ricevute[0].lat === 45.82, 'Mario riceve la posizione in tempo reale');
await pass.removeChannel(ch);
r = await aut.rpc('concludi_corsa', { p_corsa_id: corsaId }); ok(!r.error, 'corsa conclusa');
console.log('FLUSSO COMPLETO SUPERATO');
process.exit(0);
