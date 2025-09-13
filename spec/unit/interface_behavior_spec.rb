# frozen_string_literal: true

require 'spec_helper'
require 'thatsmybis_scraper'

RSpec.describe 'Interface and Behavior Tests', type: :unit do
  describe 'ThatsMyBisScraper module interface' do
    it 'provides main entry point' do
      expect(ThatsMyBisScraper).to respond_to(:run)
    end

    it 'defines custom error class' do
      expect(ThatsMyBisScraper::Error).to be < StandardError
    end

    it 'has CLI module' do
      expect(ThatsMyBisScraper::CLI).to be_a(Module)
    end

    it 'has Scrapers module' do
      expect(ThatsMyBisScraper::Scrapers).to be_a(Module)
    end

    it 'has Utils module' do
      expect(ThatsMyBisScraper::Utils).to be_a(Module)
    end
  end

  describe 'Data structure consistency' do
    let(:mock_html) do
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

    let(:mock_doc) { Nokogiri::HTML(mock_html) }

    it 'RosterScraper returns consistent data structure' do
      mock_scraper = double('BaseScraper')
      allow(mock_scraper).to receive(:scrape).and_return(mock_doc)
      
      roster_scraper = ThatsMyBisScraper::Scrapers::RosterScraper.new(nil, scraper: mock_scraper)
      links = roster_scraper.collect_profile_links

      expect(links).to be_an(Array)
      expect(links.first).to be_a(Hash)
      expect(links.first).to include(:url, :player_name, :profile_text)
      expect(links.first[:url]).to be_a(String)
      expect(links.first[:player_name]).to be_a(String)
      expect(links.first[:profile_text]).to be_a(String)
    end

    it 'CharacterScraper returns consistent data structure' do
      character_html = <<~HTML
        <html>
          <head><title>TestChar - That's My BIS</title></head>
          <body>
            <h1><a href="#" class="text-warrior">TestChar</a></h1>
            <div class="row mb-3 pt-3 bg-light rounded">
              <div class="col-12 mb-2">
                <span class="text-legendary font-weight-bold">
                  <span class="fas fa-fw fa-scroll-old"></span>
                  Test Wishlist
                </span>
              </div>
              <div class="col-12 pb-3">
                <ol class="js-wishlist-unsorted">
                  <li>
                    <span class="font-weight-medium">
                      <a href="#" data-wowhead="item=12345?domain=wotlk" class="q4">
                        <span class="iconsmall">
                          <ins style='background-image: url("test.jpg");'></ins>
                        </span>
                        <span>Test Item</span>
                      </a>
                    </span>
                  </li>
                </ol>
              </div>
            </div>
          </body>
        </html>
      HTML

      mock_doc = Nokogiri::HTML(character_html)
      mock_scraper = double('BaseScraper')
      allow(mock_scraper).to receive(:scrape).and_return(mock_doc)
      allow(mock_scraper).to receive(:last_document).and_return(mock_doc)

      character_scraper = ThatsMyBisScraper::Scrapers::CharacterScraper.new(mock_scraper)
      character_data = character_scraper.scrape_character_page('https://example.com/char')

      expect(character_data).to be_a(Hash)
      expect(character_data).to include(:name, :url, :scraped_at, :wishlists)
      expect(character_data[:name]).to be_a(String)
      expect(character_data[:url]).to be_a(String)
      expect(character_data[:scraped_at]).to be_a(String)
      expect(character_data[:wishlists]).to be_an(Array)
      
      if character_data[:wishlists].any?
        wishlist = character_data[:wishlists].first
        expect(wishlist).to include(:name, :items)
        expect(wishlist[:name]).to be_a(String)
        expect(wishlist[:items]).to be_an(Array)
        
        if wishlist[:items].any?
          item = wishlist[:items].first
          expect(item).to include(:name, :quality, :wowhead_id, :url)
          expect(item[:name]).to be_a(String)
          expect(item[:quality]).to be_a(String)
        end
      end
    end
  end

  describe 'URL handling behavior' do
    let(:roster_scraper) { ThatsMyBisScraper::Scrapers::RosterScraper.new }

    it 'converts relative URLs to absolute' do
      absolute_url = roster_scraper.send(:make_absolute_url, '/11258/chonglers/c/540876/aelektra')
      expect(absolute_url).to start_with('https://')
      expect(absolute_url).to include('/11258/chonglers/c/540876/aelektra')
    end

    it 'handles empty URLs gracefully' do
      absolute_url = roster_scraper.send(:make_absolute_url, '')
      expect(absolute_url).to be_nil
    end

    it 'handles nil URLs gracefully' do
      absolute_url = roster_scraper.send(:make_absolute_url, nil)
      expect(absolute_url).to be_nil
    end

    it 'preserves absolute URLs' do
      url = 'https://thatsmybis.com/11258/chonglers/c/540876/aelektra'
      absolute_url = roster_scraper.send(:make_absolute_url, url)
      expect(absolute_url).to eq(url)
    end
  end

  describe 'Data filtering behavior' do
    let(:mock_html) do
      <<~HTML
        <html>
          <body>
            <div class="dropdown">
              <a class="dropdown-item" href="/11258/chonglers/c/540876/aelektra">
                <span class="fas fa-fw fa-user"></span> Profile
              </a>
              <a class="dropdown-item" href="/11258/chonglers/c/create">
                <span class="fas fa-fw fa-user"></span> Create Character
              </a>
              <a class="dropdown-item" href="/11258/chonglers/c/123456/test/loot">
                <span class="fas fa-fw fa-user"></span> Profile
              </a>
            </div>
          </body>
        </html>
      HTML
    end

    it 'filters out create character links' do
      mock_doc = Nokogiri::HTML(mock_html)
      mock_scraper = double('BaseScraper')
      allow(mock_scraper).to receive(:scrape).and_return(mock_doc)
      
      roster_scraper = ThatsMyBisScraper::Scrapers::RosterScraper.new(nil, scraper: mock_scraper)
      links = roster_scraper.collect_profile_links

      urls = links.map { |link| link[:url] }
      expect(urls).not_to include('https://thatsmybis.com/11258/chonglers/c/create')
    end

    it 'filters out loot page links' do
      mock_doc = Nokogiri::HTML(mock_html)
      mock_scraper = double('BaseScraper')
      allow(mock_scraper).to receive(:scrape).and_return(mock_doc)
      
      roster_scraper = ThatsMyBisScraper::Scrapers::RosterScraper.new(nil, scraper: mock_scraper)
      links = roster_scraper.collect_profile_links

      urls = links.map { |link| link[:url] }
      expect(urls).not_to include('https://thatsmybis.com/11258/chonglers/c/123456/test/loot')
    end

    it 'extracts player names correctly' do
      mock_doc = Nokogiri::HTML(mock_html)
      mock_scraper = double('BaseScraper')
      allow(mock_scraper).to receive(:scrape).and_return(mock_doc)
      
      roster_scraper = ThatsMyBisScraper::Scrapers::RosterScraper.new(nil, scraper: mock_scraper)
      links = roster_scraper.collect_profile_links

      player_names = links.map { |link| link[:player_name] }
      expect(player_names).to include('aelektra')
    end
  end

  describe 'Error handling behavior' do
    it 'handles missing scraper gracefully' do
      expect { ThatsMyBisScraper::Scrapers::RosterScraper.new }.not_to raise_error
    end

    it 'handles invalid URLs gracefully' do
      roster_scraper = ThatsMyBisScraper::Scrapers::RosterScraper.new
      absolute_url = roster_scraper.send(:make_absolute_url, 'not-a-url')
      expect(absolute_url).to be_nil
    end

    it 'handles empty HTML gracefully' do
      empty_html = '<html><body></body></html>'
      mock_doc = Nokogiri::HTML(empty_html)
      mock_scraper = double('BaseScraper')
      allow(mock_scraper).to receive(:scrape).and_return(mock_doc)
      
      roster_scraper = ThatsMyBisScraper::Scrapers::RosterScraper.new(nil, scraper: mock_scraper)
      links = roster_scraper.collect_profile_links

      expect(links).to be_an(Array)
      expect(links.length).to eq(0)
    end
  end

  describe 'Configuration behavior' do
    it 'has configurable settings' do
      expect(ThatsMyBisScraper::Config).to be_a(Module)
      expect(ThatsMyBisScraper::Config::Settings).to be_a(Class)
    end

    it 'allows customization of scraper options' do
      scraper = ThatsMyBisScraper::Scrapers::BaseScraper.new(delay: 5, timeout: 60)
      expect(scraper.instance_variable_get(:@delay)).to eq(5)
      expect(scraper.instance_variable_get(:@timeout)).to eq(60)
    end
  end
end
