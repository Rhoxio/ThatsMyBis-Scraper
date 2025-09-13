# frozen_string_literal: true

require 'optparse'
require 'colorize'
require 'json'
require 'fileutils'
require 'set'

module ThatsMyBisScraper
  module CLI
    # Main CLI application class
    class Application
      def initialize
        @options = {}
      end

      def run(args = ARGV)
        parse_options(args)
        execute_command
      rescue Interrupt
        puts "\nScraping cancelled by user.".yellow
        exit 0
      rescue => e
        puts "Error: #{e.message}".red
        puts e.backtrace.first(5).join("\n").red if @options[:verbose]
        exit 1
      end

      private

      def parse_options(args)
        OptionParser.new do |opts|
          opts.banner = "Usage: thatsmybis-scraper [COMMAND] [OPTIONS]"

          opts.on("-v", "--verbose", "Enable verbose output") do
            @options[:verbose] = true
          end

          opts.on("-h", "--help", "Show this help message") do
            puts opts
            puts "\nCommands:"
            puts "  roster     - Scrape roster page and collect profile links"
            puts "  character  - Scrape a single character page"
            puts "  full       - Full scrape (roster + all characters)"
            puts "  debug      - Debug single character scraping"
            exit 0
          end
        end.parse!(args)

        @command = args.first&.downcase
      end

      def execute_command
        case @command
        when 'roster'
          run_roster_scrape
        when 'character'
          run_character_scrape
        when 'full'
          run_full_scrape
        when 'debug'
          run_debug_scrape
        else
          puts "Unknown command: #{@command}".red
          puts "Use --help for available commands".yellow
          exit 1
        end
      end

      def run_roster_scrape
        puts "Scraping roster page...".blue
        
        driver_manager = ThatsMyBisScraper::Utils::WebDriverManager.instance
        shared_driver = driver_manager.driver
        
        begin
          scraper = ThatsMyBisScraper::Scrapers::BaseScraper.new(driver: shared_driver)
          roster_scraper = ThatsMyBisScraper::Scrapers::RosterScraper.new(nil, scraper: scraper)
          
          profile_links = roster_scraper.collect_profile_links
          puts "Found #{profile_links.length} profile links".green
          
          # Save the links
          filename = roster_scraper.save_links_to_file
          puts "Profile links saved to: #{filename}".green
          
        ensure
          driver_manager.cleanup
        end
      end

      def run_character_scrape
        puts "Scraping character page...".blue
        puts "Please provide a character URL:".yellow
        url = STDIN.gets.chomp
        
        if url.empty?
          puts "No URL provided, using default test URL".yellow
          url = "https://thatsmybis.com/11258/chonglers/c/540876/aelektra"
        end
        
        driver_manager = ThatsMyBisScraper::Utils::WebDriverManager.instance
        shared_driver = driver_manager.driver
        
        begin
          scraper = ThatsMyBisScraper::Scrapers::BaseScraper.new(driver: shared_driver)
          character_scraper = ThatsMyBisScraper::Scrapers::CharacterScraper.new(scraper)
          
          character_data = character_scraper.scrape_character_page(url)
          puts "Successfully scraped: #{character_data[:name]}".green
          puts "Found #{character_data[:wishlists]&.length || 0} wishlists".green
          
        ensure
          driver_manager.cleanup
        end
      end

      def run_full_scrape
        puts "Running full scrape...".blue
        
        driver_manager = ThatsMyBisScraper::Utils::WebDriverManager.instance
        shared_driver = driver_manager.driver
        
        begin
          scraper = ThatsMyBisScraper::Scrapers::BaseScraper.new(driver: shared_driver)
          roster_scraper = ThatsMyBisScraper::Scrapers::RosterScraper.new(nil, scraper: scraper)
          character_scraper = ThatsMyBisScraper::Scrapers::CharacterScraper.new(scraper)
          
          puts "Step 1: Collecting profile links...".blue
          profile_links = roster_scraper.collect_profile_links
          
          if profile_links.empty?
            puts "No profile links found!".red
            return
          end
          
          puts "Found #{profile_links.length} character profiles".green
          puts "Continue with full scrape? (y/n): ".cyan
          response = STDIN.gets.chomp.downcase
          
          unless response == 'y' || response == 'yes'
            puts "Scraping cancelled.".yellow
            return
          end
          
          puts "Step 2: Scraping character pages...".blue
          character_data = []
          visited_urls = Set.new
          skipped_count = 0
          
          profile_links.each_with_index do |profile_link, index|
            # Skip if we've already visited this URL
            if visited_urls.include?(profile_link[:url])
              puts "[#{index + 1}/#{profile_links.length}] Skipping duplicate: #{profile_link[:player_name]} (#{profile_link[:url]})".yellow
              skipped_count += 1
              next
            end
            
            puts "[#{index + 1}/#{profile_links.length}] Scraping: #{profile_link[:player_name]}".cyan
            
            begin
              char_data = character_scraper.scrape_character_page(profile_link[:url])
              character_data << char_data
              visited_urls.add(profile_link[:url])
              sleep(1) # Be respectful
            rescue => e
              puts "Error scraping #{profile_link[:player_name]}: #{e.message}".red
              next
            end
          end
          
          puts "Completed scraping #{character_data.length} characters".green
          if skipped_count > 0
            puts "Skipped #{skipped_count} duplicate URLs".yellow
          end
          
          # Save character data to file
          if character_data.any?
            filename = save_character_data_to_file(character_data, roster_scraper.base_url)
            puts "Character data saved to: #{filename}".green
          end
          
        ensure
          driver_manager.cleanup
        end
      end

      def run_debug_scrape
        puts "Running debug scrape...".blue
        
        test_url = "https://thatsmybis.com/11258/chonglers/c/540876/aelektra"
        puts "Debugging character: #{test_url}".green
        
        driver_manager = ThatsMyBisScraper::Utils::WebDriverManager.instance
        shared_driver = driver_manager.driver
        
        begin
          scraper = ThatsMyBisScraper::Scrapers::BaseScraper.new(driver: shared_driver)
          character_scraper = ThatsMyBisScraper::Scrapers::CharacterScraper.new(scraper)
          
          character_data = character_scraper.scrape_character_page(test_url)
          
          puts "\n" + "="*60
          puts "DEBUG RESULTS".blue.bold
          puts "="*60
          puts "Character Name: #{character_data[:name]}"
          puts "Character Class: #{character_data[:class]}"
          puts "Character Level: #{character_data[:level]}"
          puts "Number of Wishlists: #{character_data[:wishlists]&.length || 0}"
          
          if character_data[:wishlists] && !character_data[:wishlists].empty?
            character_data[:wishlists].each_with_index do |wishlist, index|
              puts "\nWishlist #{index + 1}: #{wishlist[:name]}"
              puts "  Items in wishlist: #{wishlist[:items]&.length || 0}"
              
              if wishlist[:items] && !wishlist[:items].empty?
                puts "  First few items:"
                wishlist[:items].first(3).each_with_index do |item, item_index|
                  puts "    #{item_index + 1}. #{item[:name]} (#{item[:quality]})"
                end
              else
                puts "  NO ITEMS FOUND!"
              end
            end
          else
            puts "\nNO WISHLISTS FOUND!"
          end
          
        ensure
          driver_manager.cleanup
        end
      end

      private

      def save_character_data_to_file(character_data, base_url)
        filename = "data/character_data_#{Time.now.strftime('%Y%m%d_%H%M%S')}.json"
        
        FileUtils.mkdir_p('data') unless Dir.exist?('data')
        
        data = {
          base_url: base_url,
          scraped_at: Time.now.iso8601,
          total_characters: character_data.length,
          characters: character_data
        }
        
        File.write(filename, JSON.pretty_generate(data))
        filename
      end
    end
  end
end
