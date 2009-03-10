#!/usr/bin/env ruby

$:.unshift(File.dirname(__FILE__) + "/../lib")

require "mp3info"

ARGV.each do |arg|
  begin
    Mp3Info.open(arg) { |mp3| }
  rescue Mp3InfoError, ID3v2Error
  end
end
