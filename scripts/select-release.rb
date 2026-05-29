#!/usr/bin/env ruby

require "json"
require "open3"
require "optparse"
require "time"

options = {
  assets: {},
}

parser = OptionParser.new do |opts|
  opts.banner = <<~BANNER
    Usage: select-release.rb --repo REPO --min-age-days DAYS [--asset VAR=NAME]... [--help]

    Select the latest non-draft, non-prerelease GitHub release that is at least the requested age.
  BANNER

  opts.on("--repo REPO") { |value| options[:repo] = value }
  opts.on("--min-age-days DAYS", Integer) { |value| options[:min_age_days] = value }
  opts.on("--asset VAR=NAME") do |value|
    key, name = value.split("=", 2)
    abort "--asset must be in VAR=NAME format" if key.to_s.empty? || name.to_s.empty?
    abort "Invalid asset variable name: #{key}" unless key.match?(/\A[A-Z][A-Z0-9_]*\z/)

    options[:assets][key] = name
  end
  opts.on("-h", "--help", "Show this help message and exit") do
    puts opts
    exit 0
  end
end

parser.parse!(ARGV)

abort "Missing --repo" unless options[:repo]
abort "Missing --min-age-days" unless options.key?(:min_age_days)

repo = options[:repo]
min_age_days = options[:min_age_days]
required_assets = options[:assets]
now = Time.now.utc

selected_release = nil
selected_age_days = nil
page = 1

loop do
  api = "https://api.github.com/repos/#{repo}/releases?per_page=100&page=#{page}"
  stdout, status = Open3.capture2("curl", "-fsSL", api)
  abort "Failed to fetch #{api}" unless status.success?

  releases = JSON.parse(stdout)
  break if releases.empty?

  selected_release = releases.find do |candidate|
    next false if candidate["draft"] || candidate["prerelease"]

    published_at = candidate["published_at"]
    next false unless published_at

    age_days = ((now - Time.iso8601(published_at)) / 86_400).floor
    next false if age_days < min_age_days

    selected_age_days = age_days
    true
  end

  break if selected_release

  page += 1
end

unless selected_release
  puts 'FOUND=false'
  puts 'LATEST=""'
  puts 'PUBLISHED_AT=""'
  puts 'AGE_DAYS=""'
  exit 0
end

assets = selected_release.fetch("assets").to_h do |asset|
  digest = asset["digest"].to_s.sub(/^sha256:/, "")
  [asset.fetch("name"), digest]
end

missing_assets = required_assets.values.reject do |name|
  digest = assets[name]
  digest && !digest.empty?
end
abort "Missing release assets: #{missing_assets.join(", ")}" unless missing_assets.empty?

puts 'FOUND=true'
puts "LATEST=#{selected_release.fetch("tag_name").sub(/^v/, "").dump}"
puts "PUBLISHED_AT=#{selected_release.fetch("published_at").dump}"
puts "AGE_DAYS=#{selected_age_days}"

required_assets.each do |key, name|
  puts "#{key}=#{assets.fetch(name).dump}"
end
