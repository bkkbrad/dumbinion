#!/usr/bin/env ruby

require 'optparse'
require 'rubygems'
require 'libarchive'
require 'log4r'

logger = Log4r::Logger.new 'extract_features'
logger.outputters << Log4r::Outputter.stdout 
logger.level = Log4r::INFO
options = {}
options[:cache] = "logs"

OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} [options]"

  opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
    logger.level = Log4r::DEBUG
  end
  opts.on("-c", "--cache DIR", String, "Log directory; default: '#{options[:cache]}' ") do |cache|
    options[:cache] = cache
  end
  opts.on_tail("-h", "--help", "Show this message") do
    puts opts
    exit
  end
end.parse!
    
Dir[File.join(options[:cache], "*.bz2")].sort.each do |file|
  if file =~ /\/(\d+)\.tar\.bz2$/
    Archive.read_open_filename(file) do |ar|
      logger.info file
      while entry = ar.next_header
        name = entry.pathname
        data = ar.read_data
        supply = []
        if data =~ /^cards in supply: (.*?)$/
          cards_desc = $1
          cards_desc.scan />([^<]*)<\/span>/ do |m|
            supply << m[0]
          end
        end
        
        logger.debug "#{name} (size=#{data.size})"
        logger.debug supply.inspect
        aborted = (data =~ /<b>game aborted:/)
        logger.debug "Aborted." if aborted
        logger.debug data if supply.empty? && !aborted
      end
    end
  end
end

