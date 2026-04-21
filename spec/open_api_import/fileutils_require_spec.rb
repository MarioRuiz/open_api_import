# frozen_string_literal: true

require "open_api_import"

RSpec.describe "OpenApiImport stdlib dependencies" do
  it "loads FileUtils when requiring the gem (regression for OpenApiImport.from)" do
    expect(defined?(FileUtils)).to eq("constant")
  end
end
