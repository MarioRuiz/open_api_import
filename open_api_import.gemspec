Gem::Specification.new do |s|
  s.name        = 'open_api_import'
  s.version     = '0.9.0'
  s.summary     = "OpenApiImport -- Import a Swagger or Open API file and create a Ruby Request Hash file including all requests and responses with all the examples. The file can be in JSON or YAML"
  s.description = "OpenApiImport -- Import a Swagger or Open API file and create a Ruby Request Hash file including all requests and responses with all the examples. The file can be in JSON or YAML"
  s.authors     = ["Mario Ruiz"]
  s.email       = 'marioruizs@gmail.com'
  s.files       = ["lib/open_api_import.rb","lib/open_api_import/utils.rb","LICENSE","README.md",".yardopts"]
  s.extra_rdoc_files = ["LICENSE","README.md"]
  s.homepage    = 'https://github.com/MarioRuiz/open_api_import'
  s.license       = 'MIT'
  s.add_runtime_dependency 'oas_parser', '~> 0.22', '>= 0.22.2'
  s.add_runtime_dependency 'rufo', '~> 0.7', '>= 0.7.0'
  s.add_runtime_dependency 'nice_hash', '~> 1.15', '>= 1.15.3'
  s.add_development_dependency 'rspec', '~> 3.8', '>= 3.8.0'
  s.add_development_dependency 'coveralls', '~> 0.8', '>= 0.8.22'
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ["lib"]
  s.executables << 'open_api_import'
  s.required_ruby_version = '>= 2.4'
  s.post_install_message = "Thanks for installing! Visit us on https://github.com/MarioRuiz/open_api_import"
end

