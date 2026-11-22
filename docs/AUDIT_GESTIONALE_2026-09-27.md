# Verifica generale del gestionale — 27 settembre 2026

## Aggiornamento successivo: correzioni

I tre problemi P1 descritti sotto sono stati corretti nel codice e coperti da
test di regressione. Sono stati corretti anche i conteggi Pranzo/Cena, la data
mobile e i timeout; aggiunti avvisi di capienza e identità dell'operatore;
ottimizzate le letture operative e il riuso dello storico. Regole, funzioni interessate e gestionale pubblicati con successo.
Il resto di questo documento conserva le osservazioni dell'audit precedente.

Il gestionale carica correttamente, ma sono stati riprodotti tre difetti prioritari.
Il superamento della suite esistente non copreva questi casi.

## Controlli eseguiti

- `flutter analyze --no-pub`: nessun problema.
- `flutter test --no-pub`: 40 test superati.
- Suite Node completa nell'emulatore: 25 voci superate, ossia 22 test server
  e 3 script Firestore con 268 controlli complessivi (14 + 37 + 217).
- Controllo sintattico di index, staff_users, marketing_consents e review_automation.
- Browser sul gestionale pubblicato, con sessione amministratore già presente:
  Servizio, menu Altro, Clienti, ricerca senza risultati, Report mensile,
  Richieste recensione e modulo Nuova prenotazione.
- Modulo Nuova prenotazione anche a 390 × 844: nessuna sovrapposizione evidente.
- Nessun errore o avviso rilevato nella console durante le schermate osservate.
- Nessuna prenotazione creata, nessuna notifica/email inviata, nessuna impostazione
  modificata in produzione. Le riproduzioni usano soltanto dati sintetici locali.

## Problemi prioritari

### P1 — Contatore coperti incrementabile senza una nuova prenotazione

**Riprodotto nell'emulatore.** Due aggiornamenti anonimi riferiti alla stessa
prenotazione già esistente ricevono entrambi HTTP 200 e portano il contatore da
2 a 4 e poi a 6, senza creare altre prenotazioni.

`firestore.rules:446`, `validUpdatedCounter`, verifica che la prenotazione esista
dopo la scrittura, ma non che sia nuova e creata nella stessa operazione atomica.
Anche `validNewCounter` richiede una revisione analoga.

Impatto: chi conosce l'ID di una propria prenotazione può falsare i coperti e
ridurre artificialmente la disponibilità. Il contatore pubblico contiene inoltre
`lastBookingId`.

Correzione proposta: vincolare incremento, identità del contatore e creazione
della prenotazione a una sola transazione; negare riutilizzi di prenotazioni
preesistenti e aggiungere un test che richieda HTTP 403 al secondo incremento.

### P1 — Agenda cucina accessibile con un vecchio privilegio amministratore

**Riprodotto nell'emulatore.** Un account con `staff_users.active=false` e vecchio
documento `admins` attivo ottiene una prenotazione sintetica da `getKitchenAgenda`.

`functions/staff_users.js:826`, `userCanViewBookings`, controlla prima il profilo
storico e restituisce `true` senza verificare quello corrente. Le altre API
amministrative sono state corrette; questo helper distinto è rimasto escluso.

Impatto: se la sincronizzazione dei profili è in ritardo o fallisce, un account
revocato con sessione ancora utilizzabile può leggere nomi, orari e note cucina.
La prova ha invocato il gestore locale con contesto autenticato sintetico; non
ha tentato accessi con credenziali revocate in produzione.

Correzione proposta: dare precedenza al profilo staff anche qui e usare un'unica
politica condivisa per tutte le API.

### P1 — Disattivazione account non esclude le notifiche push

**Riprodotta la selezione errata dei destinatari, senza invii.** Il token sintetico
di un account disattivato viene restituito da `getNotificationTokens`.

`functions/index.js:359` raccoglie tutti i token di `notification_devices` e
`admins` senza verificare il ruolo o l'attivazione dell'utente. La disattivazione
e la cancellazione dello staff non ripuliscono `notification_devices`; anche il
logout (`lib/app.dart:505`) esegue solo il sign-out Firebase.

Impatto: un dispositivo con token ancora valido può continuare a ricevere nome,
data, orario e coperti dopo la revoca dell'accesso.

Correzione proposta: filtrare i destinatari in base ai privilegi correnti e
gestire esplicitamente i token alla disattivazione, cancellazione e uscita.

## Interfaccia e prestazioni

### P2 — Conteggio delle prenotazioni incoerente con il servizio selezionato

**Osservato nel browser.** Con Pranzo selezionato e zero prenotazioni visibili,
compare `Attive (2)`. Il conteggio include anche Cena.

In `lib/features/bookings/bookings_screen.dart:4832` il badge usa
`activeForDate.length`, mentre la lista applica il filtro del servizio.
Applicare lo stesso filtro ai conteggi e rendere il testo vuoto esplicito:
“Nessuna prenotazione per Pranzo”, anziché “per questa data”.

### P2 — Lettura dell'intero archivio a ogni apertura

**Accertato dal codice; impatto su grandi volumi non misurato.**
`lib/features/bookings/bookings_screen.dart:4702` sottoscrive tutte le
prenotazioni senza filtro temporale. Clienti e report leggono tutte le pagine
dell'archivio con `loadBookingHistory`.

Miglioramento: limitare le query operative alla finestra necessaria, caricare lo
storico su richiesta e introdurre aggregati per clienti/report. Riduce traffico,
letture Firestore e lavoro sul dispositivo al crescere dello storico.

### P2 — Richieste server senza timeout esplicito

**Accertato dal codice; mancata risposta non simulata.**
`lib/services/callable_http_service.dart:44` non impone un timeout alla POST.
Il login attende inoltre `notifyStaffLogin` prima di chiudere il dialogo.

Miglioramento: timeout con errore comprensibile e nuova prova controllata;
separare la notifica di accesso dal completamento del login. Evitare retry
automatici delle operazioni con effetti senza una chiave di idempotenza.

### Miglioramenti operativi

- Mostrare un avviso prima di superare la capienza nelle aggiunte manuali,
  negli aumenti coperti e nelle riattivazioni. Ora questi percorsi aggiornano il
  contatore senza confrontarlo con la capienza del servizio. Un eventuale
  superamento volontario deve essere distinguibile da un errore.
- Registrare UID e ruolo dell'operatore nelle modifiche: attualmente campi come
  `arrivedBy` e `cancelledBy` riportano genericamente `admin` anche per altri ruoli.
- Su mobile mostrare la data completa: a 390 px il selettore mostra
  “dom 27 settem...”.
- Aggiungere test dei flussi UI e delle revoche a sessione aperta, oltre ai test
  di modelli e regole già presenti.

## Modifiche effettuate durante il controllo

Allineato `functions/marketing_consents.integration.test.js` ai permessi già
pubblicati: l'amministratore può gestire i consensi; manager, staff e account
disattivati devono essere rifiutati. Il test prima presumeva ancora l'accesso
manager e falliva per questo motivo.

Aggiunto `docs/reproduce_access_findings.cjs`: riproduttore diagnostico vincolato
all'emulatore, non test di regressione. Stampa il risultato atteso e quello
osservato dei tre problemi P1. Un'uscita 0 significa che la diagnosi è terminata,
non che i difetti siano risolti.

Durante l'audit iniziale non erano stati pubblicati aggiornamenti né corretti i
problemi P1; vedere l'aggiornamento in apertura per le correzioni successive.
Resta rispettata la scelta dell'utente di mantenere accessibili
allo staff autorizzato i dati operativi delle prenotazioni.

## Limiti

Non sono stati provati invii reali email/WhatsApp/push, operazioni distruttive,
salvataggi di prenotazioni in produzione, login con tutti i ruoli, browser
offline, prestazioni sotto carico o app native. I permessi dei diversi ruoli
sono stati verificati attraverso test locali, non con account reali aggiuntivi.
