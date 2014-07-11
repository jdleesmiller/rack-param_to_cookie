require 'rubygems'
require 'bundler/setup'
require 'gemma'

Gemma::RakeTasks.with_gemspec_file 'rack_param_to_cookie.gemspec'

task :default => :test
