# frozen_string_literal: true

require 'nokogiri'
require 'httparty'
require 'colorize'
require 'dotenv/load'
require 'selenium-webdriver'
require 'json'
require 'uri'
require 'fileutils'

# Configuration
require_relative '../config/settings'

# Core modules
require_relative 'thatsmybis_scraper/utils/webdriver_manager'
require_relative 'thatsmybis_scraper/scrapers/base_scraper'
require_relative 'thatsmybis_scraper/scrapers/roster_scraper'
require_relative 'thatsmybis_scraper/scrapers/character_scraper'

# CLI
require_relative 'thatsmybis_scraper/cli/application'

module ThatsMyBisScraper
  class Error < StandardError; end
  
  # Main entry point for CLI
  def self.run(args = ARGV)
    CLI::Application.new.run(args)
  end
end
