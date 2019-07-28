#!/usr/bin/env ruby

# file: easyimg_utils.rb

require 'c32'
require 'rxfhelper'
require 'rmagick'
require 'webp_ffi'

# requirements:
#
# rmagick package dependencies:
# apt-get install imagemagick imagemagick-doc libmagickcore-dev libmagickwand-dev`
# 
# viewer:
# apt-get install feh
#
# webp-ffi dependencies
# apt-get install libjpeg-dev libpng-dev libtiff-dev libwebp-dev
#



module CommandHelper
  using ColouredText
  
  def list(a=@commands)

    format_command = ->(s) do
      command, desc = s.split(/\s+#\s+/,2)
      " %s %s %s" % ['*'.blue, command, desc.to_s.light_black]
    end

    puts a.map(&format_command).join("\n")
    
  end

  def search(s)
    list @commands.grep Regexp.new(s.to_s)
  end

end


class EasyImgUtils
  extend CommandHelper
  include Magick

@commands = "
* add rectangle # usage: add_rectangle(color: 'green', x1: 12, y1: 12, x2: 24, y2: 24)
* add_svg # adds an SVG transparency overlay. usage: add_svg('/tmp/image1.svg')
* add_text # e.g. add_text('some text')
* blur # e.g. blur(x: 231, y: 123, w: 85, h: 85)
* capture_screen # takes a screenshot of the desktop
* center_crop # crops from the centre of an image. Usage center_crop(width, height)
* composite # overlay a smaller image on top of an image
* contrast # changes the intensity between lighter and darker elements
* convert # convert from 1 img format to another
* crop # e.g. crop(x: 231, y: 123, w: 85, h: 85)
* fax_effect # Produces a high-contrast, two colour image
* greyscale # Reduces the image to 256 shades of grey
* info # returns the dimension of the image in a Hash object
* make_thumbnail # similar to resize but faster for sizes less than 10% of original image 
* resize # set the maximum geomertry of the image for resizing e.g. resize('320x240')
* rotate
* rotate_180
* rotate_left
* rotate_right
* sketch # renders an artistic sketch, ideal with simplistic photos
* view # view the output
* vignette # Feathers the edge of an image in a circular path
".strip.lines.map {|x| x[/(?<=\* ).*/]}.sort


  def initialize(img_in=nil, img_out=nil, out: img_out, 
                 working_dir: '/tmp', debug: false)

    @file_in, @file_out, @working_dir = img_in, out, working_dir    
    @debug = debug

  end
  
  def add_rectangle(a=[], quality: nil, color: 'green', stroke_width: 5, 
                    x1: 0, y1: 0, x2: 0, y2: 0)
    
    x1, y1, x2, y2 = *a if a
    img = read()
    gc = Magick::Draw.new
    gc.stroke('green')
    gc.stroke_width(5)
    gc.fill('transparent')
    gc.rectangle(x1, y1, x2, y2)
    gc.draw(img)
    write img, quality
    
  end
    
  def add_svg(svg_file)

    img = Magick::ImageList.new
    img.read(@file_in)
    
    img.read(svg_file) do
        self.format = 'SVG'
        self.background_color = 'transparent'
    end
    
    img.flatten_images.write @file_out
    
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
  
  def brightness(quality: nil)
    img = read()
    img2 = imglevel(-Magick::QuantumRange * 0.25, Magick::QuantumRange * 1.25, 1.0)
    write img2, quality
  end
  
  def capture_screen(quality: nil)
    
    # defaults (silent=false, frame=false, descend=false, 
    #           screen=false, borders=false)
    
    img = Magick::Image.capture(true, false, false, true, true) {
      self.filename = "root"
    }
    write img, quality
    
  end

  def center_crop(w=0, h=0, width: w, height: h, quality: nil)
    
    return unless w
    
    img = read()
    img.crop!(CenterGravity, width, height)
    write img, quality    
    
  end
  
  def composite(filex=nil, x: 0, y: 0, quality: nil)
    
    return unless filex
    
    img = read()
        
    imgx = Magick::ImageList.new(filex)

    # Change the white pixels in the sign to transparent.
    imgx = imgx.matte_replace(0,0)

    img2 = Magick::Draw.new
    img2.composite(x, y, 0, 0, imgx)
    img2.draw(img)    
    
    write img, quality        
    
  end
  
  alias overlay composite
  alias add_img composite
  
  # contrast level 
  # 1 low -> 10 high
  #
  def contrast(level=5)
    
    neutral = 5
    
    return if level == neutral
        
    img ||= read()
            
    n = neutral - level
    sharpen  = n > 0 
    n.abs.times { img = img.contrast(sharpen) }
    
    write img, quality
    
  end
  
  def convert(quality: nil)
    
    if File.extname(@file_in) == '.webp' then      
      
      # output_format options: pam, ppm, pgm, bmp, tiff or yuv
      ext = File.extname(@file_out)[1..-1].to_sym
      puts 'ext: ' + ext.inspect if @debug
      
      if ext == :jpg then
        
        file_out = @file_out.sub(/\.jpg$/,'.png')
        WebP.decode(@file_in, file_out, output_format: :png)
        img = read(file_out)
        write img, quality
        
      else
      
        WebP.decode(@file_in, @file_out, output_format: ext)
      end
      
    else
      img = read()
      write img, quality
    end
    
  end     
  
  def crop(x: 0, y: 0, w: nil, h: nil, quality: nil)
    
    return unless w
    
    img = read()
    img.crop!(x,y, width=w, height=h)
    write img, quality
    
  end
  
  def fax_effect(threshold: 0.55, quality: nil)

    img = read()
    
    # Use a threshold of 55% of MaxRGB.
    img = img.threshold(Magick::MaxRGB*threshold)
    
    write img, quality
    
  end
  
  def greyscale(quality: nil)
    
    img = read()
    img2 = img.quantize(256, GRAYColorspace)
    write img2, quality
    
  end
  
  alias grayscale greyscale
  
  def info()

    img = Magick::Image.ping( @file_in ).first
    {
      geometry: "%sx%s" % [img.columns, img.rows],
      mime_type: img.mime_type, format: img.format,
      quality: img.quality, filesize: img.filesize,
      filename: img.filename, created: img.properties
    }
    
  end
  
  def make_thumbnail(width=125, height=125)
    
    img = read()
    img2 = img.thumbnail(width, height)
    write img2, quality    
    
  end
  
  alias thumbnail make_thumbnail

  # defines the maximum size of an image while maintaining aspect ratio
  #
  def resize(geometry='320x240', quality: nil)
    
    preview = read()
    
    preview.change_geometry!(geometry) do |cols, rows, img|
      img.resize!(cols, rows)
    end
    
    write preview, quality
    
  end
  
  def rotate(degrees)
    
    img = read()
    img2 = img.rotate(degrees.to_i)
    write img2, quality    
    
  end

  def rotate_180()
    
    img = read()
    img2 = img.rotate(180)
    write img2, quality    
    
  end    
  
  def rotate_left()
    
    img = read()
    img2 = img.rotate(-45)
    write img2, quality    
    
  end    
  
  def rotate_right()
    
    img = read()
    img2 = img.rotate(45)
    write img2, quality    
    
  end  
    
  
  def sketch(quality: nil)
    
    img = read()

    # Convert to grayscale
    sketch = img.quantize(256, Magick::GRAYColorspace)

    # Apply histogram equalization
    sketch = sketch.equalize

    sketch = sketch.sketch(0, 10, 135)
    img = img.dissolve(sketch, 0.75, 0.25)

    write img, quality
    
  end
  
  alias drawing sketch

  def view(show: true)
    
    return unless @file_out
    command = `feh #{@file_out}`
    run command, show
    
  end
  
  def vignette(quality: nil)
    
    img = read()
    img2 = img.vignette

    write img2, quality
    
  end
  
  alias feathered_around vignette

  private
  
  def read(file=@file_in)
    data, type = RXFHelper.read(file)
    Magick::Image.from_blob(data).first
  end

  def run(command, show=false)

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
