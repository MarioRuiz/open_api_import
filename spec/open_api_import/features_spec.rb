require "open_api_import"

RSpec.describe OpenApiImport do
  describe ".from" do
    describe "mock_response option" do
      it "includes mock_response when mock_response is true" do
        file_name = "./spec/fixtures/v2.0/yaml/petstore-simple.yaml"
        FileUtils.rm_f("#{file_name}.rb")
        OpenApiImport.from file_name, create_method_name: :operation_id, mock_response: true
        expect(File.exist?("#{file_name}.rb")).to eq true
        content = File.read("#{file_name}.rb")
        expect(content).to include("mock_response:")
      end

      it "includes response code and message in mock_response" do
        file_name = "./spec/fixtures/v2.0/yaml/petstore-simple.yaml"
        OpenApiImport.from file_name, create_method_name: :operation_id, mock_response: true
        content = File.read("#{file_name}.rb")
        expect(content).to include("mock_response:")
        expect(content).to include("code:")
        expect(content).to include("message:")
      end
    end

    describe "silent option" do
      it "suppresses output when silent is true" do
        file_name = "./spec/fixtures/v2.0/yaml/petstore-minimal.yaml"
        expect do
          OpenApiImport.from file_name, silent: true
        end.not_to output(/Requests file/).to_stdout
      end

      it "displays output when silent is false" do
        file_name = "./spec/fixtures/v2.0/yaml/petstore-minimal.yaml"
        expect do
          OpenApiImport.from file_name, silent: false
        end.to output(/Requests file/).to_stdout
      end

      it "still creates log file when silent" do
        file_name = "./spec/fixtures/v2.0/yaml/petstore-minimal.yaml"
        OpenApiImport.from file_name, silent: true
        expect(File.exist?("#{file_name}_open_api_import.log")).to eq true
      end
    end

    describe "error handling" do
      it "raises ParseError for unparseable files" do
        file_name = "./spec/fixtures/wrong/invalid_syntax.yaml"
        File.write(file_name, "{{invalid yaml content!!")
        expect do
          OpenApiImport.from file_name
        end.to raise_error(OpenApiImport::ParseError)
      ensure
        FileUtils.rm_f(file_name)
        FileUtils.rm_f("#{file_name}_open_api_import.log")
      end

      it "handles missing files by returning nil" do
        result = OpenApiImport.from "./nonexistent_file.yaml"
        expect(result).to be_nil
      end

      it "logs unsupported swagger version" do
        file_name = "./spec/fixtures/wrong/petstore-minimal.yaml"
        OpenApiImport.from file_name
        log = File.read("#{file_name}_open_api_import.log")
        expect(log).to include("Unsupported Swagger version")
      end
    end

    describe "return_data option" do
      it "returns hash of generated content without writing files" do
        file_name = "./spec/fixtures/v2.0/yaml/petstore-minimal.yaml"
        temp_rb = "#{file_name}.rb"
        FileUtils.rm_f(temp_rb)

        result = OpenApiImport.from file_name, return_data: true, silent: true
        expect(result).to be_a(Hash)
        expect(result.keys.first).to end_with(".rb")
        expect(result.values.first).to include("module Swagger")
      end

      it "returns multiple files for path_file mode" do
        file_name = "./spec/fixtures/v2.0/yaml/petstore-simple.yaml"
        result = OpenApiImport.from file_name, name_for_module: :path_file, return_data: true, silent: true
        expect(result).to be_a(Hash)
        expect(result.size).to be > 1
      end
    end

    describe "formData parameters" do
      it "generates data_examples with formData values" do
        file_name = "./spec/fixtures/v2.0/yaml/formdata_api.yaml"
        FileUtils.rm_f("#{file_name}.rb")
        OpenApiImport.from file_name, create_method_name: :operation_id, silent: true
        expect(File.exist?("#{file_name}.rb")).to eq true
        content = File.read("#{file_name}.rb")
        expect(content).to include("data_examples:")
        expect(content).to include("filename:")
        expect(content).to include("enabled:")
        expect(content).to include("size:")
        expect(content).to include("ratio:")
      end
    end

    describe "header parameters" do
      it "does not crash on header parameters" do
        file_name = "./spec/fixtures/v2.0/yaml/formdata_api.yaml"
        result = OpenApiImport.from file_name, create_method_name: :operation_id, silent: true
        expect(result).to eq true
      end
    end

    describe "shared path-level parameters" do
      it "distributes shared parameters to all methods on the path" do
        file_name = "./spec/fixtures/v2.0/yaml/shared_params.yaml"
        FileUtils.rm_f("#{file_name}.rb")
        OpenApiImport.from file_name, create_method_name: :operation_id, silent: true
        content = File.read("#{file_name}.rb")
        expect(content).to include("def self.get_item")
        expect(content).to include("def self.delete_item")
        expect(content).to match(/get_item.*id/m)
        expect(content).to match(/delete_item.*id/m)
      end
    end

    describe "readOnly and default values" do
      it "generates data_read_only key" do
        file_name = "./spec/fixtures/v2.0/yaml/readonly_defaults.yaml"
        FileUtils.rm_f("#{file_name}.rb")
        OpenApiImport.from file_name, create_method_name: :operation_id, silent: true
        content = File.read("#{file_name}.rb")
        expect(content).to include("data_read_only:")
      end

      it "generates data_default key" do
        file_name = "./spec/fixtures/v2.0/yaml/readonly_defaults.yaml"
        OpenApiImport.from file_name, create_method_name: :operation_id, silent: true
        content = File.read("#{file_name}.rb")
        expect(content).to include("data_default:")
        expect(content).to include("active")
      end
    end

    describe "oneOf body schemas" do
      it "generates data_examples from oneOf schemas" do
        file_name = "./spec/fixtures/v3.0/oneof_api.yaml"
        FileUtils.rm_f("#{file_name}.rb")
        OpenApiImport.from file_name, create_method_name: :operation_id, silent: true
        expect(File.exist?("#{file_name}.rb")).to eq true
        content = File.read("#{file_name}.rb")
        expect(content).to include("def self.create_pet")
        expect(content).to include("data_examples:")
      end
    end

    describe "anyOf body schemas" do
      it "generates data_examples from anyOf schemas" do
        file_name = "./spec/fixtures/v3.0/oneof_api.yaml"
        OpenApiImport.from file_name, create_method_name: :operation_id, silent: true
        content = File.read("#{file_name}.rb")
        expect(content).to include("def self.create_animal")
        expect(content).to include("data_examples:")
      end
    end

    describe "OpenAPI 3.0 support" do
      it "handles v3.0 specs with requestBody" do
        file_name = "./spec/fixtures/v3.0/petstore.yaml"
        FileUtils.rm_f("#{file_name}.rb")
        result = OpenApiImport.from file_name, silent: true
        expect(result).to eq true
        expect(File.exist?("#{file_name}.rb")).to eq true
      end

      it "handles v3.0 api-with-examples (content -> examples)" do
        file_name = "./spec/fixtures/v3.0/api-with-examples.yaml"
        FileUtils.rm_f("#{file_name}.rb")
        result = OpenApiImport.from file_name, create_method_name: :operation_id, silent: true
        expect(result).to eq true
        content = File.read("#{file_name}.rb")
        expect(content).to include("responses:")
      end

      it "handles v3.0 expanded petstore with allOf in requestBody" do
        file_name = "./spec/fixtures/v3.0/petstore-expanded.yaml"
        FileUtils.rm_f("#{file_name}.rb")
        result = OpenApiImport.from file_name, create_method_name: :operation_id, silent: true
        expect(result).to eq true
        content = File.read("#{file_name}.rb")
        expect(content).to include("data_examples:")
      end

      it "handles v2.0 api-with-examples (examples -> application/json)" do
        file_name = "./spec/fixtures/v2.0/yaml/api-with-examples.yaml"
        FileUtils.rm_f("#{file_name}.rb")
        result = OpenApiImport.from file_name, create_method_name: :operation_id, silent: true
        expect(result).to eq true
        content = File.read("#{file_name}.rb")
        expect(content).to include("responses:")
      end
    end

    describe "OpenAPI 3.1 support" do
      it "handles v3.1 specs with nullable type arrays" do
        file_name = "./spec/fixtures/v3.0/petstore_3_1.yaml"
        FileUtils.rm_f("#{file_name}.rb")
        result = OpenApiImport.from file_name, silent: true
        expect(result).to eq true
        expect(File.exist?("#{file_name}.rb")).to eq true
        content = File.read("#{file_name}.rb")
        expect(content).to include("def self.list_pets")
        expect(content).to include("def self.create_pet")
      end
    end

    describe "response with array of items (type only)" do
      it "generates response with array type items" do
        file_name = "./spec/fixtures/v2.0/yaml/formdata_api.yaml"
        OpenApiImport.from file_name, create_method_name: :operation_id, silent: true
        content = File.read("#{file_name}.rb")
        expect(content).to include("responses:")
      end
    end

    describe "version constant" do
      it "has a VERSION constant matching semver" do
        expect(OpenApiImport::VERSION).to match(/\d+\.\d+\.\d+/)
      end
    end

    describe "ParseError class" do
      it "is a subclass of StandardError" do
        expect(OpenApiImport::ParseError.ancestors).to include(StandardError)
      end

      it "can be instantiated with a message" do
        error = OpenApiImport::ParseError.new("test error")
        expect(error.message).to eq("test error")
      end
    end

    describe "JSON format support" do
      it "handles JSON swagger files" do
        file_name = "./spec/fixtures/v2.0/json/petstore-simple.json"
        FileUtils.rm_f("#{file_name}.rb")
        result = OpenApiImport.from file_name, create_method_name: :operation_id, silent: true
        expect(result).to eq true
        content = File.read("#{file_name}.rb")
        expect(content).to include("def self.find_pets")
      end
    end

    describe "uber API (complex multi-tag)" do
      it "creates all tag-based modules with :tags" do
        file_name = "./spec/fixtures/v2.0/yaml/uber.yaml"
        OpenApiImport.from file_name, name_for_module: :tags, silent: true
        content = File.read("#{file_name}.rb")
        expect(content).to include("module Products")
        expect(content).to include("module Estimates")
        expect(content).to include("module User")
      end
    end

    describe "create_constants with query params" do
      it "generates constants with operationId method naming" do
        file_name = "./spec/fixtures/v2.0/yaml/uber.yaml"
        FileUtils.rm_f("#{file_name}.rb")
        OpenApiImport.from file_name, create_method_name: :operationId, create_constants: true, silent: true
        content = File.read("#{file_name}.rb")
        expect(content).to include("LATITUDE")
      end
    end
  end
end
