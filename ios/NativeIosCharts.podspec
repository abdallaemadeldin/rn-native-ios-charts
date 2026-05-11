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
  # SwiftUI Charts requires iOS 16+. We target 17 to use modern
  # `.foregroundStyle` with gradients and the unified Chart API.
  s.platforms      = { :ios => '17.0', :tvos => '17.0' }
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
