#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint shazam_kit_managed.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'shazam_kit_managed'
  s.version          = '1.0.5'
  s.summary          = 'Fork corretto di flutter_shazam_kit: SHManagedSession su iOS 17+, conversione di formato esplicita nel ripiego.'
  s.description      = <<-DESC
Copia corretta di flutter_shazam_kit (fork non ufficiale, 989 Records) che usa SHManagedSession su iOS 17 e superiori e, sul ripiego per le versioni precedenti, converte esplicitamente il formato audio prima di passarlo a ShazamKit.
                       DESC
  s.homepage         = 'https://github.com/989web/shazam_kit_managed'
  s.license          = { :file => '../LICENSE' }
  s.author           = { '989 Records' => 'dev@989records.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
