require "open_api_import"

using OpenApiImportStringExt

RSpec.describe OpenApiImportStringExt do
  describe "#snake_case" do
    it "converts CamelCase to snake_case" do
      expect("CamelCase".snake_case).to eq "camel_case"
    end

    it "converts PascalCase to snake_case" do
      expect("PascalCaseString".snake_case).to eq "pascal_case_string"
    end

    it "handles consecutive uppercase letters" do
      expect("HTMLParser".snake_case).to eq "html_parser"
    end

    it "replaces non-word characters with underscores" do
      expect("hello-world".snake_case).to eq "hello_world"
    end

    it "collapses multiple underscores" do
      expect("hello__world".snake_case).to eq "hello_world"
    end

    it "handles already snake_case strings" do
      expect("already_snake".snake_case).to eq "already_snake"
    end

    it "converts spaces to underscores" do
      expect("hello world".snake_case).to eq "hello_world"
    end

    it "handles path-like strings" do
      expect("listUsers".snake_case).to eq "list_users"
    end

    it "handles empty strings" do
      expect("".snake_case).to eq ""
    end

    it "handles all-uppercase strings" do
      expect("API".snake_case).to eq "api"
    end

    it "handles strings with numbers" do
      expect("v2GetUser".snake_case).to eq "v2get_user"
    end

    it "handles special characters" do
      expect("hello/world".snake_case).to eq "hello_world"
    end

    it "handles single character" do
      expect("A".snake_case).to eq "a"
    end
  end

  describe "#camel_case" do
    it "converts snake_case to CamelCase" do
      expect("hello_world".camel_case).to eq "HelloWorld"
    end

    it "converts hyphenated strings" do
      expect("hello-world".camel_case).to eq "HelloWorld"
    end

    it "returns already CamelCase strings unchanged" do
      expect("HelloWorld".camel_case).to eq "HelloWorld"
    end

    it "converts space-separated strings" do
      expect("hello world".camel_case).to eq "HelloWorld"
    end

    it "handles single word lowercase" do
      expect("hello".camel_case).to eq "Hello"
    end

    it "handles empty strings" do
      expect("".camel_case).to eq ""
    end

    it "returns all-caps strings unchanged" do
      expect("API".camel_case).to eq "API"
    end

    it "handles strings starting with uppercase but containing separators" do
      expect("Hello_World".camel_case).to eq "HelloWorld"
    end

    it "handles multiple underscores" do
      expect("one__two___three".camel_case).to eq "OneTwoThree"
    end
  end
end
