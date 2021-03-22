Gem::Specification.new do |s|
  s.name = 'easyimg_utils'
  s.version = '0.6.5'
  s.summary = 'Makes manipulating images from 1 line of code easier.'
  s.authors = ['James Robertson']
  s.files = Dir['lib/easyimg_utils.rb']
  s.add_runtime_dependency('rmagick', '~> 4.2', '>=4.2.2') 
  s.add_runtime_dependency('rxfhelper', '~> 1.1', '>=1.1.3')   
  s.add_runtime_dependency('webp-ffi', '~> 0.3', '>=0.3.1')
  s.add_runtime_dependency('x4ss', '~> 0.2', '>=0.2.0')
  s.signing_key = '../privatekeys/easyimg_utils.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'digital.robertson@gmail.com'
  s.homepage = 'https://github.com/jrobertson/easyimg_utils'
end
