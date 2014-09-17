# ruby-mp3info

* http://github.com/moumar/ruby-mp3info

[![Build Status](https://travis-ci.org/moumar/ruby-mp3info.png?branch=master)](https://travis-ci.org/moumar/ruby-mp3info)

## Description

ruby-mp3info read low-level informations and manipulate tags on mp3 files.

## Features/Problems

* Written in pure ruby
* Read low-level informations like bitrate, length, samplerate, etc...
* Read, write, remove id3v1 and id3v2 tags
* Correctly read VBR files (with or without Xing header)
* Only 2.3 version is supported for writings id3v2 tags
* id3v2 tags are always written in UTF-16 encoding

## Synopsis

```ruby
require "mp3info"

# Read and display infos & tags

Mp3Info.open("myfile.mp3") do |mp3info|
  puts mp3info
end

# read/write tag1 and tag2 with Mp3Info#tag attribute
# when reading tag2 have priority over tag1
# when writing, each tag is written.

Mp3Info.open("myfile.mp3") do |mp3|
  puts mp3.tag.title
  puts mp3.tag.artist
  puts mp3.tag.album
  puts mp3.tag.tracknum
  mp3.tag.title = "track title"
  mp3.tag.artist = "artist name"
end

# tags are written when calling Mp3Info#close or at the end of the #open block

### access id3v2 tags

Mp3Info.open("myfile.mp3") do |mp3|
  # you can access four letter v2 tags like this
  puts mp3.tag2.TIT2
  mp3.tag2.TIT2 = "new TIT2"
  # or like that
  mp3.tag2["TIT2"]
  # at this time, only COMM tag is processed after reading and before writing
  # according to ID3v2#options hash
  mp3.tag2.options[:lang] = "FRE"
  mp3.tag2.COMM = "my comment in french, correctly handled when reading and writing"
end

### image manipulation

file = File.new('input_img','rb')
Mp3Info.open '1.mp3' do |m|
   pictures = m.tag2.pictures # array of images :
   pictures.each do |description, data|
      # description ends with (.jpg / .png) for easy writing to file
      File.binwrite(description, data)
  end
  m.tag2.remove_pictures # remove all images

  m.tag2.add_picture(file.read) # add a single image to APIC tag
  # **optionally**, you may include options for the image tag to add_picture():
  # options = { mime: 'jpeg|gif|png', description: "description",
  #             pic_type: 0 }
  # There is no need to specify mime or options because the mime is guessed based on the input image
  # Only one image is permitted in the mp3 for compatibility. add_picture() overwrites all previous images.
  # Please note:
  # If supplying :mime option just supply the mime 'jpeg', 'gif' or 'png', the code adds the "image/.." for you!
  # e.g. m.tag2.add_picture(file.read, mime: 'jpeg', pic_type: 3) gets a mime "image/jpeg"
end
```

## Requirements

* iconv when using ruby 1.8

## Install

    gem install ruby-mp3info

## Developers

After checking out the source, run:

    $ rake newb

This task will install any missing dependencies, run the tests/specs, and generate the RDoc.

## License

GPL-3.0

## TODO:

* encoder detection
* support for more tags in id3v2
* generalize id3v2 with other audio formats (APE, MPC, OGG, etc...)
