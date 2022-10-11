#!/usr/bin/env bash
# rm Gemfile
# rm Gemfile.lock
# echo -e "source \"https://rubygems.org\"\ngem 'github-pages'" > Gemfile
# bundle install
bundle exec jekyll serve --livereload --drafts --future --port 4001 --host 0.0.0.0
