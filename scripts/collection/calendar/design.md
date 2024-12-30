# Design Document: Google Calendar Report Generator

## Overview

The Google Calendar Report Generator is a Ruby-based script that connects to Google Calendar to fetch events, generate reports for daily, weekly, fortnightly, and monthly intervals, and outputs the results in either **stdout** or **Markdown format**. The tool is designed to handle multiple calendars and provide a consolidated or individual event summary for specified intervals.

---

## Goals

1. **Ease of Use**: Fetch calendar events and generate reports with minimal setup.
2. **Support Multiple Calendars**: Retrieve and aggregate data from multiple calendars.
3. **Flexible Reporting**: Generate daily, weekly, fortnightly, and monthly reports.
4. **Output Formats**: Display reports on stdout or save them as Markdown files.
5. **Reusable and Extensible**: Provide a modular design for future enhancements.

---

## Functional Requirements

1. Authenticate and connect to Google Calendar using OAuth 2.0.
2. Fetch events within specified time intervals:
   - Daily
   - Weekly
   - Fortnightly
   - Monthly
3. Handle recurring events using Google Calendar's recurrence rules.
4. Support output formats:
   - Plaintext (stdout)
   - Markdown (.md file)
5. Option to fetch events from multiple Google Calendar IDs.

---

## Non-Functional Requirements

1. **Performance**: Fetch and process events quickly within API rate limits.
2. **Security**: Safely store OAuth tokens and credentials.
3. **Scalability**: Handle multiple calendars and large numbers of events.
4. **Maintainability**: Use modular code structure for easy updates and extensions.

---

## Architecture

### High-Level Design

The system is composed of three main components:

1. **Google Calendar API Integration**

   - Authenticate via OAuth 2.0.
   - Fetch events from specified calendars using the Google Calendar API (v3).

2. **Event Processing**

   - Filter events by specified time intervals.
   - Parse and format event details (e.g., start time, end time, recurrence rules).

3. **Report Generation**
   - Generate reports in either stdout or Markdown format.

### Component Diagram

```
+-------------------------+       +-----------------------+
| Google Calendar API    | <---> | Calendar Integration |
| (v3)                   |       +-----------------------+
+-------------------------+
            |
            v
+-------------------------+
| Event Processing        |
| - Fetch Events          |
| - Filter by Interval    |
| - Handle Recurrence     |
+-------------------------+
            |
            v
+-------------------------+
| Report Generator        |
| - Markdown Formatter    |
| - Stdout Formatter      |
+-------------------------+
```

---

## Detailed Design

### 1. Google Calendar API Integration

#### Description

This module handles authentication and API requests to Google Calendar.

#### Workflow

1. Authenticate using OAuth 2.0 with the `google-api-client` gem.
2. Fetch calendar events via the `list_events` method.
3. Handle tokens securely using `token.yaml` for offline access.

#### Code Snippet

```ruby
require 'google/apis/calendar_v3'
require 'googleauth'
require 'googleauth/stores/file_token_store'

CREDENTIALS_PATH = 'credentials.json'
TOKEN_PATH = 'token.yaml'
SCOPE = Google::Apis::CalendarV3::AUTH_CALENDAR

# Authenticate and get service instance
def authorize
  client_id = Google::Auth::ClientId.from_file(CREDENTIALS_PATH)
  token_store = Google::Auth::Stores::FileTokenStore.new(file: TOKEN_PATH)
  authorizer = Google::Auth::UserAuthorizer.new(client_id, SCOPE, token_store)
  user_id = 'default'
  credentials = authorizer.get_credentials(user_id)

  if credentials.nil?
    puts "Authorize this application by visiting this URL:"
    puts authorizer.get_authorization_url
    puts "Enter the code:"
    code = gets.chomp
    credentials = authorizer.get_and_store_credentials_from_code(
      user_id: user_id, code: code
    )
  end

  credentials
end
```

---

### 2. Event Processing

#### Description

Filters and processes events based on time intervals and recurrence rules.

#### Input

- `calendar_id`: The Google Calendar ID.
- `start_time`, `end_time`: Date range for filtering events.

#### Output

- List of events within the specified range, including recurring events.

#### Key Methods

- `fetch_events`: Retrieves events from the Google Calendar API.
- `filter_events`: Filters events by date range and applies recurrence rules.

#### Code Snippet

```ruby
def fetch_events(service, calendar_id, start_time, end_time)
  service.list_events(
    calendar_id,
    time_min: start_time.iso8601,
    time_max: end_time.iso8601,
    single_events: true,
    order_by: 'startTime'
  ).items
end

# Example usage
start_time = DateTime.now
end_time = start_time + 7
fetch_events(service, 'primary', start_time, end_time)
```

---

### 3. Report Generation

#### Description

Generates formatted reports in stdout or Markdown format.

#### Input

- List of events.
- Output format (`:stdout` or `:markdown`).

#### Output

- Formatted report as a string or saved Markdown file.

#### Key Methods

- `generate_report`: Formats the events into a report string.
- `output_report`: Outputs the report to stdout or saves it as a Markdown file.

#### Code Snippet

```ruby
def generate_report(events, title)
  report = "# #{title}\n\n"
  events.each do |event|
    start = event.start.date || event.start.date_time
    report += "- **#{event.summary}**: #{start}\n"
  end
  report.empty? ? "No events found.\n" : report
end

def output_report(report, format = :stdout)
  if format == :markdown
    File.write('calendar_report.md', report)
    puts "Report saved to calendar_report.md"
  else
    puts report
  end
end
```

---

## Example Usage

```ruby
service = Google::Apis::CalendarV3::CalendarService.new
service.authorization = authorize

calendar_ids = ['primary']
interval = :weekly # Options: :daily, :weekly, :fortnightly, :monthly

now = DateTime.now
ranges = {
  daily: { start: now, end: now + 1 },
  weekly: { start: now, end: now + 7 },
  fortnightly: { start: now, end: now + 14 },
  monthly: { start: now, end: now >> 1 }
}

start_time = ranges[interval][:start]
end_time = ranges[interval][:end]

report = ""
calendar_ids.each do |calendar_id|
  events = fetch_events(service, calendar_id, start_time, end_time)
  report += generate_report(events, "Report for #{calendar_id}")
end

output_report(report, :markdown)
```

---

## Future Enhancements

1. **CLI Support**: Add CLI arguments for specifying intervals and output formats.
2. **Advanced Filters**: Support keyword filters, event types, or specific attendees.
3. **Scheduler Integration**: Automate the script using a cron job or `rufus-scheduler`.
4. **Export Formats**: Add support for `.ics` (iCalendar) exports.
5. **Web Interface**: Provide a simple UI for non-technical users.

---

## Conclusion

This design leverages the Google Calendar API for robust event management and reporting. The modular approach ensures flexibility and extensibility, making it easy to add features or adapt to new requirements.
