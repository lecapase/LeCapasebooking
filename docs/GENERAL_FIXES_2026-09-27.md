# Correzioni successive all'audit

## Autorizzazioni e integrità

- Incremento anonimo del contatore consentito solo se la prenotazione non esiste
  prima dell'operazione, esiste dopo la transazione e il contatore ha l'ID corretto.
  L'orario di aggiornamento deve essere quello del server.
- Agenda cucina e selezione dei destinatari push usano `access_policy.js`:
  il profilo staff corrente prevale sui vecchi privilegi amministrativi.
- Account disattivati, sconosciuti o eliminati non sono destinatari push.
  I record dispositivi vengono eliminati alla disattivazione e cancellazione;
  il logout rimuove il token del dispositivo e ne richiede l'invalidazione a FCM.
- L'Agenda cucina resta fuori dal menu. I dati operativi restano visibili allo
  staff autorizzato, secondo la scelta già confermata dall'utente.
- Inserimenti manuali e modifiche di stato, coperti e orario registrano UID e
  ruolo dell'operatore. Le regole rifiutano identità falsificate negli aggiornamenti.

## Uso quotidiano

- I conteggi Attive/Passate seguono il servizio selezionato.
- La data nel modulo manuale va a capo e rimane leggibile su mobile.
- Timeout di 30 secondi sulle chiamate HTTP, con indicazione di controllare
  l'esito prima di ripetere operazioni. Nessun retry automatico delle scritture.
- La notifica di accesso non ritarda più la chiusura del login.
- Aggiunte manuali, aumenti di coperti e riattivazioni richiedono conferma quando
  superano il limite online configurato. La conferma vale fino al totale mostrato:
  se una modifica concorrente lo supera, viene richiesta una nuova conferma.
  Le riduzioni non richiedono conferma; lo storico non attiva l'avviso.
  Il limite è quello online esistente, non un nuovo parametro di capienza fisica.
- Il modulo manuale resta bloccato durante il salvataggio e i dati da salvare
  vengono catturati prima delle attese asincrone.

## Prestazioni

- Il feed operativo ascolta il mese selezionato con margine per le settimane
  adiacenti, più quattro query per le notifiche da gestire anche fuori periodo.
  Deduplica i documenti e cancella i listener quando si cambia periodo o schermata.
- Clienti e report condividono per due minuti una cache in memoria per account;
  Aggiorna rilegge il server. Modifiche operative e logout invalidano la cache.
- Lo storico completo è ancora letto alla prima apertura o all'aggiornamento,
  per conservare l'esattezza di visite e clienti di ritorno. Non sono stati
  introdotti aggregati persistenti né migrazioni di dati.

## Verifiche

- Analisi Flutter: nessun problema.
- 43 test Flutter superati, inclusi superamento, riduzione e concorrenza coperti.
- 23 test server e 4 script Firestore superati: 279 controlli delle regole.
- Nuove regressioni: replay contatore, identità del contatore, agenda con account
  revocato, destinatari push disattivati/eliminati, falsificazione dell'operatore.
- Build release riuscita sia del gestionale sia del booking pubblico.
- Backup web prima delle correzioni: `build/gestionale-before-general-fixes-20260927.zip`.
- Copia dei sorgenti corretti: `build/general-fixes-source-20260927.zip`.

Stato distribuzione: completata con successo su lecapase-booking-3af33. La verifica live non crea prenotazioni né invia
messaggi reali; le scritture sono verificate soltanto nell'emulatore.

Verifica live conclusa: Pranzo mostra Attive (0) correttamente, il calendario
carica settembre e agosto, la data del modulo mobile è interamente visibile a
390 px. Nessun errore o avviso rilevato in console durante queste verifiche.
Il riproduttore originale ora restituisce 403 per entrambi i replay, mantiene
il contatore a 2, nega l'agenda all'account revocato ed esclude il token disattivato.
