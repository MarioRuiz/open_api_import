require 'open_api_import'

RSpec.describe OpenApiImport do

    describe '#from' do
        it 'creates a log file if swagger_file is a valid string for a file name' do
            file_name = 'example.yaml'
            File.delete("#{file_name}_open_api_import.log") if File.exist?("#{file_name}_open_api_import.log")
            OpenApiImport.from file_name
            expect(File.exist?("#{file_name}_open_api_import.log")).to eq true
            expect(File.read("#{file_name}_open_api_import.log")).to match /swagger_file:\s#{file_name}/
        end

        it 'doesn\'t create a log file if swagger_file is not a valid string for a file name' do
            file_name = 'exa%$#@{}//&&[]`mple.yaml'
            OpenApiImport.from file_name
            expect(File.exist?("#{file_name}_open_api_import.log")).to eq false
        end

        it 'logs error when swagger version file is lower than supported' do
            file_name = './spec/fixtures/wrong/petstore-minimal.yaml'
            File.delete("#{file_name}_open_api_import.log") if File.exist?("#{file_name}_open_api_import.log")
            OpenApiImport.from file_name
            expect(File.exist?("#{file_name}_open_api_import.log")).to eq true
            expect(File.read("#{file_name}_open_api_import.log")).to match /Unsupported Swagger version/
        end

        it 'creates a requests file' do
            file_name = './spec/fixtures/v2.0/yaml/petstore-minimal.yaml'
            File.delete("#{file_name}.rb") if File.exist?("#{file_name}.rb")
            OpenApiImport.from file_name
            expect(File.exist?("#{file_name}.rb")).to eq true
        end

        it 'creates the module names correctly from the yaml swagger file' do
            file_name = './spec/fixtures/v2.0/yaml/petstore-minimal.yaml'
            OpenApiImport.from file_name
            expect(File.read("#{file_name}.rb")).to match /module\sSwagger\s+module\sSwaggerPetstore\s+module\sV1_0_0/
        end

        it 'creates the module names correctly from the json swagger file' do
            file_name = './spec/fixtures/v2.0/json/petstore-minimal.json'
            OpenApiImport.from file_name
            expect(File.read("#{file_name}.rb")).to match /module\sSwagger\s+module\sSwaggerPetstore\s+module\sV1_0_0/
        end

        it 'creates the module names correctly when name_for_module is :fixed' do
            file_name = './spec/fixtures/v2.0/yaml/petstore-minimal.yaml'
            OpenApiImport.from file_name, name_for_module: :fixed
            expect(File.read("#{file_name}.rb")).to match /module\sSwagger\s+module\sSwaggerPetstore\s+module\sV1_0_0\s+module\sRequests/
        end

        it 'creates the module names correctly when name_for_module is :path' do
            file_name = './spec/fixtures/v2.0/yaml/petstore-simple.yaml'
            OpenApiImport.from file_name, name_for_module: :path
            regexp = /module\sPets$/
            expect(File.read("#{file_name}.rb")).to match regexp
        end

        it 'creates the module names correctly when name_for_module is :tags' do
            file_name = './spec/fixtures/v2.0/yaml/uber.yaml'
            OpenApiImport.from file_name, name_for_module: :tags
            regexp = /module\sProducts$/
            expect(File.read("#{file_name}.rb")).to match regexp
        end
        
        it 'creates the file names correctly when name_for_module is :path_file' do
            file_name = './spec/fixtures/v2.0/yaml/petstore-simple.yaml'
            OpenApiImport.from file_name, name_for_module: :path_file
            expect(File.exist?("#{file_name}_Root.rb")).to eq true
            expect(File.exist?("#{file_name}_Pets.rb")).to eq true
            expect(File.exist?("#{file_name}.rb")).to eq true
        end

        it 'creates the file names correctly when name_for_module is :tags_file' do
            file_name = './spec/fixtures/v2.0/yaml/uber.yaml'
            OpenApiImport.from file_name, name_for_module: :tags_file
            expect(File.exist?("#{file_name}_Products.rb")).to eq true
            expect(File.exist?("#{file_name}_Estimates.rb")).to eq true
            expect(File.exist?("#{file_name}_User.rb")).to eq true
        end

        it 'creates the module names correctly when name_for_module is :path_file' do
            file_name = './spec/fixtures/v2.0/yaml/petstore-simple.yaml'
            OpenApiImport.from file_name, name_for_module: :path_file
            expect(File.read("#{file_name}_Pets.rb")).to match /module\sPets$/
            expect(File.read("#{file_name}_Root.rb")).to match /module\sRoot$/
        end

        it 'creates the module names correctly when name_for_module is :tags_file' do
            file_name = './spec/fixtures/v2.0/yaml/uber.yaml'
            OpenApiImport.from file_name, name_for_module: :tags_file
            expect(File.read("#{file_name}_Products.rb")).to match /module\sProducts$/
            expect(File.read("#{file_name}_Estimates.rb")).to match /module\sEstimates$/
            expect(File.read("#{file_name}_User.rb")).to match /module\sUser$/
        end

        it 'creates a file that requires all request files when name_for_module is :path_file' do
            file_name = './spec/fixtures/v2.0/yaml/petstore-simple.yaml'
            OpenApiImport.from file_name, name_for_module: :path_file
            content = File.read("#{file_name}.rb")
            expect(content).to include 'require_relative "petstore-simple.yaml_Root"'
            expect(content).to include 'require_relative "petstore-simple.yaml_Pets"'
        end

        it 'creates a file that requires all request files when name_for_module is :tags_file' do
            file_name = './spec/fixtures/v2.0/yaml/uber.yaml'
            OpenApiImport.from file_name, name_for_module: :tags_file
            content = File.read("#{file_name}.rb")
            expect(content).to include 'require_relative "uber.yaml_Products"'
            expect(content).to include 'require_relative "uber.yaml_Estimates"'
            expect(content).to include 'require_relative "uber.yaml_User"'
        end
        
        it 'logs warning when unsupported http method is on the swagger file' do
            file_name = './spec/fixtures/wrong/petstore-minimal_not_supported_method.yaml'
            OpenApiImport.from file_name
            expect(File.exist?("#{file_name}_open_api_import.log")).to eq true
            expect(File.read("#{file_name}_open_api_import.log")).to match /Not imported method: head for path: /
        end

        it 'creates the name of the method using the http method and the path when create_method_name is :path' do
            file_name = './spec/fixtures/v2.0/yaml/petstore-minimal.yaml'
            File.delete("#{file_name}.rb") if File.exist?("#{file_name}.rb")
            OpenApiImport.from file_name, create_method_name: :path
            expect(File.exist?("#{file_name}.rb")).to eq true
            expect(File.read("#{file_name}.rb")).to include("def self.get_pets(")
        end

        it 'creates the name of the method using the operationId in snake_case when create_method_name is :operation_id' do
            file_name = './spec/fixtures/v2.0/yaml/petstore-simple.yaml'
            File.delete("#{file_name}.rb") if File.exist?("#{file_name}.rb")
            OpenApiImport.from file_name, create_method_name: :operation_id
            expect(File.exist?("#{file_name}.rb")).to eq true
            expect(File.read("#{file_name}.rb")).to include("def self.find_pets(")
        end

        it 'creates the name of the method using the operationId like it is when create_method_name is :operationId' do
            file_name = './spec/fixtures/v2.0/yaml/petstore-simple.yaml'
            File.delete("#{file_name}.rb") if File.exist?("#{file_name}.rb")
            OpenApiImport.from file_name, create_method_name: :operationId
            expect(File.exist?("#{file_name}.rb")).to eq true
            expect(File.read("#{file_name}.rb")).to include("def self.findPets(")
        end

        it 'creates the name of the method using the default "undefined" when no operationId supplied' do
            file_name = './spec/fixtures/v2.0/yaml/petstore-minimal.yaml'
            File.delete("#{file_name}.rb") if File.exist?("#{file_name}.rb")
            OpenApiImport.from file_name, create_method_name: :operation_id
            expect(File.exist?("#{file_name}.rb")).to eq true
            expect(File.read("#{file_name}.rb")).to include("def self.undefined(")
        end

        it 'creates all end points and http methods' do
            file_name = './spec/fixtures/v2.0/yaml/petstore-simple.yaml'
            File.delete("#{file_name}.rb") if File.exist?("#{file_name}.rb")
            OpenApiImport.from file_name, create_method_name: :operation_id
            expect(File.exist?("#{file_name}.rb")).to eq true
            content = File.read("#{file_name}.rb")
            expect(content).to include('def self.find_pets(')
            expect(content).to include('def self.add_pet(')
            expect(content).to include('def self.find_pet_by_id(')
            expect(content).to include('def self.delete_pet(')
        end

        it 'creates module Root when no folder in path' do
            file_name = './spec/fixtures/v2.0/yaml/petstore-simple.yaml'
            File.delete("#{file_name}.rb") if File.exist?("#{file_name}.rb")
            OpenApiImport.from file_name, create_method_name: :operation_id
            expect(File.exist?("#{file_name}.rb")).to eq true
            content = File.read("#{file_name}.rb")
            expect(content).to include('module Root')
        end

        it 'creates module with name of folder in path' do
            file_name = './spec/fixtures/v2.0/yaml/uber.yaml'
            File.delete("#{file_name}.rb") if File.exist?("#{file_name}.rb")
            OpenApiImport.from file_name, create_method_name: :operation_id
            expect(File.exist?("#{file_name}.rb")).to eq true
            content = File.read("#{file_name}.rb")
            expect(content).to include('module Estimates')
        end
        
        it 'adds info in comments: operationId, method, summary, description and parameters' do
            file_name = './spec/fixtures/v2.0/yaml/uber.yaml'
            File.delete("#{file_name}.rb") if File.exist?("#{file_name}.rb")
            OpenApiImport.from file_name, create_method_name: :operation_id
            expect(File.exist?("#{file_name}.rb")).to eq true
            content = File.read("#{file_name}.rb")
            expect(content).to include('# operationId: undefined, method: get')
            expect(content).to include('# summary: Price Estimates')
            expect(content).to include('The Price Estimates endpoint returns an estimated price')
            expect(content).to include('latitude: (number) (required) Latitude component of location.')
        end

        it 'adds method key on request hash' do
            file_name = './spec/fixtures/v2.0/yaml/petstore-simple.yaml'
            File.delete("#{file_name}.rb") if File.exist?("#{file_name}.rb")
            OpenApiImport.from file_name, create_method_name: :operation_id
            expect(File.exist?("#{file_name}.rb")).to eq true
            content = File.read("#{file_name}.rb")
            eval(content)
            req = Swagger::SwaggerPetstore::V1_0_0::Root.find_pets
            expect(req.key?(:method)).to eq true
            expect(req[:method]).to eq :get
        end

        it 'adds name key on request hash' do
            file_name = './spec/fixtures/v2.0/yaml/petstore-simple.yaml'
            File.delete("#{file_name}.rb") if File.exist?("#{file_name}.rb")
            OpenApiImport.from file_name, create_method_name: :operation_id
            expect(File.exist?("#{file_name}.rb")).to eq true
            content = File.read("#{file_name}.rb")
            eval(content)
            req = Swagger::SwaggerPetstore::V1_0_0::Root.find_pets
            expect(req.key?(:name)).to eq true
            expect(req[:name]).to eq "Root.find_pets"
        end

        it 'detects version on method_name and add it to module' do
            file_name = './spec/fixtures/v3.0/petstore_with_version.yaml'
            OpenApiImport.from file_name
            expect(File.read("#{file_name}.rb")).to match /module\sV1Pets/
        end

        it 'detects version on method_name and remove it' do
            file_name = './spec/fixtures/v3.0/petstore_with_version.yaml'
            OpenApiImport.from file_name
            expect(File.read("#{file_name}.rb")).to match /def\sself\.list_pets/
        end

        it 'adds constants if create_constants' do
            file_name = './spec/fixtures/v2.0/yaml/uber.yaml'
            File.delete("#{file_name}.rb") if File.exist?("#{file_name}.rb")
            OpenApiImport.from file_name, create_method_name: :path, create_constants: true
            expect(File.exist?("#{file_name}.rb")).to eq true
            content = File.read("#{file_name}.rb")
            expect(content).to include('def self.get_products(latitude: LATITUDE, longitude: LONGITUDE)')
        end

        it 'converts patterns from \\x to \\u' do
            file_name = './spec/fixtures/v2.0/yaml/petstore.yaml'
            File.delete("#{file_name}.rb") if File.exist?("#{file_name}.rb")
            OpenApiImport.from file_name, create_method_name: :operation_id
            expect(File.exist?("#{file_name}.rb")).to eq true
            content = File.read("#{file_name}.rb")
            eval(content)
            req = Swagger::SwaggerPetstore::V1_0_0::Root.list_pets
            expect(req.key?(:data_pattern)).to eq true
            expect(req[:data_pattern].key?(:name)).to eq true
            expect(req[:data_pattern][:name].to_s).to eq '(?-mix:^[a-z\u00DF-\u00FF][a-z0-9\-_\u{DF}-\u{FF}]*$)'
        end


    end


end
