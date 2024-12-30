# Weather Script

A Ruby script for fetching and displaying weather data with support for current conditions and forecasts. Outputs data in multiple formats with customizable locations and time periods.

## Features

- Multiple time period support:
  - Current day conditions
  - Weekly forecast
  - Fortnightly forecast
  - Monthly forecast (where available)
- Multiple output formats:
  - Standard output (default)
  - Markdown files
  - JSON files
- Comprehensive weather data:
  - Temperature (current, feels like, min/max)
  - UV index with risk levels
  - Wind speed and direction
  - Humidity and pressure
  - Visibility
  - Sunrise and sunset times
  - Precipitation probability (for forecasts)
- Location configuration:
  - Default to Melbourne, Australia
  - Configurable favorite locations
  - Command-line location override
- Private config file support with example template
- Environment variable support via dotenv

## Requirements

- Ruby 3.3 or higher
- Bundler
- OpenWeather API key
- Required gems:
  - httparty (for API requests)
  - json (included in Ruby standard library)
  - fileutils (included in Ruby standard library)
  - yaml (included in Ruby standard library)
  - dotenv (for environment variables)

## Installation

1. Clone and set up the repository:
```bash
# Clone the repository
git clone git@github.com:loftwah/ubuntu-box.git
cd ubuntu-box/scripts/collection/weather

# Install dependencies
bundle install

# Copy and configure settings
cp weather_config.yml.example ~/.weather_config.yml
# Edit ~/.weather_config.yml with your preferences

# Set up environment variables
cp .env.example .env
# Edit .env with your API key and preferences
```

## Configuration

The script uses a combination of environment variables and a config file. Environment variables take precedence over config file settings.

### Environment Variables

Create a `.env` file in the project directory using the provided `.env.example` as a template:

```bash
# OpenWeather API Configuration
OPENWEATHER_API_KEY=your_api_key_here

# Default Location (optional)
DEFAULT_LOCATION=Melbourne,AU

# Output Settings (optional)
DEFAULT_FORMAT=stdout
DEFAULT_PERIOD=day
OUTPUT_DIR=reports/weather

# Optional API Settings
UNITS=metric
LANGUAGE=en
```

### Config File

Create a `.weather_config.yml` file in your home directory or specify a custom location. Use the provided `weather_config.yml.example` as a template:

```yaml
# API key from OpenWeather
api_key: your_api_key_here

# Default location if none specified
default_location: Melbourne,AU

# Your favorite locations
locations:
  - name: Melbourne
    country: AU
    lat: -37.8136
    lon: 144.9631
  - name: Sydney
    country: AU
    lat: -33.8688
    lon: 151.2093

# Display preferences
units: metric
language: en
temperature_format: celsius
wind_speed: ms
```

## Usage

### Basic Usage

Get current weather for default location:
```bash
./weather.rb
```

### Time Periods

1. Current weather (default):
```bash
./weather.rb -p day
```

2. Weekly forecast:
```bash
./weather.rb -p week
```

3. Fortnightly forecast:
```bash
./weather.rb -p fortnight
```

4. Monthly forecast:
```bash
./weather.rb -p month
```

### Output Formats

1. Standard output (default):
```bash
./weather.rb
```

2. Markdown file:
```bash
./weather.rb -f markdown
```

3. JSON file:
```bash
./weather.rb -f json
```

### Location Override

```bash
./weather.rb -l Sydney,AU
```

### Custom Output Directory

```bash
./weather.rb -f markdown -o /path/to/output
```

### Command Line Options

```
Usage: weather.rb [options]
    -l, --location LOCATION    Location (format: city,country_code)
    -p, --period PERIOD        Period: day, week, fortnight, month
    -f, --format FORMAT        Output format: stdout, markdown, json
    -o, --output-dir DIR       Output directory
    -c, --config FILE         Config file path
    -h, --help                Show this help message
```

## Docker Support

Build and run using Docker:

```bash
# Build the image
docker build -t weather-script .

# Run with default options
docker run -v $HOME/.weather_config.yml:/root/.weather_config.yml weather-script

# Run with custom options
docker run weather-script -l Sydney,AU -p week
```

Or use Docker Compose:

```bash
# Run with Docker Compose
docker-compose up
```

## Project Structure

```
.
├── Dockerfile              # Docker configuration
├── README.md              # This file
├── .env.example           # Example environment variables
├── docker-compose.yml     # Docker Compose configuration
├── weather.rb             # Main script
├── weather_config.yml.example  # Example configuration
└── reports/               # Generated reports (if using file output)
    └── weather/
        ├── YYYYMMDD_location_period.json
        └── YYYYMMDD_location_period.md
```

## Output Examples

### Standard Output
```markdown
# Weather Report for Melbourne,AU

Generated on: 2024-12-30 10:00:00 AEDT

## Current Conditions

🌡️ **Temperature**
- Current: 22°C
- Feels like: 21°C
- Today's min: 18°C
- Today's max: 25°C

☀️ **Sun & UV**
- UV Index: 8 (Very High)
- Sunrise: 05:45
- Sunset: 20:30
...
```

### JSON Output
```json
{
  "timestamp": "2024-12-30T10:00:00+11:00",
  "location": "Melbourne,AU",
  "current": {
    "temperature": {
      "current": 22,
      "feels_like": 21,
      "min": 18,
      "max": 25
    },
    "humidity": 65,
    "pressure": 1015,
    ...
  }
}
```

## Configuration Priority

The script checks for settings in this order:
1. Command line arguments (highest priority)
2. Environment variables (from .env file)
3. Config file settings (from weather_config.yml)
4. Default values (lowest priority)

This means you can:
- Use environment variables for sensitive data (API keys)
- Keep general preferences in the config file
- Override any setting temporarily via command line
- Share your config file without exposing sensitive data

## Error Handling

The script includes comprehensive error handling for:

- Invalid API keys
- Network failures
- Invalid locations
- Missing configuration
- File system errors
- Invalid command line arguments

## Acknowledgments

- Weather data provided by OpenWeather API
- Built with Ruby and Docker