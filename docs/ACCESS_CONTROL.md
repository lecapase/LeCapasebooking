# Accesso alle sezioni riservate

Clienti, report mensili, recensioni, marketing, utenti e impostazioni sono
riservati agli amministratori attivi. Le schermate verificano il profilo corrente
e smontano il contenuto quando l'account perde il ruolo o viene disconnesso.

Le regole Firestore riservano agli amministratori le raccolte clienti, profili,
marketing, eventi email e richieste recensione. Le API di consensi e recensioni
verificano autonomamente i privilegi. Un documento `staff_users` esistente
prevale sempre sul documento storico `admins`, anche quando disattivato.

## Limite dei dati operativi

Gli utenti operativi autorizzati possono ancora leggere `bookings`, compresi
telefono, email, note e storico. Clienti e report sono ricavati anche da questi
documenti: proteggere le relative schermate non impedisce di ricostruire quei
dati con accesso diretto alle prenotazioni.

Per escludere questi dati dai ruoli operativi occorre separare i campi privati
in documenti riservati agli amministratori e fornire una vista operativa ridotta,
aggiornando letture, scritture e dati esistenti. Le regole Firestore non possono
nascondere singoli campi di un documento leggibile.

## Verifiche

- `test/firestore/review_rules_test.cjs`: accessi diretti ed elenchi, scritture
  negate, ruoli sconosciuti/disattivati e vecchi privilegi amministrativi.
- `functions/review_requests.integration.test.js`: API recensioni e consensi,
  inclusi account declassati con un vecchio documento amministratore attivo.
- `flutter analyze` e `flutter test`.
