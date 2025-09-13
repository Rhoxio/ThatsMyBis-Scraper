# frozen_string_literal: true

require 'spec_helper'
require 'thatsmybis_scraper'

RSpec.describe ThatsMyBisScraper::Scrapers::CharacterScraper do
  let(:mock_scraper) { double('BaseScraper') }
  let(:scraper) { described_class.new(mock_scraper) }
  let(:character_url) { 'https://thatsmybis.com/11258/chonglers/c/540876/aelektra' }

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
                  <span class="text-uncommon small">Heroic</span>
                </li>
                <li>
                  <span class="font-weight-medium">
                    <a href="https://thatsmybis.com/11258/chonglers/i/51243/test-item" 
                       data-wowhead="item=51243?domain=wotlk" class="q3">
                      <span class="iconsmall">
                        <ins style='background-image: url("https://wow.zamimg.com/images/wow/icons/small/inv_sword_123.jpg");'></ins>
                      </span>
                      <span>Test Item</span>
                    </a>
                  </span>
                  <span class="text-rare small">Rare</span>
                </li>
              </ol>
            </div>
          </div>
        </body>
      </html>
    HTML
  end

  let(:mock_doc) { Nokogiri::HTML(character_html) }

  describe '#initialize' do
    it 'uses provided scraper' do
      expect(scraper.instance_variable_get(:@scraper)).to eq(mock_scraper)
    end

    it 'creates new scraper if none provided' do
      scraper_without_external = described_class.new
      expect(scraper_without_external.instance_variable_get(:@scraper)).to be_a(ThatsMyBisScraper::Scrapers::BaseScraper)
    end
  end

  describe '#scrape_character_page' do
    before do
      allow(mock_scraper).to receive(:scrape).and_return(mock_doc)
      allow(mock_scraper).to receive(:last_document).and_return(mock_doc)
    end

    it 'scrapes character page and returns data' do
      character_data = scraper.scrape_character_page(character_url)
      
      expect(character_data).to be_a(Hash)
      expect(character_data[:name]).to eq('Ælektra')
      expect(character_data[:url]).to eq(character_url)
      expect(character_data[:scraped_at]).to be_a(String)
    end

    it 'extracts character name from title' do
      character_data = scraper.scrape_character_page(character_url)
      expect(character_data[:name]).to eq('Ælektra')
    end

    it 'extracts wishlists' do
      character_data = scraper.scrape_character_page(character_url)
      
      expect(character_data[:wishlists]).to be_an(Array)
      expect(character_data[:wishlists].length).to eq(1)
      expect(character_data[:wishlists].first[:name]).to eq('Wishlist 1')
    end

    it 'extracts wishlist items' do
      character_data = scraper.scrape_character_page(character_url)
      
      wishlist = character_data[:wishlists].first
      expect(wishlist[:items]).to be_an(Array)
      expect(wishlist[:items].length).to eq(2)
      
      first_item = wishlist[:items].first
      expect(first_item[:name]).to eq('Sanctified Frost Witch\'s Faceguard')
      expect(first_item[:quality]).to eq('Epic')
      expect(first_item[:wowhead_id]).to eq('51242')
    end
  end

  describe '#extract_character_data' do
    it 'extracts character information' do
      character_data = scraper.send(:extract_character_data, mock_doc)
      
      expect(character_data).to include(:name, :class, :race, :level, :professions, :wishlists)
      expect(character_data[:name]).to eq('Ælektra')
    end
  end

  describe '#extract_character_name' do
    it 'extracts name from h1 link' do
      name = scraper.send(:extract_character_name, mock_doc)
      expect(name).to eq('Ælektra')
    end

    it 'falls back to title tag if h1 not found' do
      html_without_h1 = '<html><head><title>TestCharacter - That\'s My BIS</title></head></html>'
      doc = Nokogiri::HTML(html_without_h1)
      
      name = scraper.send(:extract_character_name, doc)
      expect(name).to eq('TestCharacter')
    end
  end

  describe '#extract_wishlists' do
    it 'finds wishlist sections' do
      wishlists = scraper.send(:extract_wishlists, mock_doc)
      
      expect(wishlists).to be_an(Array)
      expect(wishlists.length).to eq(1)
      expect(wishlists.first[:name]).to eq('Wishlist 1')
    end
  end

  describe '#extract_wishlist_items' do
    let(:wishlist_container) { mock_doc.css('.row.mb-3.pt-3.bg-light.rounded').first }

    it 'extracts items from wishlist container' do
      items = scraper.send(:extract_wishlist_items, wishlist_container)
      
      expect(items).to be_an(Array)
      expect(items.length).to eq(2)
      
      first_item = items.first
      expect(first_item[:name]).to eq('Sanctified Frost Witch\'s Faceguard')
      expect(first_item[:quality]).to eq('Epic')
    end

    it 'only extracts from unsorted list' do
      items = scraper.send(:extract_wishlist_items, wishlist_container)
      
      # Should only get items from js-wishlist-unsorted, not js-wishlist-sorted
      expect(items.length).to eq(2)
    end
  end

  describe '#extract_item_data' do
    let(:item_element) { mock_doc.css('.js-wishlist-unsorted li').first }

    it 'extracts item information' do
      item_data = scraper.send(:extract_item_data, item_element)
      
      expect(item_data[:name]).to eq('Sanctified Frost Witch\'s Faceguard')
      expect(item_data[:quality]).to eq('Epic')
      expect(item_data[:wowhead_id]).to eq('51242')
      expect(item_data[:url]).to include('sanctified-frost-witchs-faceguard')
    end

    it 'extracts item icon URL' do
      item_data = scraper.send(:extract_item_data, item_element)
      
      expect(item_data[:icon_url]).to include('inv_helmet_169.jpg')
    end
  end

  describe '#extract_wowhead_id' do
    it 'extracts ID from wowhead attribute' do
      id = scraper.send(:extract_wowhead_id, 'item=51242?domain=wotlk')
      expect(id).to eq('51242')
    end

    it 'handles different wowhead formats' do
      id = scraper.send(:extract_wowhead_id, 'item=12345')
      expect(id).to eq('12345')
    end

    it 'returns nil for invalid format' do
      id = scraper.send(:extract_wowhead_id, 'invalid=format')
      expect(id).to be_nil
    end
  end

  describe '#extract_item_quality' do
    it 'maps CSS classes to quality names' do
      expect(scraper.send(:extract_item_quality, 'q4')).to eq('Epic')
      expect(scraper.send(:extract_item_quality, 'q3')).to eq('Rare')
      expect(scraper.send(:extract_item_quality, 'q2')).to eq('Uncommon')
      expect(scraper.send(:extract_item_quality, 'q1')).to eq('Common')
      expect(scraper.send(:extract_item_quality, 'q5')).to eq('Legendary')
    end

    it 'handles unknown quality classes' do
      expect(scraper.send(:extract_item_quality, 'unknown')).to eq('Unknown')
    end
  end
end
