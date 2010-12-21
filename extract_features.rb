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

$card_names = {}
File.open("card_names.txt", "r") do |f|
  while f.gets
    parts = $_.chomp.split(/\t/)
    parts.each { |x| $card_names[x] = parts[0] }
  end
end

def make_hand(text)
  hand = {}
  text.scan /(\w+) <span class=[^>]*>([^<]*)<\/span>/ do |n|
    count = (n[0] == "an" || n[0] == "a" ? "1" : n[0]).to_i 
    hand[$card_names[n[1]]] = count
  end
  hand
end

def money(hand)
  res = 0
  [["Copper", 1], ["Silver",2], ["Gold",3]].each do |pair|
    res += (hand[pair[0]] || 0) * pair[1]
  end
  res
end

qid = 0
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
        
        users = Hash.new {|h,k| h[k] = [] }
        has_points = false
        data.scan /^<b>(.*?):\s*(\d+)\s*points?<\/b>/ do |m|
          has_points = true
          user = m[0]
          points = m[1]
          users[user] << "points:#{m[1]}"
        end
        if !has_points
          #puts "Skip!"
          #puts
          next
          #skip for not complete
        end

        data.scan /<span class=logonly>\((.*?)'s first hand: (.*)\)<\/span>\s*$/ do |m|
          user = m[0]
          hand = make_hand(m[1])
          users[user] << money(hand)
        end

        user = nil
        turn = nil
        data.each_line do |line|
          if line =~ /\A\s*--- (.*)'s turn (\d+) ---\Z/
            user = $1 
            turn =  $2
            break if turn == "3"
          end
          if line =~ /\A\s*.* buys .*? <span [^>]*>(.*)<\/span>.\s*\Z/
            users[user] << "buy:#{$1.gsub(/\s/, '_')}"
          end
          if line =~ /\A\s*<span class=logonly>\(.*\sdraws:\s(.*?)\)<\/span>\s*\Z/
            hand = make_hand($1)
            users[user] << money(hand) unless turn == "2"
          end
        end
        supply.map! {|x| x.gsub(/\s/, '_')}
        if users.keys.size <= 1
          #puts "Skip! Solitaire"
          #puts
          next
        end
        logger.debug "***#{users.inspect}" if users.size > 0

        logger.debug "#{name} (size=#{data.size})"
        logger.debug supply.inspect
        aborted = (data =~ /<b>game aborted:/)
        logger.debug "Aborted." if aborted
        #logger.debug data if supply.empty? && !aborted
        #
        if !supply.empty? && !aborted && users.values.all? { |x| x.length == 5} 
          users.keys.each do |user|
            points = users[user][0]
            puts ([points.gsub(/^points:/, ''), "qid:#{qid}", users[user].map{|x| x.to_s}.sort.select {|x| x =~ /^buy:/}] + supply).join(" ")
          end
          qid += 1
        end
      end
    end
  end
end
