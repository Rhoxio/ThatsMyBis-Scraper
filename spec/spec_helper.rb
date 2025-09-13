# frozen_string_literal: true

require 'bundler/setup'
require 'dotenv/load'
require 'webmock/rspec'
require 'vcr'

# Load the main application
require_relative '../lib/thatsmybis_scraper'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Configure WebMock
  WebMock.disable_net_connect!(allow_localhost: true)

  # Configure VCR
  VCR.configure do |c|
    c.cassette_library_dir = 'spec/vcr_cassettes'
    c.hook_into :webmock
    c.configure_rspec_metadata!
  end

  # Prevent WebDriver from actually running in tests
  config.before(:each) do
    # Mock Selenium WebDriver to prevent actual browser automation
    mock_driver = double('MockDriver')
    allow(mock_driver).to receive(:navigate)
    allow(mock_driver).to receive(:page_source)
    allow(mock_driver).to receive(:current_url)
    allow(mock_driver).to receive(:execute_script)
    allow(mock_driver).to receive(:quit)
    
    allow(Selenium::WebDriver).to receive(:for).and_return(mock_driver)
    allow_any_instance_of(Selenium::WebDriver::Chrome::Options).to receive(:add_argument)
    allow_any_instance_of(Selenium::WebDriver::Chrome::Options).to receive(:add_preference)
    allow_any_instance_of(Selenium::WebDriver::Chrome::Options).to receive(:add_experimental_option)
    allow(FileUtils).to receive(:mkdir_p)
    allow(Dir).to receive(:exist?).and_return(false)
  end
end
