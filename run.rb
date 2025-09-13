# frozen_string_literal: true

# Simple entry point that loads the main module
require_relative 'lib/thatsmybis_scraper'

# Example usage
if __FILE__ == $PROGRAM_NAME
  puts "ThatsMyBis Scraper".blue.bold
  puts "Use the executable scripts in bin/ directory:"
  puts "  ./bin/scrape - Basic scraping"
  puts "  ./bin/selenium_scrape - Selenium-based scraping"
  puts "  ./bin/roster_test - Test roster retrieval"
end