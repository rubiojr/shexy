# encoding: utf-8

require 'rubygems'
require 'bundler'
require './lib/shexy.rb'

begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.version = Shexy::VERSION
  gem.name = "shexy"
  gem.homepage = "http://rubiojr.github.com/shexy"
  gem.license = "MIT"
  gem.summary = %Q{SSH, the way I like it}
  gem.description = %Q{[extremely] thin wrapper around net-ssh and net-scp}
  gem.email = "rubiojr@frameos.org"
  gem.authors = ["Sergio Rubio"]
  # dependencies defined in Gemfile
end
Jeweler::RubygemsDotOrgTasks.new

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

task :default => :build

require 'rdoc/task'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "shexy #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
