# frozen_string_literal: true

source "https://rubygems.org"

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

# gem "rails"

gem "sinatra", "~> 2.1"

gem "sinatra-reloader", "~> 1.0"

gem "rack", "~> 2.2"

gem "http", "~> 5.0.4"

gem "dxruby", "~> 1.4"

ruby ">= 3.0.3"

gem "sinatra-contrib", "~> 2.1"

group :production, optional: true do
  gem "unicorn", "~> 6.1"
end
