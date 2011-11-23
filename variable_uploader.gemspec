# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "variable_uploader/version"

Gem::Specification.new do |s|
  s.name        = "variable_uploader"
  s.version     = GoodData::VariableUploader::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Tomas Svarovsky"]
  s.email       = ["svarovsky.tomas@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{Wrapper on GoodData ruby gem that should make uploading varaibles easier}
  s.description = %q{Wrapper on GoodData ruby gem that should make uploading varaibles easier==}

  s.rubyforge_project = "variable_uploader"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
  
  s.add_dependency "rspec"
  s.add_dependency "rake"
  s.add_dependency "fastercsv"
  s.add_dependency "gooddata"
  
end

