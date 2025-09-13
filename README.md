# ThatsMyBis Scraper

A Ruby web scraper project for extracting data from websites.

## Prerequisites

- Ruby 3.4.3 (managed via `.ruby-version`)
- Bundler

## Setup

1. Install Ruby 3.4.3 (if not already installed):
   ```bash
   rvm install ruby-3.4.3
   rvm use ruby-3.4.3
   ```

2. Install dependencies:
   ```bash
   bundle install
   ```

3. Configure environment variables:
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

## Usage

Run the scraper:
```bash
bundle exec ruby bin/scrape
```

Or make the script executable and run directly:
```bash
./bin/scrape
```

## Development

Run tests:
```bash
bundle exec rspec
```

Run linting:
```bash
bundle exec rubocop
```

## Project Structure

```
├── bin/                    # Executable scripts
├── config/                 # Configuration files
├── data/                   # Output data files
├── lib/                    # Main application code
├── logs/                   # Log files
├── spec/                   # Test files
├── .env.example           # Environment variables template
├── .gitignore             # Git ignore rules
├── .rubocop.yml           # RuboCop configuration
├── .ruby-version          # Ruby version specification
├── Gemfile                # Ruby dependencies
└── README.md              # This file
```

## Features

- HTTP request handling with retries
- HTML parsing with Nokogiri
- Configurable delays and timeouts
- Environment-based configuration
- Comprehensive error handling
- Colored console output
- Test suite with VCR for HTTP mocking

## Contributing

1. Follow the RuboCop style guidelines
2. Write tests for new features
3. Update documentation as needed
