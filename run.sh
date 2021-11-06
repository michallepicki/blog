#!/usr/bin/env bash
rm Gemfile
rm Gemfile.lock
echo "gem 'github-pages'" > Gemfile
bundle install
bundle exec jekyll serve --livereload --port 4001
