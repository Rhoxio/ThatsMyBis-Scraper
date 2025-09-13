# frozen_string_literal: true

module ThatsMyBisScraper
  # Main scraper class
  class Scraper
    include HTTParty

    def initialize(options = {})
      @base_url = options[:base_url] || ENV['TARGET_URL']
      @delay = options[:delay] || ENV.fetch('REQUEST_DELAY', 1).to_i
      @max_retries = options[:max_retries] || ENV.fetch('MAX_RETRIES', 3).to_i
      @timeout = options[:timeout] || ENV.fetch('TIMEOUT', 30).to_i
      @user_agent = options[:user_agent] || ENV.fetch('USER_AGENT', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36')
      @headless = options[:headless] || ENV.fetch('HEADLESS', 'false') == 'true'
      @driver = options[:driver] # Accept external driver instance
      @cookie_file = options[:cookie_file] || 'data/cookies.json'
      @external_driver = !@driver.nil? # Track if we're using external driver
    end

    def scrape(url = nil)
      target_url = url || @base_url
      raise Error, 'No URL provided' unless target_url

      puts "Starting scrape of: #{target_url}".green
      
      # Use Selenium for OAuth-enabled scraping
      scrape_with_selenium(target_url)
    end

    def scrape_with_selenium(url)
      setup_driver unless @driver
      
      begin
        puts "Navigating to: #{url}".blue
        @driver.navigate.to(url)
        
        # Wait for page to load
        sleep(2)
        
        # Check if we need to handle OAuth login (only if redirected to login)
        if needs_oauth_login?
          handle_oauth_login
        end
        
        # Get the page content after login (if needed)
        page_source = @driver.page_source
        @last_document = Nokogiri::HTML(page_source)
        
        puts "Successfully scraped with Selenium".green
        @last_document
        
      rescue => e
        puts "Error during scraping: #{e.message}".red
        raise e
      end
    end

    # Persistent methods removed - use WebDriverManager for single instance approach

    attr_reader :last_document

    def scrape_with_http(url)
      response = make_request(url)
      parse_response(response)
    end

    private

    def setup_driver
      # If we already have an external driver, don't create a new one
      if @external_driver
        puts "Using external WebDriver instance".green
        return @driver
      end

      puts "Setting up Selenium WebDriver...".blue

      # Create user data directory for persistent cookies
      user_data_dir = File.expand_path('data/chrome_user_data')
      FileUtils.mkdir_p(user_data_dir) unless Dir.exist?(user_data_dir)

      options = Selenium::WebDriver::Chrome::Options.new
      options.add_argument('--no-sandbox')
      options.add_argument('--disable-dev-shm-usage')
      options.add_argument('--disable-blink-features=AutomationControlled')
      options.add_argument("--user-agent=#{@user_agent}")

      # Use persistent user data directory for cookies
      options.add_argument("--user-data-dir=#{user_data_dir}")

      # Handle different Selenium versions for experimental options
      begin
        options.add_experimental_option("excludeSwitches", ["enable-automation"])
        options.add_experimental_option('useAutomationExtension', false)
      rescue NoMethodError
        # Fallback for older Selenium versions
        options.add_argument('--disable-extensions')
        options.add_argument('--disable-plugins')
      end
      
      if @headless
        options.add_argument('--headless')
        puts "Running in headless mode".yellow
      end

      @driver = Selenium::WebDriver.for(:chrome, options: options)
      
      # Hide automation indicators
      @driver.execute_script("Object.defineProperty(navigator, 'webdriver', {get: () => undefined})")
      
      puts "WebDriver initialized successfully with persistent cookies".green
      @driver
    end

    def cleanup_driver
      # Only cleanup if we created the driver ourselves
      if @driver && !@external_driver
        puts "Cleaning up WebDriver...".blue
        @driver.quit
        @driver = nil
        puts "WebDriver cleaned up".green
      elsif @external_driver
        puts "Skipping cleanup of external WebDriver".yellow
      end
    end

    def needs_oauth_login?
      # Check if we're actually on a login page or redirected to authentication
      current_url = @driver.current_url.downcase
      page_source = @driver.page_source.downcase
      
      # Check if URL indicates we're on a login/oauth page
      login_url_indicators = [
        'login', 'oauth', 'auth', 'discord', 'connect', 'authorize'
      ]
      
      # Check if page content indicates login is required
      login_content_indicators = [
        'please log in', 'sign in to continue', 'oauth', 'authorize',
        'connect your account', 'authenticate', 'discord login'
      ]
      
      # Only prompt if we're actually on a login page or see clear login requirements
      url_requires_login = login_url_indicators.any? { |indicator| current_url.include?(indicator) }
      content_requires_login = login_content_indicators.any? { |indicator| page_source.include?(indicator) }
      
      # Don't prompt just because "discord" appears in the content (could be normal content)
      # Only prompt if it's clearly a login/oauth context
      url_requires_login || content_requires_login
    end

    def handle_oauth_login
      puts "Authentication required, handling login flow...".yellow
      
      # Store the original target URL
      original_url = @driver.current_url
      
      # Check if we need to click Discord link first
      if discord_link_present?
        puts "Found Discord link, clicking it first...".blue
        click_discord_link
        sleep(3)  # Wait for redirect
      end
      
      # Wait for user to manually complete authentication
      puts "\n" + "="*60
      puts "AUTHENTICATION REQUIRED".red.bold
      puts "="*60
      puts "Please complete the authentication in the browser window.".cyan
      puts "This includes:".yellow
      puts "  - Entering your Discord credentials".yellow
      puts "  - Authorizing the application".yellow
      puts "  - Waiting for redirect back to Discord or completion".yellow
      puts ""
      puts "Press Enter once you've completed authentication...".cyan
      puts "="*60
      
      gets
      
      puts "Authentication completed! Navigating back to roster page...".green
      
      # Navigate back to the original roster page
      puts "Navigating back to: #{original_url}".blue
      @driver.navigate.to(original_url)
      sleep(2)  # Wait for page to load
      
      puts "Successfully navigated back to roster page!".green
    end

    def discord_link_present?
      begin
        @driver.find_element(class: 'discord-link')
        true
      rescue Selenium::WebDriver::Error::NoSuchElementError
        false
      end
    end

    def click_discord_link
      begin
        discord_link = @driver.find_element(class: 'discord-link')
        discord_link.click
        puts "Discord link clicked successfully".green
      rescue Selenium::WebDriver::Error::NoSuchElementError
        puts "Discord link not found, continuing...".yellow
      rescue => e
        puts "Error clicking Discord link: #{e.message}".red
      end
    end

    def make_request(url)
      retries = 0
      
      begin
        response = self.class.get(url, {
          headers: { 'User-Agent' => @user_agent },
          timeout: @timeout
        })

        raise Error, "HTTP Error: #{response.code}" unless response.success?

        response
      rescue => e
        retries += 1
        if retries <= @max_retries
          puts "Request failed (#{e.message}), retrying in #{@delay}s... (attempt #{retries}/#{@max_retries})".yellow
          sleep(@delay)
          retry
        else
          raise Error, "Failed after #{@max_retries} retries: #{e.message}"
        end
      end
    end

    def parse_response(response)
      doc = Nokogiri::HTML(response.body)
      puts "Successfully parsed HTML document".green
      
      # Add your parsing logic here
      doc
    end
  end
end
