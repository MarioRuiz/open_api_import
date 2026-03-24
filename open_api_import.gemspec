# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name = "open_api_import"
  s.version = "0.12.0"
  s.summary = "OpenApiImport -- Import a Swagger or Open API file and create a Ruby Request Hash file including all requests and responses with all the examples. The file can be in JSON or YAML"
  s.description = "OpenApiImport -- Import a Swagger or Open API file and create a Ruby Request Hash file including all requests and responses with all the examples. The file can be in JSON or YAML"
  s.authors = ["Mario Ruiz"]
  s.email = "marioruizs@gmail.com"
  s.files = ["lib/open_api_import.rb", "LICENSE", "README.md", ".yardopts"] + Dir["lib/open_api_import/*.rb"]
  s.extra_rdoc_files = ["LICENSE", "README.md"]
  s.homepage = "https://github.com/MarioRuiz/open_api_import"
  s.license = "MIT"
  s.add_dependency "activesupport", ">= 6.1", "< 8.0"
  s.add_dependency "nice_hash", "~> 1.19"
  s.add_dependency "oas_parser_reborn", "~> 0.25"
  s.add_dependency "rufo", "~> 0.16"
  s.add_development_dependency "rspec", "~> 3.8", ">= 3.8.0"
  s.add_development_dependency "rubocop", "~> 1.0"
  s.require_paths = ["lib"]
  s.executables << "open_api_import"
  s.required_ruby_version = ">= 3.0"
  s.post_install_message = "Thanks for installing! Visit us on https://github.com/MarioRuiz/open_api_import"
  s.metadata["rubygems_mfa_required"] = "true"
end
