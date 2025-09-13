# That's My BIS Scraper

A Ruby-based web scraper for extracting roster and character data from That's My BIS (thatsmybis.com) guild management pages.

## Features

- **Single WebDriver Instance**: Efficient browser automation with persistent sessions
- **Roster Scraping**: Collect character profile links from guild roster pages
- **Character Data Extraction**: Extract wishlist items, character info, and item tooltips
- **Persistent Authentication**: Chrome user data persistence to avoid repeated logins
- **JSON Export**: Clean data export in JSON format
- **Modular Architecture**: Well-organized, maintainable codebase

## Project Structure

```
thatsmybis-scraper/
├── bin/
│   └── thatsmybis-scraper          # Main CLI executable
├── config/
│   └── settings.rb                 # Configuration management
├── lib/
│   └── thatsmybis_scraper/
│       ├── cli/
│       │   └── application.rb      # CLI interface
│       ├── scrapers/
│       │   ├── base_scraper.rb     # Base scraping functionality
│       │   ├── roster_scraper.rb   # Roster page scraping
│       │   └── character_scraper.rb # Character page scraping
│       └── utils/
│           └── webdriver_manager.rb # WebDriver management
├── spec/                           # Test files
├── data/                           # Output directory (auto-created)
└── Gemfile                         # Ruby dependencies
```

## Installation

1. **Install Ruby 3.4.3** (using RVM recommended):
   ```bash
   rvm install ruby-3.4.3
   rvm use ruby-3.4.3
   ```

2. **Install dependencies**:
   ```bash
   bundle install
   ```

3. **Set up environment** (optional):
   ```bash
   cp .env.example .env
   # Edit .env with your preferences
   ```

## Usage

### CLI Commands

```bash
# Show help
./bin/thatsmybis-scraper --help

# Scrape roster page
./bin/thatsmybis-scraper roster

# Scrape single character
./bin/thatsmybis-scraper character

# Full scrape (roster + all characters)
./bin/thatsmybis-scraper full

# Debug single character
./bin/thatsmybis-scraper debug
```

### Programmatic Usage

```ruby
require 'thatsmybis_scraper'

# Initialize scrapers
driver_manager = ThatsMyBisScraper::Utils::WebDriverManager.instance
shared_driver = driver_manager.driver

scraper = ThatsMyBisScraper::Scrapers::BaseScraper.new(driver: shared_driver)
roster_scraper = ThatsMyBisScraper::Scrapers::RosterScraper.new(nil, scraper: scraper)
character_scraper = ThatsMyBisScraper::Scrapers::CharacterScraper.new(scraper)

# Scrape roster
profile_links = roster_scraper.collect_profile_links

# Scrape character
character_data = character_scraper.scrape_character_page(profile_links.first[:url])

# Clean up
driver_manager.cleanup
```

## Configuration

Configuration is managed through environment variables or the `config/settings.rb` file:

- `TARGET_URL`: Base roster URL (default: Chonglers roster)
- `HEADLESS`: Run browser in headless mode (default: false)
- `REQUEST_DELAY`: Delay between requests in seconds (default: 1)
- `TIMEOUT`: Request timeout in seconds (default: 30)
- `MAX_RETRIES`: Maximum retry attempts (default: 3)

## Output

The scraper generates JSON files in the `data/` directory:

- `profile_links_YYYYMMDD_HHMMSS.json`: Collected profile links
- `character_data_YYYYMMDD_HHMMSS.json`: Full character data with wishlists

### Character Data Structure

```json
{
  "base_url": "https://thatsmybis.com/11258/chonglers/roster",
  "scraped_at": "2025-01-13T02:30:00Z",
  "total_characters": 25,
  "characters": [
    {
      "name": "CharacterName",
      "class": "Shaman",
      "race": "Draenei",
      "level": 80,
      "professions": ["Engineering", "Enchanting"],
      "wishlists": [
        {
          "name": "Wishlist 1",
          "items": [
            {
              "name": "Item Name",
              "quality": "Epic",
              "wowhead_id": "51242",
              "item_level": 226,
              "stats": {...},
              "set_info": {...}
            }
          ]
        }
      ],
      "url": "https://thatsmybis.com/...",
      "scraped_at": "2025-01-13T02:30:00Z"
    }
  ]
}
```

## Authentication

The scraper handles OAuth authentication automatically:

1. First run: Manual Discord OAuth login required
2. Subsequent runs: Persistent cookies maintain authentication
3. Chrome user data stored in `data/chrome_user_data/` (gitignored)

## Development

### Running Tests

```bash
bundle exec rspec
```

### Code Quality

```bash
bundle exec rubocop
```

### Project Structure

The project follows Ruby best practices:

- **Modular design**: Separate concerns into focused classes
- **Single responsibility**: Each class has one clear purpose
- **Configuration management**: Centralized settings
- **Error handling**: Proper exception handling and logging
- **CLI interface**: Clean command-line interface

## Dependencies

- **selenium-webdriver**: Browser automation
- **nokogiri**: HTML parsing
- **httparty**: HTTP requests
- **colorize**: Terminal output coloring
- **dotenv**: Environment variable management

## License

MIT License - see LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## Troubleshooting

### Common Issues

1. **Ruby version mismatch**: Ensure you're using Ruby 3.4.3
2. **Chrome driver issues**: Chrome must be installed and accessible
3. **Authentication failures**: Clear `data/chrome_user_data/` and re-authenticate
4. **Rate limiting**: Increase `REQUEST_DELAY` if getting blocked

### Debug Mode

Use debug mode to troubleshoot issues:

```bash
./bin/thatsmybis-scraper debug --verbose
```