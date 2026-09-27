# Consensi marketing

## Stati e provenienza

La scheda cliente distingue Email e WhatsApp. Un booleano senza data,
provenienza e versione non autorizza l'invio. I consensi precedenti documentati
restano utilizzabili; `marketingOptOutAt` resta una revoca di entrambi i canali.
Le nuove revoche sono specifiche per canale e hanno priorità su qualsiasi flag.
Una prenotazione successiva non riattiva un canale revocato. La riattivazione
richiederà un futuro flusso dedicato di conferma del contatto.

Le Functions registrano le modifiche nella sottocollezione `consent_events`;
il personale non può scrivere direttamente i profili né il registro.
Il gestionale mostra gli ultimi 50 eventi; il registro completo resta conservato.
Non si ricostruiscono eventi storici mancanti. Le preferenze del cliente e le
comunicazioni operative delle prenotazioni non sono consensi promozionali.

## Testi conservati

Versione 1.0 (scelta unica):

- IT: Desidero ricevere offerte, eventi e promozioni di Le Capase tramite email e WhatsApp (facoltativo).
- EN: I would like to receive Le Capase offers, events and promotions by email and WhatsApp (optional).

Versione 2.0 (due scelte indipendenti, inizialmente non selezionate):

- Email IT: Desidero ricevere offerte, eventi e promozioni di Le Capase tramite email (facoltativo).
- Email EN: I would like to receive Le Capase offers, events and promotions by email (optional).
- WhatsApp IT: Desidero ricevere offerte, eventi e promozioni di Le Capase tramite WhatsApp (facoltativo).
- WhatsApp EN: I would like to receive Le Capase offers, events and promotions by WhatsApp (optional).

## Revoche e invii

Manager e Amministratore possono registrare una richiesta di disiscrizione.
Le email promozionali includono un link con token casuale, conservato sul server
solo come hash. Il GET mostra la conferma; solo il POST revoca, così gli scanner
dei link non disiscrivono il destinatario. Lo STOP WhatsApp revoca solo WhatsApp,
anche quando non esiste ancora un profilo. Le revoche bloccano l'indirizzo anche
su altri profili tramite `marketing_suppressions`.

Il server rilegge il consenso immediatamente prima dell'invio di ciascun canale.
Una comunicazione già consegnata al provider non può essere ritirata.
Nessuna campagna o messaggio viene inviato dai test.

## Verifica e pubblicazione

- `node --test functions/consent_policy.test.js`
- Con emulatore locale: `node --test functions/marketing_consents.integration.test.js`
- Con emulatore locale: `node test/firestore/consent_rules_test.cjs`
- `flutter analyze`, `flutter test` e build web dei due target.

Per pubblicare: nuove Functions `getCustomerConsents`, `revokeCustomerConsent`,
`marketingUnsubscribe` e aggiornamenti a `onCustomerBookingCreated`,
`sendMarketingCampaign`, `dialog360Webhook`; poi le regole Firestore e i due
target Hosting. Le regole mantengono compatibilità con il modulo 1.0.
Coordinare l'aggiornamento del gestionale con le regole: la vecchia azione di
rimozione marketing scrive direttamente sul profilo e viene bloccata dalle
nuove regole. Ricaricare il gestionale dopo il deploy.
