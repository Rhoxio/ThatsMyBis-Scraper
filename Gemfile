# frozen_string_literal: true

source "https://rubygems.org"

ruby "3.4.3"

# Core dependencies
gem "bundler", "~> 2.5"

# Web scraping gems
gem "nokogiri", "~> 1.16"
gem "httparty", "~> 0.21"
gem "selenium-webdriver", "~> 4.15"

# Development and testing
gem "rspec", "~> 3.13", group: :test
gem "rubocop", "~> 1.59", group: :development
gem "rubocop-rspec", "~> 2.25", group: :development

# Utilities
gem "dotenv", "~> 2.8"
gem "colorize", "~> 1.1"
gem "pry", "~> 0.14", group: :development

group :test do
  gem "webmock", "~> 3.19"
  gem "vcr", "~> 6.2"
end
