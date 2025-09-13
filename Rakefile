# frozen_string_literal: true

require 'bundler/setup'

desc 'Run RuboCop'
task :rubocop do
  sh 'bundle exec rubocop'
end

desc 'Clean up artifacts'
task :clean do
  sh 'rm -rf .rspec_status'
  sh 'rm -rf coverage'
end

task :default => :rubocop
