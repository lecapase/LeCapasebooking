# Richieste recensione con autorizzazione

Link fornito: https://g.page/r/CVT1Lz6T5_JyEBM/review
Nome usato nei messaggi: **Le Capase**.

## Flusso definitivo

1. L'interruttore abilita soltanto la preparazione, non l'invio.
2. Alle 11 Europe/Rome `prepareReviewRequests` prepara le visite del giorno
   precedente in stato `released` o `completed`, con email e consenso valido.
3. Crea una giornata `pending` in `review_batches`. Questo documento alimenta
   una notifica persistente in tempo reale nel gestionale di tutti gli
   amministratori, su desktop e mobile. Se il gestionale è chiuso, l'avviso
   appare al prossimo accesso; non è una notifica push esterna.
4. Un amministratore apre **Richieste recensione**, controlla destinatari,
   testo e link e preme **Autorizza invio**, confermando. Basta uno degli
   amministratori; manager e staff non possono autorizzare né configurare.
5. `approveReviewBatch` registra identità, data e ora dell'autorizzazione e
   il link approvato. Non invia email direttamente.
6. `sendApprovedReviewBatch` prende in carico una sola volta la giornata e
   ricontrolla consensi, indirizzi, stati e sospensione prima di ogni invio.

Senza approvazione non parte alcuna email. I destinatari non vengono ampliati
dopo l'approvazione; se un indirizzo cambia, l'invio viene saltato. Non esistono
filtri legati alla soddisfazione né invii selettivi dalla UI. Le giornate non
approvate restano in attesa, senza scadenza automatica; i controlli vengono
ripetuti anche quando un amministratore autorizza in un giorno successivo.

## Consensi, frequenza e registro

Si riutilizzano consenso email documentato, revoche e blocchi per contatti
duplicati delle campagne. I messaggi sono neutri, in italiano o inglese, e
includono il link di disiscrizione. Nessun invio WhatsApp è implementato.

Una transazione riserva la prenotazione in `review_requests` e il contatto
in `review_contact_limits`, sia per email sia per telefono. Massimo un invito
per prenotazione e uno per contatto ogni 90 giorni dal tentativo riservato,
anche in caso di successivo errore: scelta conservativa contro i duplicati.

SMTP non offre invii esattamente una volta. Gli errori ambigui restano
`uncertain`; un arresto può lasciare `processing` o una giornata `sending`.
La giornata passa a `attention` se il processo rileva un problema. Non viene
re-inviata automaticamente: verificare i log prima di un intervento manuale.
`sent` significa accettazione del servizio email, non consegna o recensione.
La sospensione non ritira email già affidate al provider.

Il registro mostra gli ultimi 100 eventi, tutte le giornate ancora in attesa
e le 30 più recenti. La preparazione può ritentare per errori infrastrutturali,
ma non invia messaggi e non duplica una giornata già preparata.

## Test e pubblicazione

- `node --test functions/review_requests.test.js`
- Con Firestore locale: `node --test functions/review_requests.integration.test.js`
- Test regole: `node test/firestore/review_rules_test.cjs`
- Analisi/test Flutter e build web.

I test usano solo emulatori e un trasporto email simulato. Nessun messaggio
reale e nessuna inizializzazione di dati di produzione durante lo sviluppo.

Distribuire `getReviewAutomation`, `updateReviewAutomation`,
`prepareReviewRequests`, `approveReviewBatch`, `sendApprovedReviewBatch`,
regole Firestore e Hosting gestionale. Solo gli amministratori possono leggere
`review_batches`; tutte le scritture avvengono nelle Functions. Gli altri
documenti interni non sono accessibili direttamente ai client.
Alla pubblicazione la preparazione rimane disattivata finché un amministratore
non la abilita esplicitamente dal gestionale.
