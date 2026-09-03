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