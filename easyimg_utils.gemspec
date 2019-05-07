Gem::Specification.new do |s|
  s.name = 'easyimg_utils'
  s.version = '0.3.0'
  s.summary = 'Makes manipulating images from 1 line of code easier.'
  s.authors = ['James Robertson']
  s.files = Dir['lib/easyimg_utils.rb']
  s.add_runtime_dependency('rmagick', '~> 3.1', '>=3.1.0') 
  s.add_runtime_dependency('rxfhelper', '~> 0.9', '>=0.9.4')   
  s.signing_key = '../privatekeys/easyimg_utils.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'james@jamesrobertson.eu'
  s.homepage = 'https://github.com/jrobertson/easyimg_utils'
end
