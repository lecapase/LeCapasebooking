# Verifica notifiche — 27 settembre 2026

## Comportamento aggiornato su richiesta dell'utente

La lettura non rimuove più gli avvisi: restano con opacità 65%, mantenendo titolo e ordine. La lettura salva anche la permanenza nella coda, indipendente dal mese del servizio visualizzato.
Il clic sulla scheda apre giorno e servizio della prenotazione e registra la lettura. Eliminato il pulsante «Apri nel servizio».
Lo scorrimento a sinistra mostra «ELIMINA»; solo il clic su questo pulsante rimuove l'avviso dalla coda condivisa. La prenotazione resta intatta. Una nuova risposta successiva alla rimozione torna visibile; la transazione impedisce di eliminare una risposta arrivata dopo la visualizzazione.
Verifiche aggiornate: 48 test Flutter superati e 299 controlli Firestore, inclusi 20 su lettura/rimozione per ruolo. Test widget specifico: swipe senza eliminazione, poi eliminazione solo con pulsante; test della permanenza dopo lettura e ricomparsa di un nuovo evento.

Le note sulla scomparsa automatica delle notifiche lette nella verifica iniziale sotto sono superate da questa modifica.

Aggiornamento pubblicato su Hosting gestionale e regole Firestore. Verifica online a 390×844: schede lette attenuate, pulsante «Apri nel servizio» assente, console senza errori. Nessuna notifica reale eliminata durante la verifica.

### Aggiornamento immediato del contatore

Il clic registra ora localmente la lettura dell'evento prima di attendere Firestore: badge, contatore nella pagina e opacità usano lo stesso stato. In caso di errore viene ripristinato il conteggio; una nuova risposta non eredita la lettura precedente. La lettura multipla aggiorna il conteggio a ogni salvataggio riuscito. Analisi senza problemi e 14 test delle prenotazioni superati, inclusi due nuovi casi per decremento immediato, ripristino e nuove risposte.

### Correzione letture singole — 28 settembre

Ottimizzazione eliminazione multipla: sostituito il ciclo sequenziale con sei richieste concorrenti al massimo, mantenendo le transazioni e la verifica dell'evento. Avanzamento visibile per ogni completamento; errori isolati e notifiche non eliminate ancora selezionate. Analisi pulita e 19 test delle prenotazioni superati; il test di concorrenza verifica limite sei, avanzamento prima della fine e completamento degli altri elementi dopo un errore. Non effettuate cancellazioni reali per misurare la latenza.

Selezione multipla aggiunta: «Seleziona», caselle sulle singole schede, «Elimina selezionate (N)» e «Annulla selezione». In questa modalità il clic cambia la selezione senza aprire il servizio né segnare letto. Rimozione condivisa riservata agli stessi ruoli già abilitati; snapshot al momento della selezione per non eliminare risposte successive. Gli errori lasciano gli elementi selezionati e indicano quante rimozioni sono riuscite. Nessuna prenotazione viene eliminata.

Segnalazione: apertura del servizio funzionante, decremento solo con «Segna tutte». Corretti due casi riproducibili nei test: un evento già letto sul server restituiva false e annullava l'aggiornamento locale; vecchie risposte riconfermate e lette senza il campo adminNotificationRead venivano considerate non lette. La lettura parte inoltre prima della validazione della data di navigazione.

18 test delle prenotazioni superati. Il nuovo test widget usa schede reali e transazioni simulate: clic singoli, salvataggio, apertura del servizio, ritorno e decremento 2→1→0 senza pulsante globale. Conservata la protezione da nuove risposte concorrenti. Online tutte le notifiche risultavano già lette, quindi non è stato riprodotto il caso con un nuovo avviso di produzione; nessun invio o prenotazione di prova creati.

## Problemi corretti

- Apri nel servizio selezionava il turno in base all'ora corrente, invece di quello della prenotazione. Ora apre il turno effettivo e la sezione storico per gli stati conclusi.
- Staff e supervisor vedevano azioni di lettura che le regole negavano. La lettura condivisa è ora modificabile solo da amministratori e manager; gli altri ruoli consultano senza tentare scritture.
- Richieste e riconferme di giornate passate già lette restavano nella pagina. Ora sono escluse; gli avvisi non letti restano disponibili.
- Una nuova richiesta di riconferma poteva ereditare la lettura della prenotazione. Ora si confrontano invio e lettura.
- Una lettura da una scheda obsoleta poteva consumare una nuova risposta o ricreare un documento eliminato. Ora la transazione verifica esistenza e identità dell'evento prima di aggiornare.
- La lettura multipla impedisce clic ripetuti e riporta letture salvate ed errori. Le schede distinguono «Da leggere» e «Letta dal team». Le richieste correnti restano visibili finché gestite.
- Titoli temporali aggiornati ogni minuto durante la consultazione della pagina.
- Il service worker mostrava manualmente anche notifiche già visualizzate da FCM: eliminata la doppia visualizzazione. Il clic apre `/?view=notifications`.
- Rinnovo token e inizializzazione nativa rispettano la disattivazione del dispositivo. Aggiunta navigazione dalle notifiche native nel codice; serve una nuova distribuzione dell'app per gli utenti Android.
- La ripetizione del trigger di creazione non azzera più lo stato letto della prenotazione. Non è una garanzia di consegna push esattamente una volta.

## Verifiche

- Analisi Flutter: nessun problema.
- 46 test Flutter superati, inclusi tre test della politica notifiche.
- 29 test/script Node superati, inclusi due test del service worker e 279 controlli Firestore.
- Altri 10 controlli specifici: lettura notifiche correnti/passate consentita ad admin e manager, negata a supervisor, staff e account inattivi.
- Build web release completata.
- Nessuna prenotazione reale modificata e nessuna push di prova inviata. La consegna su dispositivo fisico e l'apertura dell'app Android non sono state provate.

Riferimento FCM: [ricezione messaggi web](https://firebase.google.com/docs/cloud-messaging/web/receive-messages).

Backup precedente alla modifica: `build/gestionale-before-notifications-20260927.zip`.

## Pubblicazione e verifica finale

Pubblicati con successo Hosting `gestionale` e funzione `onNewBooking`.
Verificato il collegamento diretto online: apre Notifiche, con quattro avvisi ancora da leggere e badge coerente. Le vecchie richieste già lette non compaiono più. Nessun avviso è stato segnato letto durante il controllo.
Layout verificato a 1280×720 e 390×844; nessun errore/warning nella console del browser. Screenshot parziale senza nominativi: `build/verification-notifications-mobile.png`.
