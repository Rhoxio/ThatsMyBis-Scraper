# frozen_string_literal: true

require 'spec_helper'
require 'thatsmybis_scraper'

RSpec.describe ThatsMyBisScraper::CLI::Application do
  let(:app) { described_class.new }

  describe '#run' do
    it 'shows help for help command' do
      expect { app.run(['--help']) }.to output(/Usage:/).to_stdout
    end

    it 'shows help for unknown command' do
      expect { app.run(['unknown']) }.to output(/Unknown command/).to_stderr
    end

    it 'handles interrupt gracefully' do
      allow(app).to receive(:execute_command).and_raise(Interrupt)
      
      expect { app.run(['roster']) }.to output(/cancelled/).to_stdout
    end

    it 'handles errors gracefully' do
      allow(app).to receive(:execute_command).and_raise(StandardError.new('Test error'))
      
      expect { app.run(['roster']) }.to output(/Error: Test error/).to_stderr
    end
  end

  describe '#parse_options' do
    it 'parses verbose flag' do
      app.send(:parse_options, ['--verbose', 'roster'])
      expect(app.instance_variable_get(:@options)[:verbose]).to be true
    end

    it 'parses help flag' do
      expect { app.send(:parse_options, ['--help']) }.to output(/Usage:/).to_stdout
    end

    it 'extracts command from args' do
      app.send(:parse_options, ['full'])
      expect(app.instance_variable_get(:@command)).to eq('full')
    end
  end

  describe '#execute_command' do
    it 'calls roster scrape for roster command' do
      expect(app).to receive(:run_roster_scrape)
      app.instance_variable_set(:@command, 'roster')
      app.send(:execute_command)
    end

    it 'calls character scrape for character command' do
      expect(app).to receive(:run_character_scrape)
      app.instance_variable_set(:@command, 'character')
      app.send(:execute_command)
    end

    it 'calls full scrape for full command' do
      expect(app).to receive(:run_full_scrape)
      app.instance_variable_set(:@command, 'full')
      app.send(:execute_command)
    end

    it 'calls debug scrape for debug command' do
      expect(app).to receive(:run_debug_scrape)
      app.instance_variable_set(:@command, 'debug')
      app.send(:execute_command)
    end

    it 'shows error for unknown command' do
      app.instance_variable_set(:@command, 'unknown')
      
      expect { app.send(:execute_command) }.to output(/Unknown command/).to_stderr
    end
  end

  describe '#save_character_data_to_file' do
    let(:character_data) do
      [
        { name: 'TestChar', class: 'Warrior', wishlists: [] },
        { name: 'TestChar2', class: 'Mage', wishlists: [] }
      ]
    end
    let(:base_url) { 'https://thatsmybis.com/11258/chonglers/roster' }

    before do
      allow(FileUtils).to receive(:mkdir_p)
      allow(File).to receive(:write)
    end

    it 'creates data directory' do
      expect(FileUtils).to receive(:mkdir_p).with('data')
      
      app.send(:save_character_data_to_file, character_data, base_url)
    end

    it 'writes JSON file with correct structure' do
      expect(File).to receive(:write) do |filename, content|
        expect(filename).to match(/data\/character_data_\d{8}_\d{6}\.json/)
        
        data = JSON.parse(content)
        expect(data['base_url']).to eq(base_url)
        expect(data['total_characters']).to eq(2)
        expect(data['characters']).to be_an(Array)
        expect(data['characters'].length).to eq(2)
        expect(data['scraped_at']).to be_a(String)
      end
      
      app.send(:save_character_data_to_file, character_data, base_url)
    end

    it 'returns filename' do
      filename = app.send(:save_character_data_to_file, character_data, base_url)
      expect(filename).to match(/data\/character_data_\d{8}_\d{6}\.json/)
    end
  end
end
