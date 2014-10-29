# -*- encoding: utf-8 -*-
require File.expand_path('../lib/em-mysql2/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = [""]
  gem.email         = [""]
  gem.description   = %q{Old em_mysql2 adapter}
  gem.summary       = %q{Old em_mysql2 adapter...}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.name          = "em-mysql2"
  gem.require_paths = ["lib"]
  gem.version       = EmMysql2::VERSION
  
  gem.add_dependency 'mysql2',        '~> 0.3.11'
  gem.add_dependency 'activerecord',  '~> 4.0'
  gem.add_dependency 'eventmachine',  '~> 1.0.0'
end
