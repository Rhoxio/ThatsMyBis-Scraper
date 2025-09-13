# frozen_string_literal: true

require 'bundler/setup'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = 'spec/**/*_spec.rb'
  t.rspec_opts = '--format documentation'
end

RSpec::Core::RakeTask.new(:spec_unit) do |t|
  t.pattern = 'spec/unit/**/*_spec.rb'
  t.rspec_opts = '--format documentation'
end

RSpec::Core::RakeTask.new(:spec_integration) do |t|
  t.pattern = 'spec/integration/**/*_spec.rb'
  t.rspec_opts = '--format documentation'
end

task :test => :spec
task :default => :spec

desc 'Run RuboCop'
task :rubocop do
  sh 'bundle exec rubocop'
end

desc 'Run all checks (RuboCop + RSpec)'
task :check => [:rubocop, :spec]

desc 'Clean up test artifacts'
task :clean do
  sh 'rm -rf .rspec_status'
  sh 'rm -rf spec/vcr_cassettes'
  sh 'rm -rf coverage'
end
