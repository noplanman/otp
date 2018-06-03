#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'

require 'optparse'
require 'rotp'

# Set default parameters.
params = { config: '~/.otp.yml' }
o = OptionParser.new do |opts|
  opts.banner = 'Usage: otp [options] [SITE_NAME]'

  opts.on('-c', '--config FILE', 'Specify a .otp.yml file (Default: ~/.otp.yml)') { |v| params[:config] = v }
  opts.on('-C', '--copy', 'Copy code to clipboard') { |v| params[:copy] = v }
  opts.on('-b', '--base32', 'Create a random Base32 string') { |v| params[:base32] = v }
  opts.on('-l', '--list', 'Output a list of all available sites') { |v| params[:list] = v }
  opts.on('-a', '--add', 'Add a new site') { |v| params[:add] = v }
  opts.on('-d', '--delete', 'Delete an existing site') { |v| params[:delete] = v }
  opts.on('-r', '--recovery', 'Get one of the recovery keys (random)') { |v| params[:recovery] = v }
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
  copy_command = (/darwin/ =~ RUBY_PLATFORM).nil? ? 'xclip' : 'pbcopy'
  IO.popen(copy_command, 'w') { |f| f << input.to_s }
  puts 'Copied.'
end

if params[:base32]
  puts base32 = ROTP::Base32.random_base32.upcase
  copy_to_clipboard base32 if params[:copy]
  exit
end

if params[:qrcode_in]
  begin
    require 'qrio'

    qrcode_path = File.expand_path(params[:qrcode_in])
    otp_uri = URI(Qrio::Qr.load(qrcode_path).qr.text)

    abort 'This is not an OTP auth QR code.' unless otp_uri.scheme == 'otpauth'
    abort 'Only TOTP supported for now' unless otp_uri.host == 'totp'

    puts "uri: #{otp_uri}"

    otp_label = otp_uri.path[1..-1]
    puts "label: #{otp_label}"

    otp_label_parts = otp_label.split(':')
    if otp_label_parts.length == 2
      puts "label-issuer: #{otp_label_parts[0]}"
      puts "label-user: #{otp_label_parts[1]}"
    end

    # Print all query parameters.
    URI.decode_www_form(otp_uri.query).each { |k, v| puts "#{k}: #{v}" }

    copy_to_clipboard otp_uri if params[:copy]
  rescue StandardError
    abort 'Failed to read QR code.'
  end

  exit
end

config_path = File.expand_path(params[:config])

require 'highline/import'
require 'yaml'

unless File.exist?(config_path)
  exit unless agree("<%= color(\"'#{config_path}' not found. Create it? \", :yellow) %>", true)
  File.write(config_path, { 'otp' => {} }.to_yaml, perm: 0o600)
end

begin
  otp_config = YAML.load_file(config_path)

  sites = otp_config['otp']
  raise unless sites
rescue StandardError
  abort "Incorrect format in config file '#{config_path}'."
end

if params[:add] || (!sites.empty? && params[:delete])
  site_name = ask('Site name *: ', params[:add] ? ->(sn) { sn.strip.gsub(/\s/, '_')} : nil) do |s|
    s.readline = true
    s.completion = sites.keys unless sites.empty?
    s.validate = /\A[\w\s]+\Z/
    s.responses[:not_valid] = 'Site name required (A-z, 0-9, _)'
  end

  if params[:delete]
    exit unless agree('<%= color("Are you sure? ", :yellow) %>', true)

    begin
      sites_deleted = []
      site_name.split(' ').uniq.each do |sn|
        sites_deleted << sn if sites.delete(sn)
      end

      File.write(config_path, otp_config.to_yaml)
      say("<%= color(\"Deleted '#{sites_deleted.join(', ')}'\", [:red, :bold]) %>")
    rescue StandardError => e
      say("<%= color('#{e.message}', [:red, :bold]) %>")
      abort
    end

    exit
  end

  if sites.include?(site_name)
    exit unless agree("<%= color(\"Site '#{site_name}' exists! Overwrite? \", :yellow) %>", true)
  end

  new_site = {
    'secret' => ask('Secret *: ') do |s|
      s.case = :up
      s.whitespace = :remove
      s.validate = /\A[A-Za-z2-7]+\Z/
      s.responses[:not_valid] = 'Secret must be a Base32 string (A-Z, 2-7)'
    end,
    'issuer' => ask('Issuer *: ') do |i|
      i.default = site_name
      i.whitespace = :strip_and_collapse
      i.validate = /\A[\w\s]+\Z/
      i.responses[:not_valid] = 'Issuer name invalid (A-z, 0-9, _)'
    end,
    'username' => ask('Username: '),
    'recovery_keys' => ask('Recovery keys (end with blank line):') do |rk|
      rk.gather = ''
    end
  }

  # Some cleanup for empty parameters.
  new_site.delete('username') if new_site['username'].empty?
  new_site.delete('recovery_keys') if new_site['recovery_keys'].empty?

  sites[site_name] = new_site

  begin
    File.write(config_path, otp_config.to_yaml)
    say("<%= color(\"Added '#{site_name}'\", [:green, :bold]) %>")
  rescue StandardError => e
    say("<%= color('#{e.message}', [:red, :bold]) %>")
    abort
  end

  exit
end

if sites.empty?
  say('No sites defined. Use \'<%= color("otp -a", :bold) %>\' to add a new one.')
  exit
end

if params[:list]
  puts sites.keys
  exit
end

abort 'You should give at least one site name.' if ARGV.empty?

site_name = ARGV[0]
unless (site = sites[site_name])
  abort "Site '#{site_name}' not found in config file '#{config_path}'."
end

unless (site_secret = site['secret'])
  abort "Site '#{site_name}' has no secret defined."
end

# Remove any unnecessary spaces from secret.
site_secret.delete! ' '

# Fetch a recovery key if requested.
if params[:recovery]
  unless (recovery_keys = site['recovery_keys'])
    abort "Site '#{site_name}' has no recovery keys defined."
  end

  recovery_key = ''
  recovery_key = recovery_keys if recovery_keys.is_a? String
  recovery_key = recovery_keys.sample if recovery_keys.is_a? Array

  puts recovery_keys
  copy_to_clipboard recovery_key if params[:copy]

  exit
end

# https://www.johnhawthorn.com/2009/10/qr-codes-on-the-command-line/
if params[:qrcode] || params[:qrcode_out]
  require 'rqrcode'

  site_issuer = site['issuer'] || site_name
  site_label = site_issuer
  if (site_username = site['username'])
    site_label += ':' + site_username
  end

  text = URI.escape("otpauth://totp/#{site_label}?secret=#{site_secret}&issuer=#{site_issuer}")

  # Make a QR code of the smallest possible size.
  qr = nil
  (1..10).each do |size|
    begin
      qr = RQRCode::QRCode.new(text, level: :m, size: size)
    rescue StandardError
      next
    end
    break
  end

  # Save QR code as PNG image if needed.
  qr.as_png(file: params[:qrcode_out], border_modules: 1) if params[:qrcode_out]

  # Output the QR code.
  if params[:qrcode]
    SPACER = '  '.freeze
    BLACK = "\e[40m".freeze
    WHITE = "\e[107m".freeze
    DEFAULT = "\e[49m".freeze

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
puts res = ROTP::TOTP.new(site_secret).now
copy_to_clipboard res if params[:copy]

exit
