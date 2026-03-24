
require 'coveralls'
Coveralls.wear!

require 'open_api_import'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups

  config.filter_run_when_matching :focus

  config.order = :defined

  config.after(:suite) do
    Dir.glob("spec/fixtures/**/*.rb").each { |f| File.delete(f) }
    Dir.glob("spec/fixtures/**/*.log").each { |f| File.delete(f) }
    Dir.glob("*.log").each { |f| File.delete(f) }
  end
end
