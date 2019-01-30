require 'open_api_import'

RSpec.describe OpenApiImport do

    describe '#from' do
        
        it 'adds response codes as keys on responses array' do
            file_name = './spec/fixtures/v2.0/yaml/petstore-simple.yaml'
            File.delete("#{file_name}.rb") if File.exist?("#{file_name}.rb")
            OpenApiImport.from file_name, create_method_name: :operation_id
            expect(File.exist?("#{file_name}.rb")).to eq true
            content = File.read("#{file_name}.rb")
            eval(content)
            req = Swagger::SwaggerPetstore::V1_0_0::Root.find_pets
            expect(req.key?(:responses)).to eq true
            expect(req[:responses].class).to eq Hash
            expect(req[:responses].keys).to eq  [:'200', :'default']
        end

        it 'adds the message for the response on responses array' do
            file_name = './spec/fixtures/v2.0/yaml/petstore-simple.yaml'
            File.delete("#{file_name}.rb") if File.exist?("#{file_name}.rb")
            OpenApiImport.from file_name, create_method_name: :operation_id
            expect(File.exist?("#{file_name}.rb")).to eq true
            content = File.read("#{file_name}.rb")
            eval(content)
            req = Swagger::SwaggerPetstore::V1_0_0::Root.find_pets
            expect(req[:responses][:'200'].key?(:message)).to eq true
            expect(req[:responses][:'200'][:message]).to eq "pet response"
        end

        it 'adds the data body for the response on responses array' do
            file_name = './spec/fixtures/v2.0/yaml/petstore-simple.yaml'
            File.delete("#{file_name}.rb") if File.exist?("#{file_name}.rb")
            OpenApiImport.from file_name, create_method_name: :operation_id
            expect(File.exist?("#{file_name}.rb")).to eq true
            content = File.read("#{file_name}.rb")
            eval(content)
            req = Swagger::SwaggerPetstore::V1_0_0::Root.find_pets
            expect(req[:responses][:'200'].key?(:data)).to eq true
            data = [{
                name: "string",
                tag: "string",
                id: 0,
            }]
            expect(req[:responses][:'200'][:data]).to eq data
        end


    end


end
