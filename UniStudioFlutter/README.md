# UniStudio Flutter — anteprima offline

Progetto separato dalla PWA. SQLite (sqflite), file locali, nessun account o server nel codice. iOS/iPadOS e Android sono destinazioni previste.

## Compilazione
Installare Flutter stable e gli strumenti per la piattaforma. Da questa cartella:
```sh
flutter create --platforms=ios,android --org com.unistudio --project-name unistudio .
flutter pub get
flutter analyze
flutter run
```
Non sovrascrivere lib/main.dart o pubspec.yaml. Per iOS/iPadOS usare macOS e Xcode, selezionare un Team per la firma e il dispositivo. La prima installazione delle dipendenze richiede Internet; il codice applicativo non richiede servizi online.

## Funzioni nel sorgente
- Home con saluto unico, widget configurabili, ricerca locale e tema.
- Materie, agenda (lista datata), esami, promemoria, appunti, planner di ripasso.
- Flashcard con intervalli 1/3/7 giorni, Focus 25 minuti, statistiche.
- Editor mappe con nodi trascinabili, collegamenti, zoom, scaletta, colori e PNG.
- Lavagna quaderno a pagina singola con tratto libero e PNG.
- Importazione e condivisione di documenti locali; non include lettore PDF interno.
- Alessandro con avatar e dediche locali (non AI generativa).
- Backup JSON inclusi allegati fino a 100 MB; importazione aggiuntiva, non deduplicata.
- Importazione preliminare backup PWA UniStudio/1: conserva l'originale in SQLite e mappa i campi base. Contenuto grafico legacy e libreria IndexedDB separata non vengono ricostruiti automaticamente.

## Limiti
Sorgenti non compilati né testati su dispositivo. Non è un IPA/APK pronto. Mancano scanner/OCR, integrazione pressione Pencil e palm rejection, notifiche OS, PDF interno, quaderni multipagina, migrazione completa, protezione crittografica del backup, AI locale. Non cancellare la PWA prima di verificare l'importazione e conservare i backup. Il timer non sopravvive a chiusura forzata. Le versioni delle dipendenze sono vincoli iniziali, non dichiarate ultime disponibili.