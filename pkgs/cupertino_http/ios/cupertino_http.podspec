#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint cupertino_http.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'cupertino_http'
  s.version          = '0.0.1'
  s.summary          = 'Flutter Foundation URL Loading System'
  s.description      = <<-DESC
  A Flutter plugin for accessing the Foundation URL Loading System.
                       DESC
  s.homepage         = 'https://github.com/dart-lang/http/tree/master/pkgs/cupertino_http'
  s.license          = { :type => 'BSD', :file => '../LICENSE' }
  s.author           = { 'TODO' => 'use-valid-author' }

  # This will ensure the source files in Classes/ are included in the native
  # builds of apps using this FFI plugin. Podspec does not support relative
  # paths, so Classes contains a forwarder C file that relatively imports
  # `../src/*` so that the C sources can be shared among all target platforms.
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'
  s.requires_arc = []

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
