require 'open_api_import'

#todo: add test for data_examples to include values according to type in case no examples supplied, fex: doo: 0 instead of doo: "" if type is intenger
RSpec.describe OpenApiImport do

    describe '#from' do
        
        it 'adds the data examples specified' do
            file_name = './spec/fixtures/v2.0/yaml/petstore-simple.yaml'
            File.delete("#{file_name}.rb") if File.exist?("#{file_name}.rb")
            OpenApiImport.from file_name, create_method_name: :operation_id
            expect(File.exist?("#{file_name}.rb")).to eq true
            content = File.read("#{file_name}.rb")
            eval(content)
            req = Swagger::SwaggerPetstore::V1_0_0::Root.add_pet()
            expect(req.key?(:data_examples)).to eq true
            expect(req[:data_examples].class).to eq Array
            expect(req[:data_examples]).to eq  ([{name: "string", tag: "string"}])
        end
    end
end
