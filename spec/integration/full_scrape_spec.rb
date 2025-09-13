# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'
require 'thatsmybis_scraper'

RSpec.describe 'Full Scrape Integration', type: :integration do
  let(:roster_url) { 'https://thatsmybis.com/11258/chonglers/roster' }
  let(:character_url) { 'https://thatsmybis.com/11258/chonglers/c/540876/aelektra' }

  let(:roster_html) do
    <<~HTML
      <html>
        <body>
          <div class="dropdown">
            <a class="dropdown-item" href="/11258/chonglers/c/540876/aelektra">
              <span class="fas fa-fw fa-user"></span> Profile
            </a>
          </div>
        </body>
      </html>
    HTML
  end

  let(:character_html) do
    <<~HTML
      <html>
        <head>
          <title>Ælektra - That's My BIS</title>
        </head>
        <body>
          <h1>
            <a href="#{character_url}" class="text-shaman">Ælektra</a>
          </h1>
          <div class="row mb-3 pt-3 bg-light rounded">
            <div class="col-12 mb-2">
              <span class="text-legendary font-weight-bold">
                <span class="fas fa-fw fa-scroll-old"></span>
                Wishlist 1
              </span>
            </div>
            <div class="col-12 pb-3">
              <ol class="js-wishlist-unsorted">
                <li>
                  <span class="font-weight-medium">
                    <a href="https://thatsmybis.com/11258/chonglers/i/51242/sanctified-frost-witchs-faceguard" 
                       data-wowhead="item=51242?domain=wotlk" class="q4">
                      <span class="iconsmall">
                        <ins style='background-image: url("https://wow.zamimg.com/images/wow/icons/small/inv_helmet_169.jpg");'></ins>
                      </span>
                      <span>Sanctified Frost Witch's Faceguard</span>
                    </a>
                  </span>
                </li>
              </ol>
            </div>
          </div>
        </body>
      </html>
    HTML
  end

  before do
    WebMock.enable!
    
    # Mock roster page
    stub_request(:get, roster_url)
      .to_return(status: 200, body: roster_html, headers: { 'Content-Type' => 'text/html' })
    
    # Mock character page
    stub_request(:get, character_url)
      .to_return(status: 200, body: character_html, headers: { 'Content-Type' => 'text/html' })
  end

  after do
    WebMock.disable!
  end

  describe 'End-to-end scraping workflow' do
    it 'completes full scrape workflow' do
      # Mock WebDriver to avoid actual browser automation in tests
      mock_driver = double('WebDriver')
      allow(mock_driver).to receive(:navigate)
      allow(mock_driver).to receive(:page_source).and_return(roster_html, character_html)
      allow(mock_driver).to receive(:current_url).and_return(roster_url, character_url)
      allow(mock_driver).to receive(:execute_script)
      
      driver_manager = ThatsMyBisScraper::Utils::WebDriverManager.instance
      allow(driver_manager).to receive(:driver).and_return(mock_driver)
      allow(driver_manager).to receive(:cleanup)

      # Test the full workflow
      scraper = ThatsMyBisScraper::Scrapers::BaseScraper.new(driver: mock_driver)
      roster_scraper = ThatsMyBisScraper::Scrapers::RosterScraper.new(nil, scraper: scraper)
      character_scraper = ThatsMyBisScraper::Scrapers::CharacterScraper.new(scraper)

      # Step 1: Collect profile links
      profile_links = roster_scraper.collect_profile_links
      expect(profile_links).to be_an(Array)
      expect(profile_links.length).to eq(1)
      expect(profile_links.first[:player_name]).to eq('aelektra')

      # Step 2: Scrape character page
      character_data = character_scraper.scrape_character_page(character_url)
      expect(character_data[:name]).to eq('Ælektra')
      expect(character_data[:wishlists]).to be_an(Array)
      expect(character_data[:wishlists].first[:items]).to be_an(Array)
      expect(character_data[:wishlists].first[:items].first[:name]).to eq('Sanctified Frost Witch\'s Faceguard')
    end
  end

  describe 'Duplicate URL handling' do
    it 'handles duplicate URLs correctly' do
      # Create roster with duplicate character links
      duplicate_roster_html = <<~HTML
        <html>
          <body>
            <div class="dropdown">
              <a class="dropdown-item" href="/11258/chonglers/c/540876/aelektra">
                <span class="fas fa-fw fa-user"></span> Profile
              </a>
              <a class="dropdown-item" href="/11258/chonglers/c/540876/aelektra">
                <span class="fas fa-fw fa-user"></span> Profile
              </a>
            </div>
          </body>
        </html>
      HTML

      stub_request(:get, roster_url)
        .to_return(status: 200, body: duplicate_roster_html, headers: { 'Content-Type' => 'text/html' })

      mock_driver = double('WebDriver')
      allow(mock_driver).to receive(:navigate)
      allow(mock_driver).to receive(:page_source).and_return(duplicate_roster_html)
      allow(mock_driver).to receive(:current_url).and_return(roster_url)
      allow(mock_driver).to receive(:execute_script)

      scraper = ThatsMyBisScraper::Scrapers::BaseScraper.new(driver: mock_driver)
      roster_scraper = ThatsMyBisScraper::Scrapers::RosterScraper.new(nil, scraper: scraper)

      profile_links = roster_scraper.collect_profile_links
      
      # Should deduplicate URLs
      unique_urls = profile_links.map { |link| link[:url] }.uniq
      expect(unique_urls.length).to eq(1)
      expect(profile_links.length).to eq(1)
    end
  end

  describe 'Error handling' do
    it 'handles network errors gracefully' do
      stub_request(:get, roster_url)
        .to_return(status: 500, body: 'Internal Server Error')

      mock_driver = double('WebDriver')
      allow(mock_driver).to receive(:navigate)
      allow(mock_driver).to receive(:page_source).and_return('')
      allow(mock_driver).to receive(:current_url).and_return(roster_url)
      allow(mock_driver).to receive(:execute_script)

      scraper = ThatsMyBisScraper::Scrapers::BaseScraper.new(driver: mock_driver)
      roster_scraper = ThatsMyBisScraper::Scrapers::RosterScraper.new(nil, scraper: scraper)

      expect { roster_scraper.collect_profile_links }.not_to raise_error
    end

    it 'handles missing elements gracefully' do
      empty_html = '<html><body></body></html>'

      stub_request(:get, roster_url)
        .to_return(status: 200, body: empty_html, headers: { 'Content-Type' => 'text/html' })

      mock_driver = double('WebDriver')
      allow(mock_driver).to receive(:navigate)
      allow(mock_driver).to receive(:page_source).and_return(empty_html)
      allow(mock_driver).to receive(:current_url).and_return(roster_url)
      allow(mock_driver).to receive(:execute_script)

      scraper = ThatsMyBisScraper::Scrapers::BaseScraper.new(driver: mock_driver)
      roster_scraper = ThatsMyBisScraper::Scrapers::RosterScraper.new(nil, scraper: scraper)

      profile_links = roster_scraper.collect_profile_links
      expect(profile_links).to be_an(Array)
      expect(profile_links.length).to eq(0)
    end
  end
end
