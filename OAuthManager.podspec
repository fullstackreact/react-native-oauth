require 'json'
package = JSON.parse(File.read('package.json'))
version = package["version"]
repo = package['repository']
author = package['author']

default_header_search_paths = [
  "$(inherited)",
  "${SRCROOT}/../../React/**",
  "${SRCROOT}/../node_modules/react-native/**"]

Pod::Spec.new do |s|

  s.name         = "OAuthManager"
  s.version      = version
  s.summary      = "OAuthManager makes working with OAuth 1.0/2.0 oauth providers easy"
  s.description  = <<-DESC
  Integrate OAuth 1.0/2.0 libraries in react native without even thinking about it
                   DESC

  s.homepage     = "http://fullstackreact.com"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author             = { "Ari Lerner" => author }
  s.social_media_url   = 'http://twitter.com/fullstackio'

  #  When using multiple platforms
  s.ios.deployment_target = "8.0"

  s.source = { :git => repo['url'], :tag => "v#{version}" }
  s.public_header_files = "ios/OAuthManager/*.h"

  s.source_files   = 'ios/OAuthManager/*.{h,m}'
  s.preserve_paths = 'README.md', 'package.json', '*.js'

  s.default_subspec = 'Core'

  s.subspec 'Core' do |ss|
    ss.dependency 'OAuthSwift', '~> 0.5.2'
  end

  s.subspec 'Dev' do |ss|
    ss.dependency 'React'
    ss.dependency 'React/RCTLinkingIOS'
  end

  s.xcconfig = {
    'HEADER_SEARCH_PATHS' => default_header_search_paths.join(' ')
  }
end
