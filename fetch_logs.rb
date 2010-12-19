#!/usr/bin/env ruby

require 'optparse'
require 'date'
require 'net/http'
options = {}
options[:cache] = "logs"
options[:end_date] = Date.today - 1

OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} [options]"

  opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
    options[:verbose] = v
  end
  opts.on("-s", "--start DATE", String, "Initial log to fetch; default: day after last log in cache") do |start_date|
    options[:start_date] = Date.parse(start_date)
  end
  opts.on("-e", "--end DATE", String, "Last log to fetch; default: #{options[:end_date]}") do |end_date|
    options[:end_date] = Date.parse(end_date)
  end
  opts.on("-c", "--cache DIR", String, "Log directory; default: '#{options[:cache]}' ") do |cache|
    options[:cache] = cache
  end
  opts.on_tail("-h", "--help", "Show this message") do
    puts opts
    exit
  end
end.parse!

max_date = Date.parse("2010-10-10")
Dir[File.join(options[:cache], "*.bz2")].each do |file|
  if file =~ /\/(\d+)\.tar\.bz2$/
    max_date = [Date.parse($1), max_date].max
  end
end
options[:start_date] ||= max_date.next

Net::HTTP.start("dominion.isotropic.org") do |http|
  options[:start_date].upto(options[:end_date]) do |date|
    remote_file = "/gamelog/#{date.strftime("%Y%m/%d")}/all.tar.bz2"
    local_file = File.join(options[:cache], "#{date.strftime("%Y%m%d")}.tar.bz2")
    
    if options[:verbose]
      puts date.to_s
      puts "#{remote_file} => #{local_file}"
    end
    
    resp = http.get(remote_file)
    open(local_file, "wb") do |file|
      file.write(resp.body)
    end
  end
end

# Format: http://dominion.isotropic.org/gamelog/201010/11/all.tar.b2
