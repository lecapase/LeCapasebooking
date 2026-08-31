# Le Capase Booking

Sistema Flutter/Firebase per la prenotazione pubblica e la gestione interna delle
prenotazioni del ristorante Le Capase.

## Applicazioni

Il repository produce due webapp distinte:

- **Gestionale** (`lib/main.dart`): accesso autenticato per staff, supervisor,
  manager e amministratori.
- **Booking pubblico** (`lib/main_booking.dart`): prenotazione cliente in italiano
  e inglese.

È presente anche `lib/main_customer.dart`, entry point storico dell'app cliente.

## Funzionalità principali

- gestione prenotazioni, disponibilità, capienza e chiusure;
- agenda cucina e dashboard;
- ruoli e account del personale;
- autenticazione biometrica sulle piattaforme supportate;
- notifiche push con Firebase Cloud Messaging;
- conferme e aggiornamenti via email;
- messaggi e riconferme via WhatsApp/360dialog;
- contatti marketing e consensi;
- interfaccia pubblica bilingue.

## Stack

- Flutter 3.44 / Dart 3.12;
- Firebase Authentication, Firestore, Functions, Hosting, Messaging e App Check;
- Cloud Functions Node.js 24;
- Nodemailer e API 360dialog.

## Preparazione locale

Requisiti:

- Flutter stabile compatibile con Dart `^3.12.2`;
- Node.js 24 per le Cloud Functions;
- Firebase CLI autenticata sul progetto autorizzato.

```powershell
flutter pub get
cd functions
npm ci
cd ..
```

Le versioni Flutter sono bloccate da `pubspec.lock`; le versioni Node da
`functions/package-lock.json`.

## Controlli

```powershell
flutter analyze
flutter test
node --check functions/index.js
node --check functions/staff_users.js
```

## Build Web

```powershell
flutter build web --release --target lib/main.dart --output build/web_gestionale
flutter build web --release --target lib/main_booking.dart --output build/web_booking
```

Le directory corrispondono ai target definiti in `firebase.json`.

## Deploy

Consultare [docs/OPERATIONS.md](docs/OPERATIONS.md) prima di un deploy. Non
eseguire un deploy direttamente da un working tree non pulito o senza avere
verificato entrambe le build.

## Struttura essenziale

```text
lib/
  features/              schermate e funzionalità Flutter
  services/              notifiche, biometria, App Check e chiamate backend
  main.dart              gestionale
  main_booking.dart      booking pubblico
functions/
  index.js               notifiche, email, WhatsApp e automazioni
  staff_users.js         account staff e operazioni amministrative
firestore.rules          autorizzazioni Firestore
storage.rules            autorizzazioni Storage
firebase.json            build target e configurazione Firebase
```

## Sicurezza

I segreti non devono essere inseriti nel repository. Le Functions utilizzano
Firebase Secret Manager con i nomi documentati in `docs/OPERATIONS.md`.
`google-services.json` e `firebase_options.dart` contengono identificatori della
configurazione Firebase client, non credenziali amministrative.
