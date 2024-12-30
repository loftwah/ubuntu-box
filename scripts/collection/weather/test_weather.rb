#!/usr/bin/env ruby

# Test script to run all weather periods
puts "\nTesting all weather periods for Sunbury..."

PERIODS = ['day', 'week', 'fortnight', 'month']

PERIODS.each do |period|
  puts "\n#{'=' * 80}"
  puts "Testing period: #{period}"
  puts "=" * 80
  
  system("ruby weather.rb -p #{period}")
  
  # Add a small delay between requests to avoid rate limiting
  sleep(1)
end

puts "\nAll tests completed!"