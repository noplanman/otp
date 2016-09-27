#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'

require 'optparse'
require 'rotp'
require 'colorize'

# require 'byebug'

# Set default parameters.
params = {config: '~/.otp.yml', color: true}
o = OptionParser.new do |opts|
  opts.banner = 'Usage: otp [options] [SITE_NAME]'

  opts.on('-c', '--config', 'Specify a .otp.yml file (Default: ~/.otp.yml)') { |v| params[:config] = v }
  opts.on('-b', '--base32', 'Create a random Base32 string') { |v| params[:base32] = v }
  opts.on('-l', '--list', 'Output a list of all available sites') { |v| params[:list] = v }
  opts.on('-p', '--no-color', 'Output plain code without color') { |v| params[:color] = v }
  opts.on('-o', '--copy', 'Copy code to clipboard') { |v| params[:copy] = v }
  opts.on('-q', '--qrcode', 'Create and output QR code') { |v| params[:qrcode] = v }
  opts.on('--qrcode-out FILE', 'Save QR code to file') { |v| params[:qrcode_out] = v }
  opts.on('-h', '--help', 'Display this screen') { puts opts; exit; }
end

# Handle invalid params nicely.
begin
  o.parse! ARGV
rescue OptionParser::ParseError => e
  puts e
  puts o
  abort
end

def copy_to_clipboard(input)
  copy_command = (/darwin/ =~ RUBY_PLATFORM) != nil ? 'pbcopy' : 'xclip'
  IO.popen(copy_command, 'w') { |f| f << input.to_s }
  puts 'Copied.'.green
end

if params[:base32]
  base32 = ROTP::Base32.random_base32
  puts params[:color] ? base32.yellow : base32
  copy_to_clipboard base32 if params[:copy]
  exit
end

config_path = File.expand_path(params[:config])
unless File.exists?(config_path)
  puts "#{config_path} not found.".red
  abort
end

begin
  require 'yaml'
  sites = YAML.load_file(config_path)['otp']
  raise unless sites
rescue
  puts "Incorrect format in config file #{config_path}.".red
  abort
end

if params[:list]
  sites.each { |site,| puts site }
  exit
end

if ARGV.length == 0
  puts 'You should give at least one site name.'.red
  abort
end

site_name = ARGV[0]
unless (site = sites[site_name])
  puts "Site \"#{site_name}\" not found in config file #{config_path}.".red
  abort
end

unless (site_secret = site['secret'])
  puts "Site \"#{site_name}\" has no secret defined.".red
  abort
end

# Remove any spaces.
site_secret.delete! ' '
site_username = site['username'] || ''
site_issuer = site['issuer'] || ''

# https://www.johnhawthorn.com/2009/10/qr-codes-on-the-command-line/
if params[:qrcode] || params[:qrcode_out]
  require 'rqrcode'

  text = URI.escape("otpauth://totp/#{site_issuer}:#{site_username}?secret=#{site_secret}&issuer=#{site_issuer}")

  # Make a QR code of the smallest possible size.
  qr = nil
  (1..10).each do |size|
    qr = RQRCode::QRCode.new(text, :level => 'l', :size => size) rescue next
    break
  end

  # Save QR code as PNG image.
  qr.as_png({:file => params[:qrcode_out], :border_modules => 1}) if params[:qrcode_out]

  # Output the QR code.
  if params[:qrcode]
    SPACER = '  '
    BLACK = "\e[40m"
    WHITE = "\e[107m"
    DEFAULT = "\e[49m"

    width = qr.modules.length

    puts WHITE + SPACER * (width + 2) + BLACK

    width.times do |x|
      print WHITE + SPACER
      width.times do |y|
        print (qr.is_dark(x, y) ? BLACK : WHITE) + SPACER
      end
      puts WHITE + SPACER + DEFAULT
    end

    puts WHITE + SPACER * (width + 2) + BLACK
  end
end

# Output OTP code.
res = ROTP::TOTP.new(site_secret).now
puts params[:color] ? res.yellow : res

copy_to_clipboard res if params[:copy]

exit
