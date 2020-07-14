Gem::Specification.new do |s|
  s.name = 'easyimg_utils'
  s.version = '0.6.2'
  s.summary = 'Makes manipulating images from 1 line of code easier.'
  s.authors = ['James Robertson']
  s.files = Dir['lib/easyimg_utils.rb']
  s.add_runtime_dependency('rmagick', '~> 4.1', '>=4.1.2') 
  s.add_runtime_dependency('rxfhelper', '~> 1.0', '>=1.0.0')   
  s.add_runtime_dependency('webp-ffi', '~> 0.2', '>=0.2.7')
  s.add_runtime_dependency('x4ss', '~> 0.2', '>=0.2.0')
  s.signing_key = '../privatekeys/easyimg_utils.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'james@jamesrobertson.eu'
  s.homepage = 'https://github.com/jrobertson/easyimg_utils'
end
