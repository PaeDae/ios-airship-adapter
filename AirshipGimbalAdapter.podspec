
Pod::Spec.new do |s|
  s.version                 = "1.0.0"
  s.name                    = "GimbalAirshipAdapter"
  s.summary                 = "An adapter for integrating Gimbal place events with Airship."
  s.documentation_url       = "https://github.com/gimbalinc/ios-airship-adapter"
  s.homepage                = "https://infillion.com/commerce/gimbal/"
  s.author                  = { "Gimbal" => "support@infillion.com" }
  s.license                 = { :type => "Apache License, Version 2.0", :file => "LICENSE" }
  s.source                  = { :git => "https://github.com/PaeDae/ios-airship-adapter.git", :tag => s.version.to_s }
  s.ios.deployment_target   = "11.0"
  s.swift_version           = "5.0"
  s.source_files            = "Pod/Classes/*"
  s.requires_arc            = true
  s.dependency                "GimbalXCFramework", "~> 2.85"
  s.dependency                "Airship", "~> 16.1"
  s.pod_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64'}
  s.user_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }
end