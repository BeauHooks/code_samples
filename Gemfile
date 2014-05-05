###
#
# NOTE: Needed dependencies before running this application for Linux
#
# sudo apt-get install pdftk libtiff-tools libmagickwand-dev xvfb x11-xkb-utils xfonts-100dpi xfonts-75dpi xfonts-scalable xfonts-cyrillic
###

source 'https://rubygems.org'

# Core Gems
gem 'rails', '3.2.13'

# Modules
gem 'shipments_module', path: './vendor/engines/shipments_module'
gem 'rate_calculator_module', path: './vendor/engines/rate_calculator_module'

# Database and DB Utitlity Gems
gem 'mysql2', '~> 0.3.12b4'
gem 'redis'
gem 'redis-store'
gem 'redis-rails'

# Full Text Indexed Searching
gem 'thinking-sphinx'

# Javascript and JSON Gems
gem 'jquery-rails'
gem 'therubyracer', '~> 0.10.1'
gem 'underscore-rails'
gem 'js-routes'
gem 'hashdiff'
gem 'knockoutjs-rails'
gem 'jasminerice'
gem 'guard-jasmine'

# Push notifications
gem 'faye'

# Application monitoring tools
gem 'newrelic_rpm'
gem 'exception_notification'

# Authentication
gem 'devise'

# Extra Tools
gem 'pdfkit', '~> 0.5.3'
gem 'delocalize', '~> 0.3.1'
gem 'kaminari', '~> 0.13.0'
gem 'net-ldap', '~> 0.3.1'
gem 'army-negative', '~> 3.2.0', :git => 'https://github.com/Digi-Cazter/army-negative.git'
gem 'tinymce-rails'
gem 'remotipart', '~> 1.2'
gem 'numbers_and_words'
gem 'currency-in-words'
gem "omniship", :git => "https://github.com/Digi-Cazter/omniship.git"
gem 'rmagick'
gem 'nokogiri'
gem 'typhoeus'
gem 'normalize-rails'
gem 'pry', group: :development

# Rake task dependencies
gem 'listen'
gem 'daemons'
gem 'net-ssh', '~> 2.5', :require => 'net/ssh'
gem 'database_cleaner'
gem 'looper'

# Server Deployment
gem 'passenger'
gem 'rvm', '~> 1.11.3.5'
gem 'net-ssh', '~> 2.5', :require => 'net/ssh'
gem 'thin'
gem 'foreman'
gem 'capistrano', '~> 2.14.2'
gem 'rvm-capistrano'
gem 'colored'

# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'turbo-sprockets-rails3'
  gem 'sass-rails',   '~> 3.2.3'
  gem 'compass-rails'
  gem 'coffee-rails', '~> 3.2.1'
  gem 'uglifier', '>= 1.0.3'
  gem 'jquery-ui-rails', '>= 4.0.4'
end

group :development do
  gem 'annotate', ">=2.5.0"
end

group :test do
  gem 'capybara'
  gem 'capybara-screenshot'
  gem 'selenium-webdriver'
  gem 'guard-rspec'
  gem 'launchy'
  gem 'faker'
end

group :test, :development do
  gem "rspec-rails"
  gem 'factory_girl_rails', :require => false
  gem 'rb-inotify'
end
