#!/usr/bin/env ruby
# frozen_string_literal: true

require 'nokogiri'

# Test the filtering logic
def test_profile_link_filtering
  # Sample HTML that includes both real profile links and "create character" links
  sample_html = <<~HTML
    <div>
      <a class="dropdown-item" href="/11258/chonglers/c/540876/aelektra">
        <span class="fas fa-fw fa-user"></span> Profile
      </a>
      <a class="dropdown-item" href="/11258/chonglers/c/create?member_id=240895">
        <span class="fas fa-user-plus"></span> Create character
      </a>
      <a class="dropdown-item" href="/11258/chonglers/c/123456/anotherplayer">
        <span class="fas fa-fw fa-user"></span> Profile
      </a>
    </div>
  HTML

  doc = Nokogiri::HTML(sample_html)
  profile_links = []

  puts "Testing profile link filtering..."
  puts "Sample HTML contains:"
  doc.css('a.dropdown-item[href*="/c/"]').each do |link|
    puts "  - #{link['href']} (#{link.text.strip})"
  end

  puts "\nFiltering results:"
  doc.css('a.dropdown-item[href*="/c/"]').each do |link|
    href = link['href']
    next if href.nil? || href.empty?
    
    # Skip "create character" links and other non-profile links
    if href.include?('/c/create') || 
       href.include?('member_id=') ||
       link.text.strip.downcase.include?('create') ||
       link.text.strip.downcase.include?('new')
      
      puts "  FILTERED OUT: #{href} (#{link.text.strip})"
      next
    end
    
    puts "  INCLUDED: #{href} (#{link.text.strip})"
    profile_links << {
      url: href,
      text: link.text.strip
    }
  end

  puts "\nFinal results:"
  puts "Total profile links found: #{profile_links.length}"
  profile_links.each_with_index do |link, index|
    puts "  #{index + 1}. #{link[:text]} - #{link[:url]}"
  end
end

test_profile_link_filtering
