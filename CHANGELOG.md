## 1.0.5 (989 Records fork)

* Fix: "com.apple.ShazamKit error 202" a intermittenza su alcuni cicli.
  Causa individuata: `startManagedListening` richiamava
  `SHManagedSession.prepare()` a OGNI riapertura del ciclo (l'app chiude
  la sessione Shazam fra un ciclo e l'altro per liberare il microfono
  alla registrazione dei 15s per i provider), invece di prepararla una
  sola volta come fa il pattern ufficiale Apple. Ripetere `prepare()` su
  una sessione appena `cancel()`-ata, mentre il motore audio sottostante
  puo' non aver ancora finito di smontarsi, e' compatibile con un errore
  intermittente (compare solo su alcuni cicli, non su tutti — coerente
  con una corsa, non con un problema di permessi/configurazione, che
  fallirebbe sempre). Ora `prepare()` viene chiamato una sola volta per
  istanza di `SHManagedSession`; l'istanza si ricrea solo su `endSession`.

## 1.0.4 (989 Records fork)

* Fix: `ios/flutter_shazam_kit.podspec` rinominato in
  `ios/shazam_kit_managed.podspec`, con `s.name` allineato allo stesso
  nome. CocoaPods cerca esattamente `ios/<nome pacchetto>.podspec` —
  con il file/nome vecchi la 1.0.3 falliva `pod install` con
  "No podspec found for shazam_kit_managed in
  .symlinks/plugins/shazam_kit_managed/ios".
* Fix collegato: l'header ponte Objective-C/Swift generato prende il nome
  dal modulo CocoaPods (`s.name`), quindi anche
  `ios/Classes/FlutterShazamKitPlugin.m` ora importa
  `shazam_kit_managed-Swift.h` invece di `flutter_shazam_kit-Swift.h` —
  lo stesso bug si sarebbe ripresentato un passo dopo `pod install`.
* Verificato: nessun riferimento residuo al nome `flutter_shazam_kit` nel
  podspec, nel bridging Objective-C o nel pubspec del package. Il lato
  Android non aveva un problema equivalente (Gradle non richiede che un
  file abbia il nome del package pub — verificato leggendo
  `android/build.gradle`/`settings.gradle`/`AndroidManifest.xml`: usano
  un namespace Java (`com.sstonn.flutter_shazam_kit`) indipendente dal
  nome del package pub.dev, invariato e corretto così com'era).

## 1.0.3 (989 Records fork)

* iOS: usa `SHManagedSession` (Apple, iOS 17+) come via primaria — gestisce
  da sola microfono, sessione audio e conversione di formato, eliminando
  la causa documentata da Apple (WWDC23 "Create a great ShazamKit
  experience") per cui `SHSession.matchStreamingBuffer` con un formato
  audio non supportato risponde sempre NoMatch, senza errori.
* iOS: sotto iOS 17, il ripiego (`SHSession.matchStreamingBuffer`) ora
  converte esplicitamente il buffer del microfono a 44.1kHz mono con
  `AVAudioConverter` prima di passarlo, invece di inoltrare il formato
  nativo dell'hardware.
* Aggiunto un callback opzionale e additivo `onDiagnostics` (via usata,
  frequenza/formato effettivi) — l'interfaccia esistente non cambia.
* Nessuna modifica al lato Android.

## 1.0.2

* Update documentation.

## 1.0.1

* Remove unsued models. 

## 1.0.0

* Add detect music by microphone function for IOS and Android.