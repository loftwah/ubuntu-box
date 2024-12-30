# Linkarooie Analytics Scraper

A Ruby script for scraping and analyzing Linkarooie analytics pages. Outputs data in multiple formats with proper formatting.

## Features

- Scrapes comprehensive analytics data from Linkarooie profiles
- Supports multiple output formats:
  - Standard output (default)
  - Markdown files
  - JSON files
- Properly formatted markdown output
- Configurable output directory
- Command-line interface with option parsing
- Comprehensive error handling
- Data sanitization and formatting

## Requirements

- Ruby 3.3 or higher
- Bundler
- Required gems (installed via Bundler):
  - httparty
  - nokogiri
  - json (included in Ruby standard library)
  - fileutils (included in Ruby standard library)
  - optparse (included in Ruby standard library)

## Installation

```bash
# Clone the repository
git clone git@github.com:loftwah/ubuntu-box.git
cd ubuntu-box/scripts/collection

# Install dependencies
bundle install
```

## Usage

### Basic Usage

Print analytics to standard output:

```bash
bundle exec ruby linkarooie_analytics.rb -u username
```

### Output Formats

1. Standard output (default):

```bash
bundle exec ruby linkarooie_analytics.rb -u username
```

2. Markdown file:

```bash
bundle exec ruby linkarooie_analytics.rb -u username -f markdown
```

3. JSON file:

```bash
bundle exec ruby linkarooie_analytics.rb -u username -f json
```

### Custom Output Directory

```bash
bundle exec ruby linkarooie_analytics.rb -u username -f markdown -o /path/to/output
```

### Command Line Options

```
Usage: linkarooie_analytics.rb [options]
    -u, --username USERNAME          Linkarooie username
    -f, --format FORMAT              Output format (stdout/markdown/json)
    -o, --output-dir DIR            Output directory
    -h, --help                       Show this help message
```

## Project Structure

```
linkarooie-analytics/
├── Gemfile                 # Dependencies
├── README.md              # This file
├── linkarooie_analytics.rb # Main script
└── reports/               # Generated reports (if using file output)
    └── analytics/
        ├── YYYYMMDD_analytics.json
        └── YYYYMMDD_analytics.md
```

## Output Formats

### 1. Standard Output (Default)

Prints a properly formatted markdown report to the terminal:

```markdown
# Linkarooie Analytics Report for @username

Generated on: YYYY-MM-DD HH:MM:SS TZ

## Overall Metrics

- Total page views: X,XXX
- Total link clicks: X,XXX
- Total achievement views: XXX
- Unique visitors: X,XXX

[Additional sections follow...]
```

### 2. Markdown File

Generates a properly formatted markdown file with:

- Consistent header hierarchy
- Proper spacing between sections
- Clean list formatting
- Proper line breaks
- Sections include:
  - Overall metrics
  - Latest daily metrics
  - Top visitor locations
  - Link performance
  - Achievement performance
  - Browser usage
  - Historical data

### 3. JSON File

Generates a structured JSON file containing:

- Timestamp
- Overall metrics
- Latest daily metrics
- Daily views data
- Unique visitors data
- Top visitor locations
- Link analytics
- Achievement analytics
- Browser usage data

## Data Extraction Details

The script extracts the following data points:

### Overall Metrics

- Total page views
- Total link clicks
- Total achievement views
- Unique visitors

### Latest Daily Metrics

- Page views
- Link clicks
- Achievement views
- Unique visitors

### Top Visitor Locations

- Country
- View count

### Link Analytics

- Link title
- Total clicks
- Unique visitors

### Achievement Analytics

- Achievement title
- Total views
- Unique viewers

### Browser Usage

- Browser name
- Usage percentage

## Error Handling

The script includes comprehensive error handling for:

### Network Errors

- Connection failures
- Invalid responses
- Timeout errors

### Parsing Errors

- Missing data
- Invalid data formats
- Incomplete responses

### File System Errors

- Permission issues
- Directory creation failures
- File writing errors

### Command Line Errors

- Invalid arguments
- Missing required options
- Invalid output formats

## Debugging Tips

### Common Issues

1. SSL/TLS Errors:

```bash
# Verify SSL certificates are up to date
bundle update
```

2. Permission Issues:

```bash
# Check directory permissions
ls -la reports/analytics
# Set correct permissions if needed
chmod 755 reports/analytics
```

3. Network Issues:

```bash
# Test network connectivity
curl -I https://linkarooie.com
```

### Debugging Output

Add debugging output by modifying the script:

```ruby
puts "Fetching data..." if options[:debug]
puts "Processing response..." if options[:debug]
```

## Customization

### Adding New Metrics

1. Add extraction method:

```ruby
def extract_new_metric
  # Your extraction logic here
end
```

2. Add formatting method:

```ruby
def format_new_metric(data)
  # Your formatting logic here
end
```

3. Update the main data structure:

```ruby
def extract_data
  {
    existing_metrics: extract_existing_metrics,
    new_metric: extract_new_metric
  }
end
```

### Modifying Output Formats

1. Add new output format:

```ruby
def output_custom_format(data)
  # Your custom format logic here
end
```

2. Update the generate_report method:

```ruby
def generate_report
  case @output_format
  when 'custom'
    output_custom_format(data)
  else
    output_stdout(data)
  end
end
```

## Best Practices

### Rate Limiting

The script includes built-in delays to avoid overloading the server:

```ruby
sleep(2) # 2-second delay between requests
```

### Data Validation

All extracted data is validated before processing:

```ruby
def validate_data(data)
  return false unless data[:required_field]
  true
end
```

### Error Recovery

The script includes retry logic for transient failures:

```ruby
def with_retry(max_attempts = 3)
  attempt = 0
  begin
    attempt += 1
    yield
  rescue StandardError => e
    retry if attempt < max_attempts
    raise
  end
end
```

## Contributing

1. Fork the repository
2. Create your feature branch
3. Add tests for new features
4. Ensure all tests pass
5. Submit a pull request

## License

MIT License - Feel free to use and modify this code for your own purposes.

## Support

For issues and feature requests, please:

1. Check existing issues on GitHub
2. Create a new issue with:
   - Clear description
   - Steps to reproduce
   - Expected behavior
   - Actual behavior
   - Ruby version and environment details

## Acknowledgments

- Thanks to all contributors
- Inspired by web scraping best practices
- Built with Ruby and open source tools

## Future Enhancements

Planned features:

- Additional output formats (CSV, HTML)
- Historical data comparison
- Automated scheduling
- Email notifications
- Data visualization options
