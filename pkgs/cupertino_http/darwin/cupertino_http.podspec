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
  s.source = { :http => 'https://github.com/dart-lang/http/tree/master/pkgs/cupertino_http' }

  s.source_files = 'cupertino_http/Sources/cupertino_http/**/*'
  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  s.ios.deployment_target = '15.0'  # Required for NSURLSessionTaskDelegate.
  s.osx.deployment_target = '12.0' # Required for NSURLSessionTaskDelegate.

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
