require "rake"
require "rspec/core/rake_task"
RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = Dir.glob("spec/**/*_spec.rb")
  t.rspec_opts = "--format documentation"
end

begin
  require "rubocop/rake_task"
  RuboCop::RakeTask.new(:rubocop)
rescue LoadError
  desc "RuboCop not available"
  task :rubocop do
    puts "RuboCop is not installed. Run: gem install rubocop"
  end
end

task default: [:spec]
