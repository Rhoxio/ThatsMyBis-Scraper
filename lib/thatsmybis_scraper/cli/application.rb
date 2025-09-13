# frozen_string_literal: true

require 'optparse'
require 'colorize'

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
        # TODO: Implement roster scraping
      end

      def run_character_scrape
        puts "Scraping character page...".blue
        # TODO: Implement character scraping
      end

      def run_full_scrape
        puts "Running full scrape...".blue
        # TODO: Implement full scraping
      end

      def run_debug_scrape
        puts "Running debug scrape...".blue
        # TODO: Implement debug scraping
      end
    end
  end
end
