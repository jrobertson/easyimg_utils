#!/usr/bin/env ruby

# file: easyimg_utils.rb

require 'c32'
require 'rxfhelper'
require 'rmagick'

# requirements:
#
# rmagick package dependencies:
# apt-get install imagemagick imagemagick-doc libmagickcore-dev libmagickwand-dev`
# 
# viewer:
# apt-get install feh



module CommandHelper
  using ColouredText
  
  def list(a=@commands)

    format_command = ->(s) do
      command, desc = s.split(/\s+#\s+/,2)
      " %s %s %s" % ['*'.blue, command, desc.to_s.light_black]
    end

    puts  a.map {|x| format_command.call(x) }.join("\n")
    
  end

  def search(s)
    list @commands.grep Regexp.new(s)
  end

end


class EasyImgUtils
  extend CommandHelper
  include Magick

@commands = "
* add_text # e.g. add_text('some text')
* blur # e.g. blur(x: 231, y: 123, w: 85, h: 85)
* crop # e.g. crop(x: 231, y: 123, w: 85, h: 85)
* info # returns the dimension of the image in a Hash object
* resize # set the maximum geomertry of the image for resizing e.g. resize('320x240')
* view # view the output
".strip.lines.map {|x| x[/(?<=\* ).*/]}.sort


  def initialize(img_in=nil, img_out=nil, out: img_out, 
                 working_dir: '/tmp')

    @file_in, @file_out, @working_dir = img_in, out, working_dir

  end
  
  def add_text(s='your text goes here', quality: nil)
    
    img = read()

    d = Draw.new
    img.annotate(d, 0,0,0,0, s) do
      d.gravity = Magick::SouthGravity
      d.pointsize = 26
      d.stroke = '#000000'
      d.fill = '#ffffff'
      d.font_weight = Magick::BoldWeight
    end
    
    write img, quality
    
  end
  
  def blur(x: 0, y: 0, w: 80, h: 80, strength: 8, quality: nil)
    
    width, height = w, h
    img = read()
    region = img.dispatch(x, y, width, height, 'RGB')
    face_img = Magick::Image.constitute(width, height, "RGB", region)
    img.composite!(face_img.gaussian_blur(0, strength), x, y, 
                   Magick::OverCompositeOp)
    write img, quality
    
  end
  
  def crop(x: 0, y: 0, w: nil, h: nil, quality: nil)
    
    return unless w
    
    img = read()
    img.crop!(x,y, width=w, height=h)
    write img, quality
    
  end
  
  def info()

    img = Magick::Image.ping( @file_in ).first
    {
      geometry: "%sx%s" % [img.columns, img.rows],
      mime_type: img.mime_type, format: img.format,
      quality: img.quality, filesize: img.filesize,
      filename: img.filename, created: img.properties
    }
    
  end

  # defines the maximum size of an image while maintaining aspect ratio
  #
  def resize(geometry='320x240', quality: nil)
    
    preview = read()
    
    preview.change_geometry!(geometry) do |cols, rows, img|
      img.resize!(cols, rows)
    end
    
    write img, quality
    
  end

  def view(show: true)
    
    return unless @file_out
    command = `feh #{@file_out}`
    run command, show
    
  end

  private
  
  def read()
    data, type = RXFHelper.read(@file_in)
    Magick::Image.from_blob(data).first
  end

  def run(command, show: false)

    if show then 
      command
    else
      puts "Using ->" + command
      system command
    end

  end  
  
  def write(img, quality=nil)
    
    return img.to_blob unless @file_out
    
    img.write @file_out do
      self.quality = quality if quality
    end    
  end

end
