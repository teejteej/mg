# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "metrics/version"

Gem::Specification.new do |s|
  s.name        = "metrics"
  s.version     = Metrics::VERSION
  s.authors     = ["teejteej"]
  s.email       = ["teeceeiks@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{Metrics}
  s.description = %q{Metrics}

  s.rubyforge_project = "metrics"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  # s.add_development_dependency "uuidtools"
  # s.add_runtime_dependency "uuidtools"
  
end