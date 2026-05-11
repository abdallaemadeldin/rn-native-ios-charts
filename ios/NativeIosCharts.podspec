require 'json'

package = JSON.parse(File.read(File.join(__dir__, '..', 'package.json')))

# npm uses `git+https://...` for repository urls, but cocoapods wants
# plain `https://...`. Strip the prefix so the podspec is valid.
clean_url = package['repository']['url'].sub(/^git\+/, '').sub(/\.git$/, '')

Pod::Spec.new do |s|
  s.name           = 'NativeIosCharts'
  s.version        = package['version']
  s.summary        = package['description']
  s.description    = package['description']
  s.license        = package['license']
  s.author         = ''
  s.homepage       = clean_url
  # Podspec minimum is set low so the pod installs cleanly in any
  # iOS-15+ Expo project. The actual SwiftUI Charts code is gated
  # with `@available(iOS 17.0, *)` — on older iOS the native view
  # renders a transparent placeholder, matching the JS-side no-op on
  # non-iOS platforms.
  s.platforms      = { :ios => '15.1', :tvos => '15.1' }
  s.swift_version  = '5.9'
  s.source         = { git: "#{clean_url}.git", tag: s.version.to_s }
  s.static_framework = true

  s.dependency 'ExpoModulesCore'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'SWIFT_COMPILATION_MODE' => 'wholemodule'
  }

  s.source_files = "**/*.{h,m,swift}"
end
