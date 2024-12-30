# Start with the official Ruby image
FROM ruby:3.3

# Create app directory
ENV APP_HOME /usr/src/app
RUN mkdir -p $APP_HOME
WORKDIR $APP_HOME

# Create Gemfile
RUN echo "source 'https://rubygems.org'\n\ngem 'httparty'\ngem 'json'\ngem 'fileutils'\ngem 'dotenv'" > Gemfile

# Install dependencies
RUN bundle install

# Copy the script
COPY weather.rb .

# Make the script executable
RUN chmod +x weather.rb

# Set default command
CMD ["./weather.rb"]