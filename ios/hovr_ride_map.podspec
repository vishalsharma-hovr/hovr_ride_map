#
Pod::Spec.new do |s|
  s.name             = 'hovr_ride_map'
  s.version          = '1.0.3'
  s.summary          = 'Native Google Maps platform views for Flutter ride apps.'
  s.description      = <<-DESC
Native Google Maps platform views and ride map method channels for Flutter apps.
                       DESC
  s.homepage         = 'https://github.com/vishalsharma-hovr/hovr_ride_map'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'HOVR' => 'dev@ridehovr.com' }
  s.source           = { :path => '.' }
  s.source_files = 'hovr_ride_map/Sources/hovr_ride_map/**/*.{swift}'
  s.resource_bundles = {
    'hovr_ride_map' => ['hovr_ride_map/Sources/hovr_ride_map/Resources/**/*']
  }
  s.dependency 'Flutter'
  # >= 9.0 keeps the HOVR host app on GoogleMaps 9.x (GoogleNavigation constraint).
  s.dependency 'GoogleMaps', '>= 9.0'
  s.platform = :ios, '16.0'
  s.static_framework = true

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  s.test_spec 'Tests' do |test_spec|
    test_spec.source_files = 'hovr_ride_map/Tests/**/*'
  end
end
