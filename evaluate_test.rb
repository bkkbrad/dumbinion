#!/usr/bin/env ruby

require 'optparse'
require 'rubygems'
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
  opts.on("-t", "--test FILE", String, "Test file.") do |test|
    options[:test] = test
  end
  opts.on("-s", "--supply CARDS", String, "Description of cards.") do |supply|
    options[:supply] = supply
  end
  opts.on("-m", "--model FILE", String, "Model file.") do |model|
    options[:model] = model
  end
  opts.on_tail("-h", "--help", "Show this message") do
    puts opts
    exit
  end
end.parse!

[:model].each do |t|
  unless options[t]
    STDERR.puts "Please specify #{t} file."
    exit
  end
end

unless options[:test] || options[:supply]
  STDERR.puts "Please specify test file or supply."
  exit
end

def kernel(a, b)
  len = (a & b).length
  if $kernel_type == :subset
    return 2 ** len
  else
    return len ** $power
  end
end

$kernel_type = :polynomial
$power = 2

support = Hash.new { |h,k| h[k] = [] }
File.open(options[:model], 'r') do |f|
  while f.gets
    $_.chomp!

    if $_ =~ /\Asubsets# kernel parameter -u\s*\Z/
      $kernel_type = :subset
    end
    if $_ =~ /\A\s*(\d+)\s*# kernel parameter -d\s*\Z/
      $power = $1.to_i
    end

    if $_ =~ /buy:/
      parts = $_.split(/#/)
      weight = parts[0].to_f
      buy = []
      supply = []
      parts[1].strip.split(/\s+/).each do |c|
        (c =~ /\Abuy:/ ? buy : supply) << c
      end
      support[buy] << [weight, supply]
    end
  end
end

def process_group(group, support)
  ranking = group.map do |line|
    parts = line.split(/#/).map {|x| x.strip}
    score = parts[0].split(/\s+/)[0].to_i
    buy = []
    supply = []
    parts[1].strip.split(/\s+/).each do |c|
      (c =~ /\Abuy:/ ? buy : supply) << c
    end
    new_score = support[buy].reduce(0) do |sum, pair|
      sum + pair[0] * kernel(pair[1], supply)
    end
    [new_score, score, buy]
  end

  ranking = ranking.sort_by { |r| -r[0] }
  best = ranking[0]
  ranking.all? do |r|
    (best[1] > r[1]) || (best[2] == r[2]) #either better score or buy the same thing
  end
end

if options[:test]
  total_groups = 0
  correct_groups = 0
  group = nil
  qid = nil
  File.open(options[:test], 'r') do |f|
    while f.gets
      $_.chomp!
      if $_ =~ /qid:(\d+)/
        new_qid = $1.to_i
        if new_qid == qid
          group << $_
          next
        else
          correct_groups += 1 if qid && process_group(group, support)
          group = [$_]
          total_groups += 1
        end
        qid = new_qid
      end
    end
  end
  unless group && group.empty?
    correct_groups += 1 if qid && process_group(group, support) 
  end

  puts "Accuracy: #{correct_groups}/#{total_groups} = #{correct_groups.to_f / total_groups}"
end

if options[:supply]
  puts "Supply: #{options[:supply]}"
  supply = options[:supply].gsub(/\sand\s/, ' ').split(',').map { |x| x.strip.gsub(/\s+/, '_') }.sort
  buy_supply = (supply + ["Copper", "Silver", "Curse", "Estate"]).map { |x| "buy:" + x }.sort
  ranking = []
  (0...buy_supply.length).each do |i|
    (i...buy_supply.length).each do |j|
      buy = [buy_supply[i], buy_supply[j]]
      new_score = support[buy].reduce(0) do |sum, pair|
        sum + pair[0] * kernel(pair[1], supply)
      end
      ranking << [new_score, buy]
    end
  end
  ranking = ranking.sort_by { |pair| pair[0] }
  ranking.each do |pair|
    puts pair.join("\t")
  end
end
