# frozen_string_literal: true

module ThatsMyBisScraper
  # Roster retriever class for collecting base data and links
  class RosterRetriever
    def initialize(base_url = nil, options = {})
      # Hard-coded URL for testing - That's My BIS Chonglers roster
      @base_url = base_url || "https://thatsmybis.com/11258/chonglers/roster"
      @domain = URI.parse(@base_url).host
      @collected_links = []
      @filtered_links = []
      @profile_links = []  # Specific array for profile links
      @scraper = options[:scraper] # Accept external scraper instance
      @options = {
        follow_external: false,
        max_depth: 1,
        delay: 1,
        link_patterns: [],
        exclude_patterns: []
      }.merge(options)
    end

    def collect_links(doc = nil)
      puts "Starting link collection from: #{@base_url}".blue
      
      # If no document provided, we'll need to scrape it first
      if doc.nil?
        if @scraper
          doc = @scraper.scrape(@base_url)
        else
          scraper = Scraper.new
          doc = scraper.scrape(@base_url)
        end
      end

      links = extract_links(doc)
      puts "Found #{links.length} total links".green
      
      @collected_links = links
      filter_links
      
      puts "Filtered to #{@filtered_links.length} relevant links".green
      @filtered_links
    end

    def collect_profile_links(doc = nil)
      puts "Collecting profile links from roster page: #{@base_url}".blue
      
      # If no document provided, we'll need to scrape it first
      if doc.nil?
        if @scraper
          doc = @scraper.scrape(@base_url)
        else
          scraper = Scraper.new
          doc = scraper.scrape(@base_url)
        end
      end

      @profile_links = extract_profile_links(doc)
      puts "Found #{@profile_links.length} profile links".green
      
      @profile_links
    end

    def extract_links(doc)
      links = []
      
      # Extract all anchor tags with href attributes
      doc.css('a[href]').each do |link|
        href = link['href']
        next if href.nil? || href.empty?
        
        # Convert relative URLs to absolute
        absolute_url = make_absolute_url(href)
        next unless absolute_url
        
        link_data = {
          url: absolute_url,
          text: link.text.strip,
          title: link['title'],
          class: link['class'],
          id: link['id'],
          parent_element: get_parent_context(link)
        }
        
        links << link_data
      end
      
      links.uniq { |link| link[:url] }
    end

    def extract_profile_links(doc)
      profile_links = []
      
      # Look for dropdown-item links that contain profile links
      # Based on the HTML structure: <a class="dropdown-item" href="/11258/chonglers/c/540876/aelektra">
      doc.css('a.dropdown-item[href*="/c/"]').each do |link|
        href = link['href']
        next if href.nil? || href.empty?
        
        # Skip "create character" links and other non-profile links
        next if href.include?('/c/create') || 
                href.include?('member_id=') ||
                href.include?('/loot') ||
                link.text.strip.downcase.include?('create') ||
                link.text.strip.downcase.include?('new')
        
        # Convert relative URLs to absolute
        absolute_url = make_absolute_url(href)
        next unless absolute_url
        
        # Extract player name from the href (last part after the last slash)
        player_name = href.split('/').last
        
        # Get the profile text (should be "Profile")
        profile_text = link.text.strip
        
        # Get the parent context to see if there's a user icon
        user_icon = link.css('span.fas.fa-user').any?
        
        profile_data = {
          url: absolute_url,
          relative_url: href,
          player_name: player_name,
          profile_text: profile_text,
          has_user_icon: user_icon,
          title: link['title'],
          data_original_title: link['data-original-title']
        }
        
        profile_links << profile_data
      end
      
      # Also look for any other profile-related links that might not be in dropdown
      doc.css('a[href*="/c/"]').each do |link|
        href = link['href']
        next if href.nil? || href.empty?
        
        # Skip "create character" links and other non-profile links
        next if href.include?('/c/create') || 
                href.include?('member_id=') ||
                href.include?('/loot') ||
                link.text.strip.downcase.include?('create') ||
                link.text.strip.downcase.include?('new')
        
        # Skip if we already found this in dropdown items
        next if profile_links.any? { |pl| pl[:relative_url] == href }
        
        absolute_url = make_absolute_url(href)
        next unless absolute_url
        
        player_name = href.split('/').last
        
        profile_data = {
          url: absolute_url,
          relative_url: href,
          player_name: player_name,
          profile_text: link.text.strip,
          has_user_icon: false,
          title: link['title'],
          data_original_title: link['data-original-title']
        }
        
        profile_links << profile_data
      end
      
      profile_links.uniq { |link| link[:url] }
    end

    def filter_links
      @filtered_links = @collected_links.select do |link|
        should_include_link?(link)
      end
    end

    def should_include_link?(link)
      url = link[:url]
      
      # Skip if external and we're not following external links
      return false if !@options[:follow_external] && external_link?(url)
      
      # Skip if matches exclude patterns
      return false if matches_patterns?(url, @options[:exclude_patterns])
      
      # Include if matches include patterns (if any specified)
      if @options[:link_patterns].any?
        return matches_patterns?(url, @options[:link_patterns])
      end
      
      # Default: include internal links
      !external_link?(url)
    end

    def external_link?(url)
      begin
        uri = URI.parse(url)
        uri.host != @domain
      rescue URI::InvalidURIError
        true
      end
    end

    def matches_patterns?(url, patterns)
      patterns.any? do |pattern|
        case pattern
        when String
          url.include?(pattern)
        when Regexp
          url.match?(pattern)
        end
      end
    end

    def make_absolute_url(href)
      begin
        if href.start_with?('http')
          href
        elsif href.start_with?('//')
          "https:#{href}"
        elsif href.start_with?('/')
          URI.join(@base_url, href).to_s
        else
          URI.join(@base_url, href).to_s
        end
      rescue URI::InvalidURIError
        nil
      end
    end

    def get_parent_context(element)
      parent = element.parent
      return nil unless parent
      
      {
        tag: parent.name,
        class: parent['class'],
        id: parent['id'],
        text_snippet: parent.text.strip[0..100]
      }
    end

    def categorize_links
      categories = {
        internal: [],
        external: [],
        images: [],
        documents: [],
        navigation: [],
        content: []
      }
      
      @filtered_links.each do |link|
        url = link[:url]
        
        if external_link?(url)
          categories[:external] << link
        elsif url.match?(/\.(jpg|jpeg|png|gif|svg|webp)$/i)
          categories[:images] << link
        elsif url.match?(/\.(pdf|doc|docx|txt|zip)$/i)
          categories[:documents] << link
        elsif link[:text].downcase.match?(/(menu|nav|home|about|contact)/)
          categories[:navigation] << link
        else
          categories[:internal] << link
        end
      end
      
      categories
    end

    def save_links_to_file(filename = nil)
      filename ||= "data/collected_links_#{Time.now.strftime('%Y%m%d_%H%M%S')}.json"
      
      FileUtils.mkdir_p('data') unless Dir.exist?('data')
      
      data = {
        base_url: @base_url,
        collected_at: Time.now.iso8601,
        total_links: @collected_links.length,
        filtered_links: @filtered_links.length,
        links: @filtered_links,
        categories: categorize_links
      }
      
      File.write(filename, JSON.pretty_generate(data))
      puts "Links saved to: #{filename}".green
      filename
    end

    # This method is now deprecated - use the single WebDriver approach in the main scripts
    def scrape_all_characters
      puts "DEPRECATED: Use the single WebDriver approach in the main scripts".red
      puts "This method creates multiple WebDriver instances which is inefficient".yellow
      []
    end

    def save_character_data_to_file(character_data, filename = nil)
      filename ||= "data/character_data_#{Time.now.strftime('%Y%m%d_%H%M%S')}.json"
      
      FileUtils.mkdir_p('data') unless Dir.exist?('data')
      
      data = {
        base_url: @base_url,
        scraped_at: Time.now.iso8601,
        total_characters: character_data.length,
        characters: character_data
      }
      
      File.write(filename, JSON.pretty_generate(data))
      puts "Character data saved to: #{filename}".green
      filename
    end

    def print_summary
      puts "\n" + "="*50
      puts "ROSTER RETRIEVER SUMMARY".blue.bold
      puts "="*50
      puts "Base URL: #{@base_url}"
      puts "Total links found: #{@collected_links.length}"
      puts "Filtered links: #{@filtered_links.length}"
      puts "Profile links: #{@profile_links.length}" if @profile_links.any?
      
      categories = categorize_links
      puts "\nLink Categories:".yellow
      categories.each do |category, links|
        puts "  #{category.to_s.capitalize}: #{links.length}" unless links.empty?
      end
      puts "="*50 + "\n"
    end

    # Getters
    attr_reader :collected_links, :filtered_links, :profile_links, :base_url, :domain
  end
end
