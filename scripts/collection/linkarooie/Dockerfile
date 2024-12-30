# Dockerfile

# Start with the official Ruby 3.3 image
FROM ruby:3.3

# Create a directory for our app
ENV APP_HOME /usr/src/app
RUN mkdir -p $APP_HOME
WORKDIR $APP_HOME

# Copy Gemfile and Gemfile.lock first for efficient caching
COPY Gemfile Gemfile.lock ./

# Install dependencies
RUN bundle install

# Copy the rest of our code
COPY . .

# Set default command
CMD [ "ruby", "linkarooie_analytics.rb" ]
