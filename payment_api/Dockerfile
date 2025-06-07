FROM ruby:3.3

# Install dependencies including Rust for temporalio gem
RUN apt-get update -qq && apt-get install -y build-essential curl && \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
    . $HOME/.cargo/env

WORKDIR /usr/src/app

# Copy Gemfile and install gems (including temporalio)
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Copy application code
COPY . .

# Run the service
EXPOSE 3000
CMD ["bundle", "exec", "puma", "-p", "3000"]
