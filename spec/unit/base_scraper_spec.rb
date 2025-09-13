# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'
require 'thatsmybis_scraper'

RSpec.describe ThatsMyBisScraper::Scrapers::BaseScraper do
  let(:scraper) { described_class.new }
  let(:test_url) { 'https://thatsmybis.com/test' }
  let(:mock_html) { '<html><body><h1>Test Page</h1></body></html>' }

  before do
    WebMock.enable!
    stub_request(:get, test_url)
      .to_return(status: 200, body: mock_html, headers: { 'Content-Type' => 'text/html' })
  end

  after do
    WebMock.disable!
  end

  describe '#initialize' do
    it 'sets default values' do
      expect(scraper.instance_variable_get(:@delay)).to eq(1)
      expect(scraper.instance_variable_get(:@max_retries)).to eq(3)
      expect(scraper.instance_variable_get(:@timeout)).to eq(30)
    end

    it 'accepts custom options' do
      custom_scraper = described_class.new(delay: 5, timeout: 60)
      expect(custom_scraper.instance_variable_get(:@delay)).to eq(5)
      expect(custom_scraper.instance_variable_get(:@timeout)).to eq(60)
    end

    it 'accepts external driver' do
      mock_driver = double('WebDriver')
      scraper_with_driver = described_class.new(driver: mock_driver)
      expect(scraper_with_driver.instance_variable_get(:@driver)).to eq(mock_driver)
      expect(scraper_with_driver.instance_variable_get(:@external_driver)).to be true
    end
  end

  describe '#scrape' do
    it 'scrapes a URL and returns Nokogiri document' do
      doc = scraper.scrape(test_url)
      expect(doc).to be_a(Nokogiri::HTML::Document)
      expect(doc.css('h1').text).to eq('Test Page')
    end

    it 'handles HTTP errors gracefully' do
      stub_request(:get, test_url)
        .to_return(status: 404, body: 'Not Found')

      expect { scraper.scrape(test_url) }.to raise_error(ThatsMyBisScraper::Error)
    end

    it 'retries on failure' do
      stub_request(:get, test_url)
        .to_raise(StandardError.new('Network error'))
        .times(2)
        .then.to_return(status: 200, body: mock_html)

      doc = scraper.scrape(test_url)
      expect(doc).to be_a(Nokogiri::HTML::Document)
    end
  end

  describe '#scrape_with_selenium' do
    let(:mock_driver) { double('WebDriver') }
    let(:scraper_with_driver) { described_class.new(driver: mock_driver) }

    before do
      allow(mock_driver).to receive(:navigate)
      allow(mock_driver).to receive(:page_source).and_return(mock_html)
      allow(mock_driver).to receive(:current_url).and_return(test_url)
      allow(scraper_with_driver).to receive(:needs_oauth_login?).and_return(false)
      allow(scraper_with_driver).to receive(:wait_for_page_load)
    end

    it 'uses external driver when provided' do
      expect(mock_driver).to receive(:navigate).with(test_url)
      expect(scraper_with_driver).to receive(:wait_for_page_load)
      
      doc = scraper_with_driver.scrape_with_selenium(test_url)
      expect(doc).to be_a(Nokogiri::HTML::Document)
    end

    it 'handles OAuth login detection' do
      allow(scraper_with_driver).to receive(:needs_oauth_login?).and_return(true)
      allow(scraper_with_driver).to receive(:handle_oauth_login)
      
      expect(scraper_with_driver).to receive(:handle_oauth_login)
      
      doc = scraper_with_driver.scrape_with_selenium(test_url)
      expect(doc).to be_a(Nokogiri::HTML::Document)
    end
  end

  describe '#needs_oauth_login?' do
    let(:mock_driver) { double('WebDriver') }
    let(:scraper_with_driver) { described_class.new(driver: mock_driver) }

    it 'detects login pages by URL' do
      allow(mock_driver).to receive(:current_url).and_return('https://example.com/login')
      allow(mock_driver).to receive(:page_source).and_return('')

      expect(scraper_with_driver.send(:needs_oauth_login?)).to be true
    end

    it 'detects login pages by content' do
      allow(mock_driver).to receive(:current_url).and_return('https://example.com/page')
      allow(mock_driver).to receive(:page_source).and_return('Please log in to continue')

      expect(scraper_with_driver.send(:needs_oauth_login?)).to be true
    end

    it 'does not trigger on normal pages' do
      allow(mock_driver).to receive(:current_url).and_return('https://example.com/roster')
      allow(mock_driver).to receive(:page_source).and_return('Character roster page')

      expect(scraper_with_driver.send(:needs_oauth_login?)).to be false
    end
  end
end
