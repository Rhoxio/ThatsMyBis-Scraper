# frozen_string_literal: true

require 'spec_helper'
require 'thatsmybis_scraper'

RSpec.describe ThatsMyBisScraper::Scrapers::RosterScraper do
  let(:base_url) { 'https://thatsmybis.com/11258/chonglers/roster' }
  let(:scraper) { described_class.new(base_url) }
  let(:mock_doc) { Nokogiri::HTML(roster_html) }

  let(:roster_html) do
    <<~HTML
      <html>
        <body>
          <div class="dropdown">
            <a class="dropdown-item" href="/11258/chonglers/c/540876/aelektra">
              <span class="fas fa-fw fa-user"></span> Profile
            </a>
            <a class="dropdown-item" href="/11258/chonglers/c/306944/rhoxio">
              <span class="fas fa-fw fa-user"></span> Profile
            </a>
            <a class="dropdown-item" href="/11258/chonglers/c/123456/testchar/loot">
              <span class="fas fa-fw fa-user"></span> Profile
            </a>
            <a class="dropdown-item" href="/11258/chonglers/c/create">
              <span class="fas fa-fw fa-user"></span> Create Character
            </a>
          </div>
        </body>
      </html>
    HTML
  end

  describe '#initialize' do
    it 'sets default base URL' do
      expect(scraper.base_url).to eq(base_url)
    end

    it 'accepts custom base URL' do
      custom_url = 'https://example.com/roster'
      custom_scraper = described_class.new(custom_url)
      expect(custom_scraper.base_url).to eq(custom_url)
    end

    it 'accepts external scraper' do
      mock_scraper = double('BaseScraper')
      scraper_with_external = described_class.new(base_url, scraper: mock_scraper)
      expect(scraper_with_external.instance_variable_get(:@scraper)).to eq(mock_scraper)
    end
  end

  describe '#collect_profile_links' do
    it 'extracts profile links from roster page' do
      allow(scraper).to receive(:scrape_document).and_return(mock_doc)
      
      links = scraper.collect_profile_links
      
      expect(links).to be_an(Array)
      expect(links.length).to eq(2) # Only valid profile links
      
      link_urls = links.map { |link| link[:url] }
      expect(link_urls).to include('https://thatsmybis.com/11258/chonglers/c/540876/aelektra')
      expect(link_urls).to include('https://thatsmybis.com/11258/chonglers/c/306944/rhoxio')
    end

    it 'filters out create character links' do
      allow(scraper).to receive(:scrape_document).and_return(mock_doc)
      
      links = scraper.collect_profile_links
      link_urls = links.map { |link| link[:url] }
      
      expect(link_urls).not_to include('https://thatsmybis.com/11258/chonglers/c/create')
    end

    it 'filters out loot page links' do
      allow(scraper).to receive(:scrape_document).and_return(mock_doc)
      
      links = scraper.collect_profile_links
      link_urls = links.map { |link| link[:url] }
      
      expect(link_urls).not_to include('https://thatsmybis.com/11258/chonglers/c/123456/testchar/loot')
    end

    it 'extracts player names from URLs' do
      allow(scraper).to receive(:scrape_document).and_return(mock_doc)
      
      links = scraper.collect_profile_links
      
      player_names = links.map { |link| link[:player_name] }
      expect(player_names).to include('aelektra')
      expect(player_names).to include('rhoxio')
    end
  end

  describe '#extract_profile_links' do
    it 'processes document and returns profile links' do
      links = scraper.send(:extract_profile_links, mock_doc)
      
      expect(links).to be_an(Array)
      expect(links.first).to include(:url, :player_name, :profile_text)
    end

    it 'converts relative URLs to absolute' do
      links = scraper.send(:extract_profile_links, mock_doc)
      
      links.each do |link|
        expect(link[:url]).to start_with('https://')
      end
    end
  end

  describe '#make_absolute_url' do
    it 'converts relative URLs to absolute' do
      absolute_url = scraper.send(:make_absolute_url, '/11258/chonglers/c/540876/aelektra')
      expect(absolute_url).to eq('https://thatsmybis.com/11258/chonglers/c/540876/aelektra')
    end

    it 'returns nil for invalid URLs' do
      absolute_url = scraper.send(:make_absolute_url, '')
      expect(absolute_url).to be_nil
    end

    it 'handles already absolute URLs' do
      url = 'https://thatsmybis.com/11258/chonglers/c/540876/aelektra'
      absolute_url = scraper.send(:make_absolute_url, url)
      expect(absolute_url).to eq(url)
    end
  end

  describe '#save_links_to_file' do
    before do
      scraper.instance_variable_set(:@profile_links, [
        { url: 'https://example.com/c/1/test', player_name: 'test' }
      ])
    end

    it 'saves links to JSON file' do
      filename = scraper.save_links_to_file
      
      expect(File.exist?(filename)).to be true
      
      data = JSON.parse(File.read(filename))
      expect(data['profile_links']).to be_an(Array)
      expect(data['profile_links'].first['player_name']).to eq('test')
    end

    it 'creates data directory if it does not exist' do
      expect(FileUtils).to receive(:mkdir_p).with('data')
      scraper.save_links_to_file
    end
  end
end
