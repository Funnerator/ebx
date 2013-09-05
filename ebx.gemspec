# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ebx/version'

Gem::Specification.new do |spec|
  spec.name          = "ebx"
  spec.version       = Ebx::VERSION
  spec.authors       = ["Alex Bullard"]
  spec.email         = ["abullrd@gmail.com"]
  spec.description   = "eb eXtended"
  spec.summary       = "A extended version of the Amazon ElasticBeanstalk commandline tool"
  spec.homepage      = "https://github.com/Funnerator/ebx.git"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
end
