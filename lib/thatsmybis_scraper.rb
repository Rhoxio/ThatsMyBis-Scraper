# frozen_string_literal: true

require 'nokogiri'
require 'httparty'
require 'colorize'
require 'dotenv/load'
require 'selenium-webdriver'
require 'json'
require 'uri'

module ThatsMyBisScraper
  class Error < StandardError; end
end

# Require all the classes
require_relative 'webdriver_manager'
require_relative 'scraper'
require_relative 'roster_retriever'
require_relative 'character_scraper'