# Architettura

## Frontend gestionale

`lib/main.dart` inizializza Firebase e App Check e avvia `LeCapaseApp`. Il flusso
di accesso verifica Firebase Authentication, il profilo staff, lo stato attivo e
il ruolo. Sulle piattaforme supportate può essere applicato il gate biometrico.

Le aree principali si trovano in `lib/features`:

- `bookings`: elenco, calendario e gestione delle prenotazioni;
- `availability`: servizi, disponibilità ed eccezioni;
- `agenda`: agenda cucina;
- `contacts`: contatti e campagne marketing;
- `staff`: amministrazione degli account;
- `dashboard`, `home`, `settings` e `tables`: navigazione gestionale.

## Frontend pubblico

`lib/main_booking.dart` avvia la UI pubblica bilingue. I repository sotto
`lib/features/customer_booking/data` gestiscono disponibilità, capacità e
creazione delle prenotazioni.

## Backend

Le Cloud Functions reagiscono alla creazione e agli aggiornamenti delle
prenotazioni, inviano comunicazioni, gestiscono riconferme pianificate e
operazioni protette sugli account staff. Le operazioni privilegiate sono esposte
come callable function o trigger server-side.

## Dati e autorizzazioni

Firestore contiene, tra le altre, collezioni per prenotazioni, disponibilità,
contatori di capacità, profili cliente, utenti staff e dispositivi di notifica.
Le regole applicano autorizzazioni per ruolo e terminano con un deny predefinito.

Storage è chiuso all'accesso diretto dei client. Eventuali operazioni sui file
devono passare da codice server autorizzato.

## Comunicazioni

- email: Nodemailer con credenziali conservate in Firebase Secret Manager;
- WhatsApp: API 360dialog con chiave e token webhook in Secret Manager;
- push: Firebase Cloud Messaging e notifiche locali Flutter.

## Principio di manutenzione

Il sistema è operativo in produzione. Le modifiche devono essere piccole,
reversibili e distribuite per componente. I file monolitici vanno separati solo
durante interventi funzionali coperti da una verifica mirata, evitando un grande
refactoring contemporaneo.
