#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'

require 'optparse'
require 'rotp'

# require 'byebug'

# Set default parameters.
params = {config: '~/.otp.yml'}
o = OptionParser.new do |opts|
  opts.banner = 'Usage: otp [options] [SITE_NAME]'

  opts.on('-c', '--config FILE', 'Specify a .otp.yml file (Default: ~/.otp.yml)') { |v| params[:config] = v }
  opts.on('-C', '--copy', 'Copy code to clipboard') { |v| params[:copy] = v }
  opts.on('-b', '--base32', 'Create a random Base32 string') { |v| params[:base32] = v }
  opts.on('-l', '--list', 'Output a list of all available sites') { |v| params[:list] = v }
  opts.on('-q', '--qrcode', 'Create and output QR code') { |v| params[:qrcode] = v }
  opts.on('-Q', '--qrcode-out FILE', 'Save QR code to file') { |v| params[:qrcode_out] = v }
  opts.on('-I', '--qrcode-in FILE', 'Get OTP info from QR code image file (must be .png)') { |v| params[:qrcode_in] = v }
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
  puts 'Copied.'
end

if params[:base32]
  base32 = ROTP::Base32.random_base32
  puts base32
  copy_to_clipboard base32 if params[:copy]
  exit
end

if params[:qrcode_in]
  begin
    require 'qrio'

    qrcode_path = File.expand_path(params[:qrcode_in])
    otp_uri = URI(Qrio::Qr.load(qrcode_path).qr.text)

    unless 'otpauth' == otp_uri.scheme
      abort 'This is not an OTP auth QR code.'
    end

    unless 'totp' == otp_uri.host
      abort 'Only TOTP supported for now'
    end

    puts "uri: #{otp_uri}"

    otp_label = otp_uri.path[1..-1]
    puts "label: #{otp_label}"

    otp_label_parts = otp_label.split(':')
    if otp_label_parts.length == 2
      puts "label-issuer: #{otp_label_parts[0]}"
      puts "label-user: #{otp_label_parts[1]}"
    end

    # Print all query parameters.
    URI::decode_www_form(otp_uri.query).each { |k, v| puts "#{k}: #{v}" }

    copy_to_clipboard otp_uri if params[:copy]

  rescue
    abort 'Failed to read QR code.'
  end

  exit
end

config_path = File.expand_path(params[:config])
unless File.exists?(config_path)
  abort "#{config_path} not found."
end

begin
  require 'yaml'
  sites = YAML.load_file(config_path)['otp']
  raise unless sites
rescue
  abort "Incorrect format in config file #{config_path}."
end

if params[:list]
  sites.each { |site,| puts site }
  exit
end

if ARGV.length == 0
  abort 'You should give at least one site name.'
end

site_name = ARGV[0]
unless (site = sites[site_name])
  abort "Site \"#{site_name}\" not found in config file #{config_path}."
end

unless (site_secret = site['secret'])
  abort "Site \"#{site_name}\" has no secret defined."
end

# Remove any spaces.
site_secret.delete! ' '

# https://www.johnhawthorn.com/2009/10/qr-codes-on-the-command-line/
if params[:qrcode] || params[:qrcode_out]
  require 'rqrcode'

  site_issuer = site['issuer'] || site_name
  site_label = site_issuer
  if (site_username = site['username'])
    site_label += ':' + site_username
  end

  text = URI.escape("otpauth://totp/#{site_label}?secret=#{site_secret}&issuer=#{site_issuer}")
  # text = "asdf://totp/Cyon:armando@noplanman.ch?secret=LXIFXQ6HKEHU5ZQX&issuer=Cyon"

  # Make a QR code of the smallest possible size.
  qr = nil
  (1..10).each do |size|
    qr = RQRCode::QRCode.new(text, :level => :m, :size => size) rescue next
    break
  end

  # Save QR code as PNG image if needed.
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
puts res
copy_to_clipboard res if params[:copy]

exit
