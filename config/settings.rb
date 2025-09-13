# frozen_string_literal: true

module ThatsMyBisScraper
  # Configuration settings for the scraper
  class Config
    class << self
      attr_accessor :base_url, :user_agent, :timeout, :delay, :headless, :max_retries
      attr_accessor :chrome_user_data_dir, :output_dir

      def configure
        yield self
      end

      def reset!
        @base_url = ENV['TARGET_URL'] || 'https://thatsmybis.com/11258/chonglers/roster'
        @user_agent = ENV.fetch('USER_AGENT', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36')
        @timeout = ENV.fetch('TIMEOUT', 30).to_i
        @delay = ENV.fetch('REQUEST_DELAY', 1).to_i
        @headless = ENV.fetch('HEADLESS', 'false') == 'true'
        @max_retries = ENV.fetch('MAX_RETRIES', 3).to_i
        @chrome_user_data_dir = File.expand_path('data/chrome_user_data')
        @output_dir = File.expand_path('data')
      end

      def output_file_path(filename)
        File.join(output_dir, filename)
      end
    end

    reset!
  end
end
