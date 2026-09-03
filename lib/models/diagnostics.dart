/// Diagnostica emessa dal lato nativo a ogni avvio di ascolto: quale via e'
/// stata usata (SHManagedSession su iOS 17+, o il ripiego manuale sotto) e a
/// quale formato/frequenza e' stato effettivamente convertito il campione
/// prima di passarlo a ShazamKit.
///
/// Aggiunta ADDITIVA: l'interfaccia esistente (configureShazamKitSession,
/// startDetectionWithMicrophone, endDetectionWithMicrophone, endSession,
/// onMatchResultDiscovered, onError, onDetectStateChanged) resta invariata.
/// Un'app che non registra [FlutterShazamKit.onDiagnostics] non nota alcuna
/// differenza.
class ShazamDiagnostics {
  const ShazamDiagnostics({
    required this.via,
    required this.format,
    this.sampleRate,
  });

  factory ShazamDiagnostics.fromMap(Map<String, dynamic> map) {
    return ShazamDiagnostics(
      via: map['via'] as String? ?? 'sconosciuta',
      format: map['format'] as String? ?? '',
      sampleRate: (map['sampleRate'] as num?)?.toDouble(),
    );
  }

  /// 'managed_SHManagedSession' oppure 'legacy_matchStreamingBuffer'.
  final String via;

  /// Descrizione leggibile del formato/frequenza effettivamente usati.
  final String format;

  /// Frequenza di campionamento effettiva, quando nota (null quando la via
  /// gestita da SHManagedSession la converte internamente senza esporla).
  final double? sampleRate;
}
