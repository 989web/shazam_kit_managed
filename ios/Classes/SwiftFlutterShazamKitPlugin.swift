import Flutter
import UIKit
import ShazamKit

// ============================================================================
//  Fork corretto di flutter_shazam_kit (989 Records / 989web).
// ----------------------------------------------------------------------------
//  CAUSA ORIGINALE, documentata da Apple (WWDC23 "Create a great ShazamKit
//  experience"): la via manuale (AVAudioEngine proprio + SHSession.
//  matchStreamingBuffer) accetta solo un insieme limitato di formati audio a
//  frequenze di campionamento specifiche — con un formato non supportato il
//  risultato e' SEMPRE NoMatch, senza errori. Il plugin originale installava
//  il tap passando `format: outputFormat` a installTap(...): quel parametro
//  NON esegue una vera conversione (e' un limite noto di AVAudioEngine: la
//  conversione reale richiede un AVAudioConverter esplicito, come fa
//  correttamente il pacchetto `record` in RecorderStreamDelegate.swift, gia'
//  usato in questo stesso progetto — la struttura del converter qui sotto
//  rispecchia esattamente quella, gia' verificata/in produzione). Il buffer
//  che arrivava a SHSession era quindi nel formato nativo dell'hardware
//  (spesso 48kHz), non in quello che ShazamKit si aspetta — da qui i "nessun
//  riscontro" costanti anche con audio pulito.
//
//  FIX:
//   1) Via primaria, iOS 17+: SHManagedSession — introdotta da Apple proprio
//      per eliminare questa intera classe di problemi: gestisce da sola
//      microfono, sessione audio e conversione di formato.
//   2) Ripiego, iOS < 17: stessa via manuale di prima, ma con un
//      AVAudioConverter ESPLICITO verso il formato che SHSession richiede
//      (44.1kHz mono) prima di chiamare matchStreamingBuffer — invece di
//      affidarsi al parametro `format:` di installTap, che non converte
//      davvero.
//
//  Interfaccia Dart INVARIATA: stessi metodi (configureShazamKitSession,
//  startDetectionWithMicrophone, endDetectionWithMicrophone, endSession) e
//  stessi callback (matchFound, notFound, didHasError, detectStateChanged).
//  Aggiunta SOLO additiva: un nuovo callback "diagnostics" (via/sampleRate/
//  formato), che l'app puo' ignorare senza alcuna modifica.
// ============================================================================
public class SwiftFlutterShazamKitPlugin: NSObject, FlutterPlugin {
    // Via di ripiego (iOS < 17): sessione classica + motore audio proprio.
    private var legacySession: SHSession?
    private let audioEngine = AVAudioEngine()
    private var legacyConverter: AVAudioConverter?

    // Via primaria (iOS 17+): boxata in AnyObject perche' una proprieta'
    // memorizzata non puo' avere un tipo condizionato da @available — stesso
    // problema/soluzione documentati per qualunque API iOS-version-gated
    // usata come stored property.
    private var managedSessionBox: AnyObject?
    @available(iOS 17.0, *)
    private var managedSession: SHManagedSession? {
        get { managedSessionBox as? SHManagedSession }
        set { managedSessionBox = newValue }
    }
    private var managedSessionTask: Task<Void, Never>?
    // "Errore 202 a intermittenza" — indagine: l'app chiude la sessione
    // Shazam a ogni ciclo (cancel(), per liberare il microfono alla
    // registrazione dei 15s per i provider — "un solo proprietario del
    // microfono alla volta") e ne riapre una nuova al ciclo successivo.
    // Prima, startManagedListening richiamava managed.prepare() a OGNI
    // riapertura: ma il pattern reale di Apple (sample ufficiali, WWDC23)
    // prepara la sessione UNA volta sola per tutta la vita dell'oggetto e
    // poi si limita a interrogare result() ripetutamente — mai un secondo
    // prepare() sulla STESSA istanza. Ripetere prepare() su una sessione
    // appena cancel()-ata, mentre il motore audio sottostante potrebbe non
    // aver ancora finito di smontarsi, e' il candidato piu' concreto per
    // "error 202" intermittente (compare solo su alcuni cicli, mai su
    // tutti: coerente con una corsa/race, non con un problema di permessi
    // o di configurazione, che fallirebbe SEMPRE). Fix: prepare() una sola
    // volta per istanza di SHManagedSession, mai piu' finche' l'istanza
    // non viene ricreata (endSession).
    private var managedPreparata = false

    private var callbackChannel: FlutterMethodChannel?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_shazam_kit", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterShazamKitPlugin(callbackChannel: FlutterMethodChannel(name: "flutter_shazam_kit_callback", binaryMessenger: registrar.messenger()))
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    init(callbackChannel: FlutterMethodChannel? = nil) {
        self.callbackChannel = callbackChannel
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "configureShazamKitSession":
            configureShazamKitSession()
            result(nil)
        case "startDetectionWithMicrophone":
            do {
                try startListening(result: result)
            } catch {
                callbackChannel?.invokeMethod("didHasError", arguments: error.localizedDescription)
            }
        case "endDetectionWithMicrophone":
            stopListening()
            result(nil)
        case "endSession":
            legacySession = nil
            if #available(iOS 17.0, *) {
                managedSessionTask?.cancel()
                managedSessionTask = nil
                managedSession = nil
                managedPreparata = false
            }
            result(nil)
        default:
            result(nil)
        }
    }
}

// MARK: - Configurazione e avvio/stop, smistati fra le due vie
extension SwiftFlutterShazamKitPlugin {
    func configureShazamKitSession() {
        if #available(iOS 17.0, *) {
            if managedSession == nil {
                managedSession = SHManagedSession()
            }
        } else {
            if legacySession == nil {
                legacySession = SHSession()
                legacySession?.delegate = self
            }
        }
    }

    func startListening(result: @escaping FlutterResult) throws {
        callbackChannel?.invokeMethod("detectStateChanged", arguments: 1)
        if #available(iOS 17.0, *), let managed = managedSession {
            startManagedListening(managed)
            result(nil)
            return
        }
        try startLegacyListening()
        result(nil)
    }

    func stopListening() {
        callbackChannel?.invokeMethod("detectStateChanged", arguments: 0)
        if #available(iOS 17.0, *), managedSession != nil {
            managedSessionTask?.cancel()
            managedSessionTask = nil
            managedSession?.cancel()
            return
        }
        stopLegacyListening()
    }
}

// MARK: - Via primaria (iOS 17+) — SHManagedSession
@available(iOS 17.0, *)
extension SwiftFlutterShazamKitPlugin {
    func startManagedListening(_ managed: SHManagedSession) {
        managedSessionTask?.cancel()
        managedSessionTask = Task { [weak self] in
            guard let self = self else { return }
            // prepare() richiede da sola il permesso microfono e configura
            // motore audio/sessione — chiamato UNA sola volta per istanza
            // (vedi commento esteso su managedPreparata): ripeterlo a ogni
            // ciclo su una sessione appena cancel()-ata era il candidato
            // piu' concreto per "error 202" intermittente.
            if !self.managedPreparata {
                await managed.prepare()
                self.managedPreparata = true
            }
            self.emitDiagnostics(via: "managed_SHManagedSession", sampleRate: nil,
                                  formato: "Gestito automaticamente da SHManagedSession (conversione di formato interna al sistema)")
            // Non si chiude a intervalli fissi: resta in ascolto e segnala
            // ogni esito (match/noMatch/error) finche' non viene cancellata
            // da stopListening() — il chiamante Dart decide quando fermarsi.
            while !Task.isCancelled {
                let outcome = await managed.result()
                if Task.isCancelled { break }
                switch outcome {
                case .match(let match):
                    self.handleMatch(match)
                case .noMatch(_):
                    self.callbackChannel?.invokeMethod("notFound", arguments: nil)
                case .error(let error, _):
                    self.callbackChannel?.invokeMethod("didHasError", arguments: error.localizedDescription)
                }
            }
        }
    }
}

// MARK: - Via di ripiego (iOS < 17) — SHSession + matchStreamingBuffer, con
//         conversione di formato ESPLICITA (Punto 1 della richiesta).
extension SwiftFlutterShazamKitPlugin {
    func startLegacyListening() throws {
        guard legacySession != nil else {
            callbackChannel?.invokeMethod("didHasError", arguments: "ShazamSession not found, please call configureShazamKitSession() first to initialize it.")
            return
        }
        guard !audioEngine.isRunning else {
            callbackChannel?.invokeMethod("didHasError", arguments: "Audio engine is currently running, please stop the audio engine first and then try again")
            return
        }
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.mixWithOthers])

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        // Formato ESPLICITAMENTE richiesto da SHSession (44.1kHz mono) —
        // senza questa conversione il formato nativo dell'hardware (spesso
        // 48kHz) produce sempre NoMatch, senza errori (documentato da Apple,
        // vedi commento in testa al file).
        guard let targetFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1) else {
            callbackChannel?.invokeMethod("didHasError", arguments: "Impossibile costruire il formato 44.1kHz mono richiesto da ShazamKit.")
            return
        }
        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            callbackChannel?.invokeMethod("didHasError", arguments: "Conversione di formato verso 44.1kHz mono non disponibile su questo device.")
            return
        }
        legacyConverter = converter

        emitDiagnostics(
            via: "legacy_matchStreamingBuffer",
            sampleRate: 44100,
            formato: "PCM 44.1kHz mono (convertito esplicitamente da \(inputFormat.sampleRate)Hz/\(inputFormat.channelCount)ch con AVAudioConverter)"
        )

        // Tap sul formato NATIVO del nodo (non su outputFormat: passare un
        // formato diverso a installTap non esegue una vera conversione,
        // vedi commento in testa al file) — la conversione vera avviene
        // dopo, esplicitamente, in convertAndForward.
        inputNode.installTap(onBus: 0, bufferSize: 8192, format: inputFormat) { [weak self] buffer, time in
            self?.convertAndForward(buffer, at: time, inputFormat: inputFormat, targetFormat: targetFormat)
        }
        audioEngine.prepare()
        try audioEngine.start()
    }

    func convertAndForward(_ buffer: AVAudioPCMBuffer, at time: AVAudioTime, inputFormat: AVAudioFormat, targetFormat: AVAudioFormat) {
        guard let converter = legacyConverter else { return }
        // Stessa identica tecnica di conversione (capacita' calcolata dal
        // rapporto delle frequenze, callback che restituisce il buffer
        // sorgente con .haveData) gia' usata e verificata in produzione dal
        // pacchetto `record` (RecorderStreamDelegate.swift) in questo stesso
        // progetto — non una tecnica nuova/non verificata.
        let inputCallback: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        let capacity = (UInt32(targetFormat.sampleRate) * targetFormat.channelCount * buffer.frameLength)
            / (UInt32(inputFormat.sampleRate) * inputFormat.channelCount)
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: max(capacity, 1)) else {
            return
        }
        var error: NSError?
        converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputCallback)
        if error != nil {
            return
        }
        legacySession?.matchStreamingBuffer(convertedBuffer, at: time)
    }

    func stopLegacyListening() {
        guard audioEngine.isRunning || legacyConverter != nil else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        legacyConverter = nil
    }
}

// MARK: - Delegate della via di ripiego
extension SwiftFlutterShazamKitPlugin: SHSessionDelegate {
    public func session(_ session: SHSession, didFind match: SHMatch) {
        handleMatch(match)
    }

    public func session(_ session: SHSession, didNotFindMatchFor signature: SHSignature, error: Error?) {
        callbackChannel?.invokeMethod("notFound", arguments: nil)
        if let error = error {
            callbackChannel?.invokeMethod("didHasError", arguments: error.localizedDescription)
        }
    }
}

// MARK: - Helper condivisi fra le due vie
extension SwiftFlutterShazamKitPlugin {
    func handleMatch(_ match: SHMatch) {
        var mediaItems: [[String: Any]] = []
        match.mediaItems.forEach { rawItem in
            var item: [String: Any] = [:]
            item["title"] = rawItem.title
            item["subtitle"] = rawItem.subtitle
            item["shazamId"] = rawItem.shazamID
            item["appleMusicId"] = rawItem.appleMusicID
            if let appleUrl = rawItem.appleMusicURL {
                item["appleMusicUrl"] = appleUrl.absoluteString
            }
            if let artworkUrl = rawItem.artworkURL {
                item["artworkUrl"] = artworkUrl.absoluteString
            }
            item["artist"] = rawItem.artist
            item["matchOffset"] = rawItem.matchOffset
            if let videoUrl = rawItem.videoURL {
                item["videoUrl"] = videoUrl.absoluteString
            }
            if let webUrl = rawItem.webURL {
                item["webUrl"] = webUrl.absoluteString
            }
            item["genres"] = rawItem.genres
            item["isrc"] = rawItem.isrc
            mediaItems.append(item)
        }
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: mediaItems)
            let jsonString = String(data: jsonData, encoding: .utf8)
            self.callbackChannel?.invokeMethod("matchFound", arguments: jsonString)
        } catch {
            callbackChannel?.invokeMethod("didHasError", arguments: "Error when trying to format data, please try again")
        }
    }

    /// Punto "diagnostica" della richiesta: quale via e' stata usata e con
    /// quale frequenza/formato — un solo evento per ogni avvio ascolto,
    /// SUBITO dopo che la via e' stata scelta e configurata.
    func emitDiagnostics(via: String, sampleRate: Double?, formato: String) {
        var payload: [String: Any] = ["via": via, "format": formato]
        if let sampleRate = sampleRate {
            payload["sampleRate"] = sampleRate
        }
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }
        callbackChannel?.invokeMethod("diagnostics", arguments: jsonString)
    }
}
