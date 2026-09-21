# frozen_string_literal: true

require "open_api_import"
require "tmpdir"

using OpenApiImportStringExt

RSpec.describe "generated source safety" do
  def helper
    @helper ||= Object.new.extend(LibOpenApiImport)
  end

  def uncommented_source(content)
    content.lines.map(&:chomp).reject { |line| line.strip.empty? || line.lstrip.start_with?("#") }
  end

  def spec_with_metadata(title:, version: "1.0", description: "OK", operation_id: "safeOperation", summary: "sum")
    <<~YAML
      openapi: "3.0.0"
      info:
        title: #{title.dump}
        version: #{version.dump}
        description: #{description.dump}
      paths:
        /test:
          get:
            operationId: #{operation_id.dump}
            summary: #{summary.dump}
            responses:
              "200":
                description: "OK"
    YAML
  end

  describe LibOpenApiImport do
    it "prefixes every physical line in comments" do
      lines = helper.send(:comment_lines, "Safe\nsecond line")
      expect(lines).to eq ["# Safe", "# second line"]
    end

    it "builds constant names without punctuation" do
      expect(helper.send(:ruby_constant_name, "Safe;Pwned")).to eq "SafePwned"
      expect(helper.send(:ruby_constant_name, "Safe\nPwned")).to eq "SafePwned"
    end

    it "keeps version module names in snake_case form" do
      expect(helper.send(:ruby_module_version, "1.0.0")).to eq "V1_0_0"
      expect(helper.send(:ruby_module_version, "1.0\n2")).to eq "V1_0_2"
    end

    it "builds method names without newlines or punctuation" do
      expect(helper.send(:ruby_method_name, "safe;Operation")).to eq "safe_operation"
      expect(helper.send(:ruby_method_name, "safeOperation", preserve_case: true)).to eq "safeOperation"
      expect(helper.send(:ruby_method_name, "safe\nOperation", preserve_case: true)).to eq "safe_Operation"
    end
  end

  describe OpenApiImportStringExt do
    it "does not leave semicolons in camel_case identifiers" do
      expect("Safe;Pwned".camel_case).to eq "SafePwned"
    end

    it "does not leave newlines in camel_case identifiers" do
      expect("Safe\nPwned".camel_case).to eq "SafePwned"
    end

    it "still leaves already-valid constants unchanged" do
      expect("HelloWorld".camel_case).to eq "HelloWorld"
      expect("API".camel_case).to eq "API"
    end
  end

  describe "OpenApiImport.from" do
    it "keeps newline metadata inside comments and still loads" do
      Dir.mktmpdir do |dir|
        spec_path = File.join(dir, "spec.yaml")
        File.write(
          spec_path,
          spec_with_metadata(
            title: "Safe\nsecond title line",
            version: "1.0\nsecond version line",
            description: "first desc\nsecond desc line",
            summary: "first summary\nsecond summary line"
          )
        )

        result = OpenApiImport.from(spec_path, silent: true, name_for_module: :fixed)
        expect(result).to eq true

        generated = File.read("#{spec_path}.rb")
        executable = uncommented_source(generated).join("\n")

        expect(generated).to include("# Safe")
        expect(generated).to include("# second title line")
        expect(generated).to include("# version: 1.0")
        expect(generated).to include("# version: second version line")
        expect(generated).to include("#     second desc line")
        expect(generated).to include("#          second summary line")

        expect(executable).not_to include("second title line")
        expect(executable).not_to include("second version line")
        expect(executable).not_to include("second desc line")
        expect(executable).not_to include("second summary line")
        expect(generated).to match(/module\s+SafeSecondTitleLine/)
      end
    end

    it "does not treat punctuation in title as Ruby syntax" do
      Dir.mktmpdir do |dir|
        spec_path = File.join(dir, "spec.yaml")
        File.write(spec_path, spec_with_metadata(title: "Safe;NotAStatement"))

        generated = OpenApiImport.from(spec_path, silent: true, return_data: true).values.first
        expect(generated).to match(/module\s+SafeNotastatement/)
        expect(uncommented_source(generated).join("\n")).not_to include("NotAStatement")
      end
    end
  end
end
