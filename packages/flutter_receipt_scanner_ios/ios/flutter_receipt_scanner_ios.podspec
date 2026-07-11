#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_receipt_scanner_ios.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_receipt_scanner_ios'
  s.version          = '0.1.0'
  s.summary          = 'iOS implementation of flutter_receipt_scanner.'
  s.description      = <<-DESC
On-device receipt image acquisition and OCR via VisionKit and Vision.
                       DESC
  s.homepage         = 'https://github.com/AndrewDongminYoo/flutter_receipt_scanner'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Dongmin Yu' => 'ydm2790@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'flutter_receipt_scanner_ios/Sources/flutter_receipt_scanner_ios/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '16.0'
  s.frameworks = 'VisionKit', 'Vision', 'ImageIO', 'CoreGraphics', 'UniformTypeIdentifiers'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
