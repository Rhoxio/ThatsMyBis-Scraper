# frozen_string_literal: true

require 'spec_helper'
require 'thatsmybis_scraper'

RSpec.describe ThatsMyBisScraper::Utils::WebDriverManager do
  describe '.instance' do
    it 'returns singleton instance' do
      instance1 = described_class.instance
      instance2 = described_class.instance
      
      expect(instance1).to eq(instance2)
      expect(instance1).to be_a(described_class)
    end
  end

  describe '#initialize' do
    let(:manager) { described_class.new }

    it 'sets default options' do
      expect(manager.instance_variable_get(:@options)[:headless]).to be false
      expect(manager.instance_variable_get(:@options)[:user_agent]).to include('Mozilla')
    end

    it 'initializes driver as nil' do
      expect(manager.instance_variable_get(:@driver)).to be_nil
    end
  end

  describe '#driver' do
    let(:manager) { described_class.new }

    before do
      # Mock Selenium WebDriver creation
      allow(Selenium::WebDriver).to receive(:for).and_return(double('Driver'))
      allow(FileUtils).to receive(:mkdir_p)
    end

    it 'creates driver on first call' do
      expect(Selenium::WebDriver).to receive(:for).with(:chrome, options: instance_of(Selenium::WebDriver::Chrome::Options))
      
      driver = manager.driver
      expect(driver).to be_a(RSpec::Mocks::Double)
    end

    it 'returns same driver on subsequent calls' do
      driver1 = manager.driver
      driver2 = manager.driver
      
      expect(driver1).to eq(driver2)
    end
  end

  describe '#cleanup' do
    let(:manager) { described_class.new }
    let(:mock_driver) { double('Driver') }

    before do
      manager.instance_variable_set(:@driver, mock_driver)
    end

    it 'quits driver if it exists' do
      expect(mock_driver).to receive(:quit)
      
      manager.cleanup
      
      expect(manager.instance_variable_get(:@driver)).to be_nil
    end

    it 'does nothing if no driver exists' do
      manager.instance_variable_set(:@driver, nil)
      
      expect { manager.cleanup }.not_to raise_error
    end
  end

  describe '#create_driver' do
    let(:manager) { described_class.new }

    before do
      allow(FileUtils).to receive(:mkdir_p)
      allow(Selenium::WebDriver::Chrome::Options).to receive(:new).and_return(double('Options'))
      allow_any_instance_of(Selenium::WebDriver::Chrome::Options).to receive(:add_argument)
      allow_any_instance_of(Selenium::WebDriver::Chrome::Options).to receive(:add_preference)
      allow_any_instance_of(Selenium::WebDriver::Chrome::Options).to receive(:add_experimental_option)
      allow(Selenium::WebDriver).to receive(:for).and_return(double('Driver'))
    end

    it 'creates user data directory' do
      expect(FileUtils).to receive(:mkdir_p).with(instance_of(String))
      
      manager.send(:create_driver)
    end

    it 'creates Chrome driver with options' do
      expect(Selenium::WebDriver).to receive(:for).with(:chrome, options: instance_of(Selenium::WebDriver::Chrome::Options))
      
      manager.send(:create_driver)
    end

    it 'configures Chrome options correctly' do
      mock_options = double('Options')
      allow(Selenium::WebDriver::Chrome::Options).to receive(:new).and_return(mock_options)
      
      expect(mock_options).to receive(:add_argument).with('--no-sandbox')
      expect(mock_options).to receive(:add_argument).with('--disable-dev-shm-usage')
      expect(mock_options).to receive(:add_argument).with('--disable-blink-features=AutomationControlled')
      expect(mock_options).to receive(:add_experimental_option).with('excludeSwitches', ['enable-automation'])
      expect(mock_options).to receive(:add_experimental_option).with('useAutomationExtension', false)
      
      manager.send(:create_driver)
    end

    it 'handles headless mode' do
      manager.instance_variable_get(:@options)[:headless] = true
      
      mock_options = double('Options')
      allow(Selenium::WebDriver::Chrome::Options).to receive(:new).and_return(mock_options)
      allow(mock_options).to receive(:add_argument)
      allow(mock_options).to receive(:add_preference)
      allow(mock_options).to receive(:add_experimental_option)
      
      expect(mock_options).to receive(:add_argument).with('--headless')
      
      manager.send(:create_driver)
    end
  end
end
