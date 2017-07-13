# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'rack/param_to_cookie/version'

Gem::Specification.new do |s|
  s.name              = 'rack-param_to_cookie'
  s.version           = Rack::ParamToCookie::VERSION
  s.platform          = Gem::Platform::RUBY
  s.authors           = ['John Lees-Miller']
  s.email             = ['jdleesmiller@gmail.com']
  s.homepage          = 'https://github.com/jdleesmiller/rack-param_to_cookie'
  s.summary           = %q{Store selected request parameters to cookies.}
  s.description       = %q{Store selected request parameters to cookies for use in future requests. Useful for affiliate, referral or promotion links.}

  s.add_runtime_dependency 'rack', '< 3'

  s.add_development_dependency 'gemma', '~> 4.1.0'
  s.add_development_dependency 'rack-test'

  s.files       = Dir.glob('{lib,bin}/**/*.rb') + %w(README.rdoc)
  s.test_files  = Dir.glob('test/rack/param_to_cookie/*_test.rb')

  s.rdoc_options = [
    "--main",    "README.rdoc",
    "--title",   "#{s.full_name} Documentation"]
  s.extra_rdoc_files << "README.rdoc"
end

