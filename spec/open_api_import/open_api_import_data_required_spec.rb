require 'open_api_import'

RSpec.describe OpenApiImport do

    describe '#from' do
        
        it 'adds the required parameters on data body to data_required key' do
            file_name = './spec/fixtures/v2.0/yaml/petstore-simple.yaml'
            File.delete("#{file_name}.rb") if File.exist?("#{file_name}.rb")
            OpenApiImport.from file_name, create_method_name: :operation_id
            expect(File.exist?("#{file_name}.rb")).to eq true
            content = File.read("#{file_name}.rb")
            eval(content)
            req = Swagger::SwaggerPetstore::V1_0_0::Root.add_pet()
            expect(req.key?(:data_required)).to eq true
            expect(req[:data_required].class).to eq Array
            expect(req[:data_required]).to eq  ([:name])
        end

        it 'adds query parameters to path and as non required params on the method when no required' do
            file_name = './spec/fixtures/v2.0/yaml/petstore-simple.yaml'
            File.delete("#{file_name}.rb") if File.exist?("#{file_name}.rb")
            OpenApiImport.from file_name, create_method_name: :operation_id
            expect(File.exist?("#{file_name}.rb")).to eq true
            content = File.read("#{file_name}.rb")
            expect(content).to include 'def self.find_pets(tags: "", limit: "")'
            expect(content).to include 'path: "/api/pets?tags=#{tags}&limit=#{limit}&"'
        end

        it 'adds query parameters to path and as required params on the method when required' do
            file_name = './spec/fixtures/v2.0/yaml/petstore-simple.yaml'
            File.delete("#{file_name}.rb") if File.exist?("#{file_name}.rb")
            OpenApiImport.from file_name, create_method_name: :operation_id
            expect(File.exist?("#{file_name}.rb")).to eq true
            content = File.read("#{file_name}.rb")
            expect(content).to include 'def self.find_pet_by_id(id)'
            expect(content).to include 'path: "/api/pets/#{id}",'
        end


    end
end
