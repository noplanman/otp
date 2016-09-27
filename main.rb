#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'

require 'optparse'
require 'rotp'
require 'colorize'
# require 'byebug'

# Set default parameters.
params = {
    :config => '~/.otp.yml',
    :color  => true
}
OptionParser.new do |opts|
  opts.banner = 'Usage: otp [options] SITE_NAME'

  opts.on('-c', '--config', 'Specify a .otp.yml file (Default: ~/.otp.yml)') { |v| params[:config] = v }
  opts.on('-b', '--base32', 'Create a random Base32 string') { |v| params[:base32] = v }
  opts.on('-p', '--no-color', 'Output plain code without color') { |v| params[:color] = v }
  opts.on('-o', '--copy', 'Copy code to clipboard') { |v| params[:copy] = v }
  opts.on('-h', '--help', 'Display this screen') { puts opts; exit; }
end.parse!

def copy_to_clipboard(input)
  str          = input.to_s
  copy_command = (/darwin/ =~ RUBY_PLATFORM) != nil ? 'pbcopy' : 'xclip'
  IO.popen(copy_command, 'w') { |f| f << str }
  puts 'Copied.'.green
  str
end

if params[:base32]
  base32 = ROTP::Base32.random_base32
  puts params[:color] ? base32.yellow : base32
  copy_to_clipboard base32 if params[:copy]
  exit
end

config_path = File.expand_path(params[:config])
unless File.exists?(config_path)
  puts "#{config_path} not found.\nExit now.".red
  abort
end

begin
  require 'yaml'
  setting = YAML.load_file(config_path)['otp']
  raise unless setting
rescue
  puts "Incorrect config file format. (#{config_path})".red
  abort
end

if ARGV.length == 0
  puts 'You should give at least one keyword.'.red
  abort
end

unless (secret = setting[ARGV[0]])
  puts "Keyword \"#{ARGV[0]}\" not found in config file #{config_path}.".red
  abort
end

res = ROTP::TOTP.new(secret).now
puts params[:color] ? res.yellow : res

copy_to_clipboard res if params[:copy]

exit
