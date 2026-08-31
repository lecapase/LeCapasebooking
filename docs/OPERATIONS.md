# Operazioni e deploy

## Ambienti e target

Il progetto Firebase predefinito è `lecapase-booking-3af33` e dispone di due
target Hosting:

| Target | Directory | Entry point |
| --- | --- | --- |
| `gestionale` | `build/web_gestionale` | `lib/main.dart` |
| `booking` | `build/web_booking` | `lib/main_booking.dart` |

Prima di lavorare verificare sempre:

```powershell
git status --short --branch
firebase use
flutter --version
firebase --version
```

## Segreti delle Cloud Functions

Le Functions fanno riferimento ai seguenti segreti Firebase:

- `GMAIL_USER`
- `GMAIL_APP_PASSWORD`
- `DIALOG360_API_KEY`
- `DIALOG360_WEBHOOK_TOKEN`

I valori non devono essere salvati in file del repository, nei log o nella
documentazione. Per controllarne la presenza usare la Firebase CLI con un account
autorizzato.

## Checklist prima del deploy

1. Working tree pulito o modifiche revisionate e committate.
2. `flutter pub get` completato senza modifiche inattese al lockfile.
3. `flutter analyze` esaminato.
4. `flutter test` superato.
5. Controllo sintattico delle Functions superato.
6. Build Release di entrambi i target completata.
7. Conferma del progetto Firebase selezionato.
8. Backup o tag Git del commit attualmente in produzione.

## Build

```powershell
flutter build web --release --target lib/main.dart --output build/web_gestionale
flutter build web --release --target lib/main_booking.dart --output build/web_booking
```

## Deploy selettivo

Preferire deploy separati, così da ridurre l'area interessata:

```powershell
firebase deploy --only hosting:gestionale
firebase deploy --only hosting:booking
firebase deploy --only functions
firebase deploy --only firestore:rules,storage
```

Non distribuire Functions o regole quando la modifica riguarda soltanto la UI.

## Verifica dopo il deploy

- aprire il booking pubblico in una sessione anonima;
- controllare caricamento di servizi e disponibilità;
- aprire il gestionale con un account autorizzato;
- controllare dashboard e lista prenotazioni;
- monitorare i log Functions per errori nuovi;
- non creare prenotazioni di prova in produzione senza poi identificarle e
  rimuoverle con la procedura operativa prevista.

## Ripristino

Per il solo Hosting si può ricostruire un commit noto e ridistribuire il target
interessato. Per il codice:

```powershell
git switch --detach <commit-stabile>
flutter pub get
flutter build web --release --target lib/main.dart --output build/web_gestionale
flutter build web --release --target lib/main_booking.dart --output build/web_booking
```

Distribuire esclusivamente il target da ripristinare. Non usare `git reset
--hard` sulla directory di lavoro principale.

Un bundle Git si ripristina in una nuova directory con:

```powershell
git clone LeCapaseBooking-all-refs.bundle LeCapaseBooking-ripristinato
```

## Dati Firebase

Il backup Git protegge il codice, non i documenti Firestore, gli utenti
Authentication o i segreti. La loro conservazione deve essere gestita tramite le
procedure di backup ed esportazione Firebase/GCP previste per l'ambiente.
