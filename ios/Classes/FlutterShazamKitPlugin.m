#import "FlutterShazamKitPlugin.h"
// L'header ponte Swift generato prende il nome dal modulo CocoaPods, cioe'
// da s.name nel podspec (shazam_kit_managed, non piu' flutter_shazam_kit) —
// stessa causa/stesso fix del podspec stesso: usare qui il nome vecchio
// avrebbe rotto la build un passo dopo l'installazione dei pod, all'atto
// del bridging Objective-C/Swift.
#if __has_include(<shazam_kit_managed/shazam_kit_managed-Swift.h>)
#import <shazam_kit_managed/shazam_kit_managed-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "shazam_kit_managed-Swift.h"
#endif

@implementation FlutterShazamKitPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFlutterShazamKitPlugin registerWithRegistrar:registrar];
}
@end
