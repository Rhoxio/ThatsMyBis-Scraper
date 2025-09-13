# frozen_string_literal: true

module ThatsMyBisScraper
  module Scrapers
    # Character scraper for extracting wishlist data from individual character pages
    class CharacterScraper
    def initialize(scraper = nil)
      @scraper = scraper || BaseScraper.new
    end

    def scrape_character_page(url, use_persistent = false)
      puts "Scraping character page: #{url}".blue
      
      # Always use the provided scraper (which should have the shared WebDriver)
      doc = @scraper.scrape(url)
      
      character_data = extract_character_data(doc)
      character_data[:url] = url
      character_data[:scraped_at] = Time.now.iso8601
      
      puts "Successfully scraped character: #{character_data[:name]}".green
      character_data
    end

    def extract_character_data(doc)
      data = {
        name: extract_character_name(doc),
        class: extract_character_class(doc),
        race: extract_character_race(doc),
        level: extract_character_level(doc),
        professions: extract_professions(doc),
        wishlists: extract_wishlists(doc),
        loot_received: extract_loot_received(doc),
        recipes: extract_recipes(doc),
        public_note: extract_public_note(doc)
      }
      
      data
    end

    def extract_character_name(doc)
      # Look for character name in the main heading - try multiple selectors
      name_element = doc.css('h1 a.text-shaman, h1 a.text-mage, h1 a.text-paladin, h1 a.text-warrior, h1 a.text-hunter, h1 a.text-rogue, h1 a.text-priest, h1 a.text-druid, h1 a.text-warlock, h1 a.text-death-knight, h1 a.text-monk, h1 a.text-demon-hunter, h1 a.text-evoker').first
      
      # Fallback: look for any link with class starting with "text-" in h1
      name_element ||= doc.css('h1 a[class^="text-"]').first
      
      # Another fallback: look in the title meta tag
      if name_element.nil?
        title_element = doc.css('title').first
        if title_element&.text&.include?(' - That\'s My BIS')
          name_element = title_element.text.split(' - That\'s My BIS').first.strip
        end
      else
        name_element = name_element.text.strip
      end
      
      name_element
    end

    def extract_character_class(doc)
      # Look for class information in the character details
      class_element = doc.css('li .fas.fa-bow-arrow, li .fas.fa-sword, li .fas.fa-shield, li .fas.fa-magic, li .fas.fa-heart, li .fas.fa-leaf, li .fas.fa-skull, li .fas.fa-fist-raised').first
      if class_element
        # Extract class name from the parent text
        parent_text = class_element.parent.text.strip
        class_name = parent_text.split(' ').last
        class_name
      end
    end

    def extract_character_race(doc)
      # Look for race information
      race_element = doc.css('li small').find { |el| el.text.include?('Draenei') || el.text.include?('Human') || el.text.include?('Night Elf') || el.text.include?('Dwarf') || el.text.include?('Gnome') || el.text.include?('Orc') || el.text.include?('Undead') || el.text.include?('Tauren') || el.text.include?('Troll') || el.text.include?('Blood Elf') }
      if race_element
        race_text = race_element.text.strip
        race_parts = race_text.split(' ')
        race_parts.last # Get the race name (last part after level)
      end
    end

    def extract_character_level(doc)
      # Look for level information
      level_element = doc.css('li small').find { |el| el.text.match?(/\d+/) }
      if level_element
        level_text = level_element.text.strip
        level_match = level_text.match(/(\d+)/)
        level_match[1].to_i if level_match
      end
    end

    def extract_professions(doc)
      # Look for profession information
      prof_element = doc.css('li small').find { |el| el.text.include?('Engineering') || el.text.include?('Enchanting') || el.text.include?('Mining') || el.text.include?('Herbalism') || el.text.include?('Skinning') || el.text.include?('Tailoring') || el.text.include?('Blacksmithing') || el.text.include?('Leatherworking') || el.text.include?('Alchemy') || el.text.include?('Jewelcrafting') || el.text.include?('Inscription') }
      if prof_element
        prof_text = prof_element.text.strip
        prof_text.split(',').map(&:strip)
      else
        []
      end
    end

    def extract_wishlists(doc)
      wishlists = []
      
      # Find all wishlist sections
      wishlist_sections = doc.css('.col-12 .text-legendary, .col-12 .text-gold')
      
      wishlist_sections.each do |section|
        if section.text.include?('Wishlist')
          wishlist_name = section.text.strip
          
          # Find the container that holds the items - need to go up to find the parent that contains both title and items
          # The structure is: parent div > title div > items div
          container = section.parent.parent
          
          wishlist_data = extract_wishlist_items(container)
          
          wishlists << {
            name: wishlist_name,
            items: wishlist_data
          }
        end
      end
      
      wishlists
    end

    def extract_wishlist_items(wishlist_container)
      items = []
      
      # Look for ordered lists containing wishlist items
      # Only use js-wishlist-unsorted (visible) to avoid duplicates from sorted list
      ol_elements = wishlist_container.css('ol.js-wishlist-unsorted li')
      
      ol_elements.each do |item_element|
        item_data = extract_item_data(item_element)
        items << item_data if item_data[:name]
      end
      
      items
    end

    def extract_item_data(item_element)
      item_data = {}
      
      # Extract item link and basic info
      item_link = item_element.css('a[data-wowhead*="item="]').first
      
      if item_link
        item_data[:name] = item_link.text.strip
        item_data[:url] = item_link['href']
        item_data[:wowhead_id] = extract_wowhead_id(item_link['data-wowhead'])
        item_data[:quality] = extract_item_quality(item_link['class'])
        
        # Extract item icon
        icon_element = item_link.css('span.iconsmall ins').first
        if icon_element
          style = icon_element['style']
          if style && style.include?('background-image:')
            icon_url = style.match(/url\(["']?(.*?)["']?\)/)[1]
            item_data[:icon_url] = icon_url
          end
        end
        
        # Extract heroic/raid difficulty
        difficulty_element = item_element.css('.text-uncommon, .text-legendary, .text-epic').first
        if difficulty_element
          item_data[:difficulty] = difficulty_element.text.strip
        end
        
        # Extract priority/position
        value_attr = item_element['value']
        if value_attr
          item_data[:priority] = value_attr.to_i
        end
        
        # Extract timestamp
        timestamp_element = item_element.css('.js-timestamp-title').first
        if timestamp_element
          item_data[:added_at] = timestamp_element['data-timestamp']
          item_data[:added_by] = extract_added_by(item_element)
        end
        
        # Extract notes
        note_element = item_element.css('li').find { |li| li.text.include?('Note:') }
        if note_element
          note_text = note_element.text.strip
          item_data[:note] = note_text.gsub(/^Note:\s*/, '')
        end
        
        # Extract tooltip data if available
        tooltip_data = extract_tooltip_data(item_link['data-wowhead'], @scraper.last_document)
        item_data.merge!(tooltip_data) if tooltip_data
      end
      
      item_data
    end

    def extract_wowhead_id(wowhead_attr)
      return nil unless wowhead_attr
      
      match = wowhead_attr.match(/item=(\d+)/)
      match[1] if match
    end

    def extract_item_quality(class_attr)
      return nil unless class_attr
      
      if class_attr.include?('q0')
        'Poor'
      elsif class_attr.include?('q1')
        'Common'
      elsif class_attr.include?('q2')
        'Uncommon'
      elsif class_attr.include?('q3')
        'Rare'
      elsif class_attr.include?('q4')
        'Epic'
      elsif class_attr.include?('q5')
        'Legendary'
      else
        'Unknown'
      end
    end

    def extract_added_by(item_element)
      added_by_link = item_element.css('a.text-muted').first
      added_by_link&.text&.strip
    end

    def extract_loot_received(doc)
      loot_items = []
      
      # Look for loot received section
      loot_section = doc.css('.col-12 .text-success').find { |el| el.text.include?('Loot Received') }
      
      if loot_section
        loot_container = loot_section.parent
        ol_elements = loot_container.css('ol li')
        
        ol_elements.each do |item_element|
          item_data = extract_item_data(item_element)
          loot_items << item_data if item_data[:name]
        end
      end
      
      loot_items
    end

    def extract_recipes(doc)
      recipes = []
      
      # Look for recipes section
      recipes_section = doc.css('.col-12 .text-success').find { |el| el.text.include?('Recipes') }
      
      if recipes_section
        recipes_container = recipes_section.parent
        # Recipes might be in a different format, extract as needed
        # For now, return empty array as the sample shows "—"
        recipes = []
      end
      
      recipes
    end

    def extract_public_note(doc)
      # Look for public note section
      note_section = doc.css('.col-12 .text-muted').find { |el| el.text.include?('Public Note') }
      
      if note_section
        note_container = note_section.parent
        note_text = note_container.css('.js-markdown-parsed').first&.text&.strip
        note_text == '—' ? nil : note_text
      end
    end

    def extract_tooltip_data(wowhead_attr, doc = nil)
      return nil unless wowhead_attr
      
      item_id = extract_wowhead_id(wowhead_attr)
      return nil unless item_id
      
      tooltip_data = {}
      
      # Extract basic tooltip info from data attributes
      if wowhead_attr.include?('domain=')
        domain_match = wowhead_attr.match(/domain=(\w+)/)
        tooltip_data[:domain] = domain_match[1] if domain_match
      end
      
      # Try to find pre-loaded tooltip data in the page
      if doc
        tooltip_html = find_tooltip_in_page(doc, item_id)
        if tooltip_html
          tooltip_data.merge!(parse_tooltip_html(tooltip_html))
        end
      end
      
      tooltip_data
    end

    def find_tooltip_in_page(doc, item_id)
      # Look for tooltip divs that might contain the item data
      tooltip_elements = doc.css('.wowhead-tooltip, .whtt-tooltip, [class*="tooltip"]')
      
      # Try to find tooltip that matches our item ID
      tooltip_elements.find do |tooltip|
        # Check if tooltip contains references to our item
        tooltip_html = tooltip.to_html
        tooltip_html.include?(item_id) || 
        tooltip_html.include?('item=') ||
        tooltip_html.include?('wowhead')
      end
    end

    def parse_tooltip_html(tooltip_element)
      tooltip_data = {}
      
      # Extract item level
      ilvl_match = tooltip_element.text.match(/Item Level[:\s]*(\d+)/i)
      tooltip_data[:item_level] = ilvl_match[1].to_i if ilvl_match
      
      # Extract armor value
      armor_match = tooltip_element.text.match(/(\d+)\s*Armor/i)
      tooltip_data[:armor] = armor_match[1].to_i if armor_match
      
      # Extract durability
      durability_match = tooltip_element.text.match(/Durability\s+(\d+)\s*\/\s*(\d+)/i)
      if durability_match
        tooltip_data[:durability] = {
          current: durability_match[1].to_i,
          maximum: durability_match[2].to_i
        }
      end
      
      # Extract required level
      level_match = tooltip_element.text.match(/Requires Level[:\s]*(\d+)/i)
      tooltip_data[:required_level] = level_match[1].to_i if level_match
      
      # Extract stats (Agility, Stamina, etc.)
      stats = extract_stats_from_tooltip(tooltip_element)
      tooltip_data[:stats] = stats if stats.any?
      
      # Extract item type and slot
      slot_match = tooltip_element.text.match(/(Head|Neck|Shoulder|Back|Chest|Wrist|Hands|Waist|Legs|Feet|Finger|Trinket|Weapon|Off Hand|Shield|Ranged|Ammo)/i)
      tooltip_data[:slot] = slot_match[1] if slot_match
      
      # Extract binding info
      binding_match = tooltip_element.text.match(/(Binds when picked up|Binds when equipped|Binds to account)/i)
      tooltip_data[:binding] = binding_match[1] if binding_match
      
      # Extract classes that can use the item
      classes = extract_classes_from_tooltip(tooltip_element)
      tooltip_data[:classes] = classes if classes.any?
      
      # Extract set information
      set_info = extract_set_info_from_tooltip(tooltip_element)
      tooltip_data[:set_info] = set_info if set_info
      
      tooltip_data
    end

    def extract_stats_from_tooltip(tooltip_element)
      stats = []
      text = tooltip_element.text
      
      # Common stat patterns
      stat_patterns = [
        { pattern: /\+(\d+)\s*Agility/i, stat: 'Agility' },
        { pattern: /\+(\d+)\s*Stamina/i, stat: 'Stamina' },
        { pattern: /\+(\d+)\s*Intellect/i, stat: 'Intellect' },
        { pattern: /\+(\d+)\s*Strength/i, stat: 'Strength' },
        { pattern: /\+(\d+)\s*Spirit/i, stat: 'Spirit' },
        { pattern: /\+(\d+)\s*Attack Power/i, stat: 'Attack Power' },
        { pattern: /\+(\d+)\s*Spell Power/i, stat: 'Spell Power' },
        { pattern: /\+(\d+)%\s*Crit/i, stat: 'Critical Strike' },
        { pattern: /\+(\d+)%\s*Haste/i, stat: 'Haste' },
        { pattern: /\+(\d+)%\s*Hit/i, stat: 'Hit' }
      ]
      
      stat_patterns.each do |pattern_data|
        match = text.match(pattern_data[:pattern])
        if match
          stats << {
            stat: pattern_data[:stat],
            value: match[1].to_i,
            percentage: pattern_data[:pattern].to_s.include?('%')
          }
        end
      end
      
      stats
    end

    def extract_classes_from_tooltip(tooltip_element)
      classes = []
      text = tooltip_element.text
      
      class_patterns = [
        /Classes:\s*([^<]+)/i,
        /(Warrior|Paladin|Hunter|Rogue|Priest|Shaman|Mage|Warlock|Monk|Druid|Death Knight|Demon Hunter|Evoker)/i
      ]
      
      class_patterns.each do |pattern|
        match = text.match(pattern)
        if match
          if match[1] && match[1].include?(',')
            # Multiple classes listed
            classes = match[1].split(',').map(&:strip)
          else
            classes << match[1] || match[0]
          end
          break
        end
      end
      
      classes.uniq
    end

    def extract_set_info_from_tooltip(tooltip_element)
      set_info = {}
      text = tooltip_element.text
      
      # Look for set information
      set_match = text.match(/([^(]+)\s*\((\d+)\/(\d+)\)/i)
      if set_match
        set_info = {
          name: set_match[1].strip,
          current_pieces: set_match[2].to_i,
          total_pieces: set_match[3].to_i
        }
        
        # Extract set bonuses
        set_bonuses = []
        bonus_matches = text.scan(/\((\d+)\)\s*Set\s*:\s*([^<]+)/i)
        bonus_matches.each do |pieces, bonus|
          set_bonuses << {
            pieces: pieces.to_i,
            bonus: bonus.strip
          }
        end
        set_info[:bonuses] = set_bonuses if set_bonuses.any?
      end
      
      set_info
    end

    def fetch_wowhead_tooltip_data(item_id, domain = 'wotlk')
      # This method would make an API call to Wowhead to get detailed item information
      # For now, we'll return a placeholder structure
      {
        item_id: item_id,
        domain: domain,
        # Additional fields would be populated from Wowhead API:
        # item_level: nil,
        # armor: nil,
        # stats: [],
        # durability: nil,
        # required_level: nil,
        # classes: [],
        # item_type: nil,
        # slot: nil,
        # binding: nil,
        # set_info: nil,
        # effects: [],
        # description: nil
      }
    end
    end
  end
end
