#!/usr/bin/env ruby

$:.unshift("lib/")

require 'mp3info'
require 'benchmark'

mp3_file = ARGV.shift

SIZE = 2_000
runner = proc { |parse_mp3| Mp3Info.open(mp3_file, :parse_tags => true, :parse_mp3 => parse_mp3) }

Benchmark.bmbm do |b|
  b.report('tags parse') { SIZE.times { runner.call(false) } }
  b.report('full parse') { SIZE.times { runner.call(true) } }
end
