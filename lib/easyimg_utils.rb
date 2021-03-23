#!/usr/bin/env ruby

# file: easyimg_utils.rb

require 'c32'
require 'x4ss'
require 'rmagick'
require 'webp_ffi'
require 'rxfhelper'
require 'detectfaces'

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
# detectfaces dependencies
# apt-get install libopencv-dev



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
  include RXFHelperModule
    

@commands = "
* add rectangle # usage: add_rectangle(color: 'green', x1: 12, y1: 12, x2: 24, y2: 24)
* add_svg # adds an SVG transparency overlay. usage: add_svg('/tmp/image1.svg')
* add_text # e.g. add_text('some text')
* animate Creates an animated gif e.g. animate('/tmp/a%d.png', '/tmp/b.gif')
* best_viewport # returns the best viewing region on the y-axis
* blur # e.g. blur(x: 231, y: 123, w: 85, h: 85)
* capture_screen # takes a screenshot of the desktop
* calc_resize # e.g. calc_resize '640x480' #=> 640x491
* center_crop # crops from the centre of an image. Usage center_crop(width, height)
* composite # overlay a smaller image on top of an image
* contrast # changes the intensity between lighter and darker elements
* convert # convert from 1 img format to another
* crop # e.g. crop(x: 231, y: 123, w: 85, h: 85)
* fax_effect # Produces a high-contrast, two colour image
* faces # Returns an array of bounding boxes for detected faces
* greyscale # Reduces the image to 256 shades of grey
* info # returns the dimension of the image in a Hash object
* make_thumbnail # similar to resize but faster for sizes less than 10% of original image 
* resize # set the maximum geomertry of the image for resizing e.g. resize('320x240') see also scale
* rotate
* rotate_180
* rotate_left
* rotate_right
* scale # Scales an image by the given factor e.g. 0.75 is 75%. see also resize
* screencast # records a screencast and saves it as animated gif. e.g. (out: '/tmp/fun.gif').screencast
* sketch # renders an artistic sketch, ideal with simplistic photos
* view # view the output
* vignette # Feathers the edge of an image in a circular path
".strip.lines.map {|x| x[/(?<=\* ).*/]}.sort


  def initialize(img_in=nil, img_out=nil, out: img_out, 
                 working_dir: '/tmp', debug: false)

    @file_in, @file_out, @working_dir = img_in, out, working_dir    
    @debug = debug

  end
  
  # e.g. calc_resize '1449x1932', '640x480' #=> 480x640
  # e.g. calc_resize '518x1024', '*518x500' #=> "518x1024" 
  # the asterisk denotes a guaranteed the image will be resized using x or y
  #
  def self.calc_resize(geometry, new_geometry, force: false)
    
    xy = geometry.split('x',2)
    xy2 = new_geometry.split('x',2)

    # find any locked geometry which guarantees the resize on either x or y
    lock = xy2.find {|x| x =~ /^\*/}

    a = xy.map {|x| x[/\d+/].to_i}
    a2 = xy2.map {|x| x[/\d+/].to_i}

    i = lock ? a2.index(lock[1..-1].to_i) : a.index(a.max)

    factor = a2[i] / a[i].to_f

    s3 = a.map {|x| (x * factor).round}.join('x')    
    
  end
  
  def add_rectangle(a=[], quality: nil, color: 'green', stroke_width: 5, 
                    x1: 0, y1: 0, x2: 0, y2: 0)
    
    x1, y1, x2, y2 = *a if a
    read() do |img|
      gc = Magick::Draw.new
      gc.stroke('green')
      gc.stroke_width(5)
      gc.fill('transparent')
      gc.rectangle(x1, y1, x2, y2)
      gc.draw(img)
      write img, quality
    end
    
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
    
    read() do |img|

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
    
  end
  
  def animate()

    anim = Magick::ImageList.new
    
    read() {|img| anim << img }    
    anim.ticks_per_second = 100
    anim.delay = 20
    
    @file_out ? anim.write(@file_out) : anim.animate
    
  end    
  
  # Used where images are perhaps cropped using CSS to a letterbox size image.
  # Works best with portrait mode photos of selfies or natural 
  #   landscapes with a lot of sky
  #
  # Returns the starting y pos as a percentage of the image using face 
  # detection and high contrast detection on the y-axis
  #
  def best_viewport()
    
    percentage = 0
    
    read() do |img|

      found = faces()
      
      index = if found.any? then
        
        # find the top y
        box = found.max_by {|x, y, width, height| y}
        box[1]
        
      else
        
        y_maxcontrast(img)
        
      end
            
      percentage = (100 / (img.rows / index.to_f)).round
      
    end    
    
    return percentage
    
  end
  
  def blur(x: 0, y: 0, w: 80, h: 80, strength: 8, quality: nil)
    
    width, height = w, h
    
    read() do |img|
      
      region = img.dispatch(x, y, width, height, 'RGB')
      face_img = Magick::Image.constitute(width, height, "RGB", region)
      img.composite!(face_img.gaussian_blur(0, strength), x, y, 
                    Magick::OverCompositeOp)
      write img, quality
      
    end
    
  end
  
  def brightness(quality: nil)
    read() do |img|
      img2 = imglevel(-Magick::QuantumRange * 0.25, Magick::QuantumRange * 1.25, 1.0)
      write img2, quality
    end
  end
  
  # calculates the new geometry after a resize
  #
  def calc_resize(geometry)    
    EasyImgUtils.calc_resize(info()[:geometry], geometry)
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
    
    read() do |img|
      img.crop!(CenterGravity, width, height)
      write img, quality
    end
    
  end
  
  def composite(filex=nil, x: 0, y: 0, quality: nil)
    
    return unless filex
    
    read() do |img|
        
      imgx = Magick::ImageList.new(filex)

      # Change the white pixels in the sign to transparent.
      imgx = imgx.matte_replace(0,0)

      img2 = Magick::Draw.new
      img2.composite(x, y, 0, 0, imgx)
      img2.draw(img)    
      
      write img, quality
    end
    
  end
  
  alias overlay composite
  alias add_img composite
  
  # contrast level 
  # 1 low -> 10 high
  #
  def contrast(level=5)
    
    neutral = 5
    
    return if level == neutral
        
    read() do |img|
            
      n = neutral - level
      sharpen  = n > 0 
      n.abs.times { img = img.contrast(sharpen) }
      
      write img, quality
    end
    
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
    
    read() do |img|
      img.crop!(x,y, width=w, height=h)
      write img, quality
    end
    
  end
  
  def faces()
    DetectFaces.new(@file_in).faces
  end
  
  def fax_effect(threshold: 0.55, quality: nil)

    read() do |img|
    
      # Use a threshold of 55% of MaxRGB.
      img = img.threshold(Magick::MaxRGB*threshold)      
      write img, quality
      
    end
    
  end
  
  def greyscale(quality: nil)
    
    read() do |img|
      img2 = img.quantize(256, GRAYColorspace)
      write img2, quality
    end
    
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
    
    read() do |img|
      img2 = img.thumbnail(width, height)
      write img2, quality
    end
    
  end
  
  alias thumbnail make_thumbnail

  # defines the maximum size of an image while maintaining aspect ratio
  #
  def resize(raw_geometry='320x240', quality: nil)
    
    geometry = calc_resize(raw_geometry
                             )
    read() do |preview|
    
      preview.change_geometry!(geometry) do |cols, rows, img|
        img.resize!(cols, rows)
      end
      
      write preview, quality
    end
    
  end
  
  def rotate(degrees)
    
    read() do |img|
      img2 = img.rotate(degrees.to_i)
      write img2, quality
    end
    
  end

  def rotate_180()
    
    read() do |img|
      img2 = img.rotate(180)
      write img2, quality
    end
    
  end    
  
  def rotate_left()
    
    read() do |img|
      img2 = img.rotate(-45)
      write img2, quality
    end
    
  end    
  
  def rotate_right()
    
    read() do |img|
      img2 = img.rotate(45)
      write img2, quality    
    end
    
  end  
  
  # Scales an image by the given factor e.g. 0.75 is 75%
  #
  def scale(factor=0.75, quality: nil)
    
    read() do |img|
    
      img2 = img.scale(factor)      
      write img2, quality
      
    end
    
  end

  # Takes a screenshot every second to create an animated gif
  #
  def screencast(duration: 6, scale: 1, window: true)
    
    fileout = @file_out.sub(/\.\w+$/,'%d.png')
    
    puts 'fileout: ' + fileout if @debug
    
    x4ss = X4ss.new fileout, mouse: true, window: true
    mode = window ? :window : :screen
    sleep 2; x4ss.record duration: duration, mode: mode
    x4ss.save
    
    fileout2 = fileout.sub(/(?=%)/,'b')
    EasyImgUtils.new(fileout, fileout2).scale(scale) unless scale == 1
    EasyImgUtils.new(fileout2, @file_out).animate
    
  end
  
  def sketch(quality: nil)
    
    read() do |img|

      # Convert to grayscale
      sketch = img.quantize(256, Magick::GRAYColorspace)

      # Apply histogram equalization
      sketch = sketch.equalize

      sketch = sketch.sketch(0, 10, 135)
      img = img.dissolve(sketch, 0.75, 0.25)

      write img, quality
      
    end
    
  end
  
  alias drawing sketch

  def view(show: true)
    
    return unless @file_out
    command = `feh #{@file_out}`
    run command, show
    
  end
  
  def vignette(quality: nil)
    
    read() do |img|
      
      img2 = img.vignette
      write img2, quality
      
    end
    
  end
  
  alias feathered_around vignette 

  private
  
  def read(file=@file_in)
    
    files = if file =~ /%d/ then

      regfilepath = file.sub('%d','(\d+)')
      globfilepath = file.sub('%d','*')
      
      a = Dir[globfilepath]
      puts 'a: '  + a.inspect if @debug
      a.sort_by {|x| Regexp.new(regfilepath).match(x).captures[0].to_i }      

    else
      [file]
    end     
    
    files.each do |filex|
      
      @filex_in = filex
      data, type = RXFHelper.read(filex)
      yield(Magick::Image.from_blob(data).first)      
      
    end    

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
    
    file_out = if @file_out =~ /%d/ then
      regpath = @file_in.sub('%d','(\d+)')
      n = @filex_in[/#{regpath}/,1]
      @file_out.sub('%d',n)
    else
      @file_out
    end
    
    if file_out =~ /^dfs:/ then
      
      outfile = File.join(@working_dir, File.basename(file_out))
      
      img.write outfile do 
        self.quality = quality.to_i if quality
      end

      FileX.cp outfile, file_out
      
    else
      
      img.write file_out do 
        self.quality = quality.to_i if quality
      end
      
    end
  end
  
  # returns the y index of the pixel containing the most contrast using the 
  # y-axis center of the image
  #
  def y_maxcontrast(img)

    rows, cols = img.rows, img.columns
    center = (cols / 2).round
    pixels = img.get_pixels(center,0,1,rows)
    
    rgb = []
    px = pixels[0]
    rgb = [px.red, px.green, px.blue].map { |v| 255*(v/65535.0) }

    a = pixels[1..-1].map do |pixel,i|

      c = [pixel.red, pixel.green, pixel.blue].map { |v| 255*(v/65535.0) }
      rgb[0] - c[0]
      rgb.map.with_index {|x,i| (x - c[i]).abs.to_i}

    end

    a2 = a.map(&:sum)
    a2.index(a2.max) + 1
    
  end  
  
end
