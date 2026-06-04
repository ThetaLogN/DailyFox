# DailyFox 🦊

**DailyFox** è un'applicazione diario personale moderna e intuitiva sviluppata in Flutter. Permette agli utenti di tenere traccia del proprio umore quotidiano inserendo una valutazione numerica, un'emoji rappresentativa e una parola chiave. L'applicazione incoraggia la costanza quotidiana attraverso un sistema di traguardi e badge sbloccabili basati sugli "streak" (giorni consecutivi di compilazione).

---

## 🚀 Funzionalità Principali

- **Diario Quotidiano**: Registra e modifica la valutazione della tua giornata (da 1 a 10), associa un'emoji e scrivi una breve parola chiave riassuntiva.
- **Statistiche & Grafici Interattivi**:
  - Andamento dell'umore nel tempo.
  - Distribuzione delle emoji utilizzate.
  - Parole chiave più frequenti.
  - Statistiche mensili e andamento settimanale.
- **Calendario Storico**: Visualizza e consulta le entry del passato in modo semplice e veloce.
- **Sistema di Traguardi (Streak)**: Calcola i giorni di registrazione consecutivi e sblocca badge speciali e animati per celebrare la tua costanza.
- **Widget per la Home Screen**: Widget nativo per iOS e Android che mostra la media dei tuoi ultimi voti, l'emoji del giorno e la parola chiave attuale.
- **Notifiche Intelligenti**: Tre notifiche di promemoria giornaliere pianificate (alle 18:00, 21:00 e 23:30). Se l'utente registra la giornata, i promemoria successivi per quel giorno vengono automaticamente cancellati.
- **Supporto Multilingua**: Localizzazione completa per 8 lingue:
  - Italiano (it)
  - Inglese (en)
  - Francese (fr)
  - Tedesco (de)
  - Spagnolo (es)
  - Cinese (zh)
  - Russo (ru)
  - Giapponese (ja)
- **Tema Dinamico**: Supporto completo per la modalità Chiara e Scura in linea con le impostazioni di sistema.

---

## 🛠️ Stack Tecnologico

- **Framework**: [Flutter](https://flutter.dev) (SDK ^3.6.1)
- **Database Locale**: [sqflite](https://pub.dev/packages/sqflite) per salvare le entry in locale.
- **Grafici**: [fl_chart](https://pub.dev/packages/fl_chart) per visualizzare l'andamento dell'umore e delle statistiche.
- **Widget di Sistema**: [home_widget](https://pub.dev/packages/home_widget) per la comunicazione con i widget nativi.
- **Notifiche**: [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) per la pianificazione dei promemoria giornalieri.

---

## 📦 Installazione e Avvio

Segui questi passaggi per configurare ed eseguire il progetto localmente:

### 1. Prerequisiti
Assicurati di avere Flutter installato sul tuo computer. Puoi verificarlo con il comando:
```bash
flutter doctor
```

### 2. Clonare il Repository
```bash
git clone <url-del-repository>
cd DailyFox/fox
```

### 3. Installare le Dipendenze
Scarica tutti i pacchetti necessari definiti in `pubspec.yaml`:
```bash
flutter pub get
```

### 4. Generare i File di Localizzazione (L10n) ⚠️
Il progetto utilizza il generatore automatico di Flutter per gestire le traduzioni. È **fondamentale** eseguire questo comando prima di compilare per evitare errori legati a `AppLocalizations`:
```bash
flutter gen-l10n
```

### 5. Avviare l'Applicazione
Collega un dispositivo o avvia un emulatore ed esegui:
```bash
flutter run
```

---

## 🧪 Test e Analisi Statica

### Eseguire i Test Unitari
I test sono configurati per validare il corretto funzionamento dei modelli dei dati ed evitare regressioni:
```bash
flutter test
```

### Eseguire l'Analisi Statica
Per verificare che il codice rispetti le linee guida e le convenzioni di Dart:
```bash
flutter analyze
```
