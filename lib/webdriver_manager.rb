# frozen_string_literal: true

module ThatsMyBisScraper
  # Manages a single WebDriver instance for the entire application
  class WebDriverManager
    def self.instance
      @instance ||= new
    end

    def initialize
      @driver = nil
      @options = {
        headless: ENV.fetch('HEADLESS', 'false') == 'true',
        user_agent: ENV.fetch('USER_AGENT', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36')
      }
    end

    def driver
      @driver ||= create_driver
    end

    def cleanup
      if @driver
        puts "Cleaning up WebDriver...".blue
        @driver.quit
        @driver = nil
        puts "WebDriver cleaned up".green
      end
    end

    private

    def create_driver
      puts "Creating single WebDriver instance...".blue

      # Create user data directory for persistent cookies
      user_data_dir = File.expand_path('data/chrome_user_data')
      FileUtils.mkdir_p(user_data_dir) unless Dir.exist?(user_data_dir)

      options = Selenium::WebDriver::Chrome::Options.new
      options.add_argument('--no-sandbox')
      options.add_argument('--disable-dev-shm-usage')
      options.add_argument('--disable-blink-features=AutomationControlled')
      options.add_argument("--user-agent=#{@options[:user_agent]}")

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
      
      if @options[:headless]
        options.add_argument('--headless')
        puts "Running in headless mode".yellow
      end

      driver = Selenium::WebDriver.for(:chrome, options: options)
      
      # Hide automation indicators
      driver.execute_script("Object.defineProperty(navigator, 'webdriver', {get: () => undefined})")
      
      puts "WebDriver created successfully with persistent cookies".green
      driver
    end
  end
end
