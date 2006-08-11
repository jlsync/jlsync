#!/usr/local/bin/ruby -w

# jlsync.rb - jlsync in ruby
# Jason Lee, jlsync@jason-lee.net.au, 
# Copyright 2006 Jason Lee Pty. Ltd.
# $Id: jlsync.rb,v 1.7 2006/08/11 16:31:27 plastic Exp $
#



require 'rubygems'
require_gem 'term-ansicolor'
include Term::ANSIColor
class String
  include Term::ANSIColor
end
require "fileutils"

require 'getoptlong'
real = false
getmask  = nil
nocolor = false
eport = false
email = nil

opts = GetoptLong.new( [ "--real", "-r",           GetoptLong::NO_ARGUMENT], [ "--mask", "-m",           GetoptLong::REQUIRED_ARGUMENT], [ "--nocolor", "-n",        GetoptLong::NO_ARGUMENT], [ "--report",                GetoptLong::NO_ARGUMENT], [ "--email", "-e",          GetoptLong::REQUIRED_ARGUMENT])

opts.each do |opt, arg|
  case opt
  when "--real" 
    real = true
  when "--mask"
    getmask = arg
  when "--nocolor"
    nocolor = true
  when "--report"
    report = true
  when "--email"
    email = arg
  end
end


# require "pathname"; # maybe use this standard libarary soon.

jlsync_config = "/jlsync/etc/jlsync.config"
jlsync_source = "/jlsync/source"

# Turn of the coloring
Term::ANSIColor::coloring = false if (nocolor or (not STDOUT.isatty))




class JlConfig

  def initialize(config_file)
    @masks_of = {}
    @hosts_with = {}
    # read in config_file
    File.open(config_file).readlines.each do |line|
      next if line =~ /^#|^\s*$/
      masks = line.chomp.split(/\s+/)
      if ( @masks_of[masks.last] )
        puts "Error duplicat entries for #{masks.last} in #{config_file}. exiting. ".red.bold
        exit 1  # exception!
      else
        @masks_of[masks.last] = masks
        masks.each do |mask|
          if @hosts_with[mask]
            @hosts_with[mask] << masks.last
          else
            @hosts_with[mask] = [ masks.last ]
          end
        end
      end
    end
  end

  def masks_of(hostname)
    @masks_of[hostname]
  end

  def hosts_with(mask)
    @hosts_with[mask]
  end

end


class Node 

  attr_accessor :name, :dir, :parent, :imagepath, :nodes, :exclude_patterns 
  attr_reader   :origpath

  # Stat .atime .directory? .file?  .symlink?   
  def method_missing(method_id, *args)
    if @stat.respond_to?(method_id)
      @stat.send(method_id, *args)
    else
      super
    end
  end

  def fullpath
    @parent ? @parent.fullpath + "/" + @name : @name
  end

  def replicate(destdir)
    destname = destdir +  "/" + @name
    if self.file?
      FileUtils.ln @origpath, destname
    elsif self.directory?
      FileUtils.mkdir destname, :mode => @stat.mode & 07777 
      FileUtils.chown @stat.uid.to_s, @stat.gid.to_s, destname
      @nodes.each { |n| n.replicate(destname) }
      File.utime @stat.atime, @stat.mtime, destname 
    elsif self.symlink?
      FileUtils.ln_s @readlink, destname
      File.lchown @stat.uid, @stat.gid, destname
    else
      puts "unknown file type! #{@origpath}".red.bold
    end
  end


  # source_root() is a modified version of source() that take only the 
  # root directory of our source tree. 
  def source_root(dir)
    @name = nil      # my filename
    @dir = dir       # my directory name
    @parent = nil    # link to parent directory Node
    @origpath = dir  # my on disk location
    @stat = File.lstat(@origpath)
    @nodes = []               # directory entries
    if self.directory?
      Dir.entries(@origpath).each { |f|
        next if f =~ /^(\.|\.\.)$/ 
        new = Node.new
        new.source(f , @origpath , self)
        @nodes << new
      }
    else
      puts "error"
      exit 1;
    end
  end

  def source(name, dir, parent)
    @name = name                  # my filename
    @dir = dir                    # my directory name
    @parent = parent              # link to parent directory Node
    @origpath = dir + "/" + name  # my on disk location
    @stat = File.lstat(@origpath)
    if self.directory?
      @nodes = []               # directory entries
      Dir.entries(@origpath).each { |f|
        next if f =~ /^(\.|\.\.)$/ 
        new = Node.new
        new.source(f , @origpath , self)
        @nodes << new
      }
    elsif self.symlink?
      @readlink = File.readlink(@origpath)
    end
  end

  def build_image(client, config, name="", dir="", parent=nil)
    masks = config.masks_of(client)
    exclude_patterns = []

    #destname = destdir +  "/" + @name

    dup = self.dup  # shallow copy

    dup.dir = dir
    dup.name = name
    dup.parent = parent
    dup.imagepath = dir +  "/" + name

    if self.directory?
      # need to optimise this to be top down...
      # deep copy first...
      dup.nodes = dup.nodes.collect { |n|
        n.build_image(client, config, n.name, dup.imagepath, dup)
      }
      # ...and then apply control files.
      dup.nodes, dup.exclude_patterns = filter_controlfiles(client, config, dup.nodes)

    end

    return dup  # may not want to dup regular files?
  end


  def filter_controlfiles(client, config, nodes)
    fnodes = nodes  # filtered list of nodes
    exclude_patterns = []
    config.masks_of(client).reverse.each { |mask|

      alist = fnodes.select { |node| node.name =~ /\.#{mask}\.a~/ }
      alist.each { |a|
        puts "add:#{a.origpath}".green
        a.name =~ /\.#{mask}\.a~/
        basename = $` 
        basename_re = Regexp.escape( basename )
        fnodes = fnodes.select { |f| f.name !~ /#{basename_re}(\.\w+\.[ade]~)?$/ }
        a.name = basename
        fnodes.push a
      }

      dlist = fnodes.select { |node| node.name =~ /\.#{mask}\.d~/ }
      dlist.each { |d|
        puts "del:#{d.origpath}".red
        d.name =~ /\.#{mask}\.d~/
        basename = Regexp.escape( $` )
        fnodes = fnodes.select { |f| f.name !~ /#{basename}(\.\w+\.[ade]~)?$/ }
      }

      elist = fnodes.select { |node| node.name =~ /\.#{mask}\.e~/ }
      elist.each { |e|
        puts "exc:#{e.origpath}".cyan
        e.name =~ /\.#{mask}\.e~/
        basename =  $`
        basename_re = Regexp.escape( basename )
        fnodes = fnodes.select { |f| f.name !~ /#{basename_re}(\.\w+\.[ade]~)?$/ }
        exclude_patterns.push basename
      }
    }

    # now remove any other remainting control files for other masks
    fnodes = fnodes.select { |f| f.name !~ /\w+\.\w+\.[ade]~$/ }

    return fnodes, exclude_patterns
  end


end

class Rsync
  @rsync = '/usr/local/bin/rsync';

  def self.rsync (real, client, src_root_dir, path, excludepatterns = [] )

    Dir.chdir src_root_dir

    command = "#{@rsync} --rsync-path=/usr/local/bin/rsync --verbose --itemize-changes --compress --archive --delete --recursive --links --relative"

    #if (report)
    #
    #else


    unless (real)
      dry_command = command.dup
      dry_command << " --dry-run" <<  " .#{path} #{client}:/"
      puts dry_command.on_yellow.black.bold
      print on_yellow,black
      self.run(dry_command)
      puts reset
      print "Would you like to run rsync for real? "
      yes = (STDIN.gets =~ /^y/i)
    end

    if (real or yes)
      real_command = command.dup
      real_command << " .#{path} #{client}:/"
      puts real_command.on_green.black.bold
      print on_green,black
      self.run(real_command)
      puts reset
    end
  end

  def self.run (command)
    system(command)
    # IO.popen(command) { |line| ...
  end
end


paths_for = {}


ARGV.each { |arg|
  arg =~ /(.+):(\/.*)/
  $client = $1
  $path = $2
  paths_for[$client] = $path
}


config = JlConfig.new(jlsync_config)
source = Node.new
source.source_root(jlsync_source)

stage = "/jlsync/stage/jlsync.rb"


paths_for.each_key do |server| 
  copy = source.build_image(server,config)
  FileUtils.rm_rf(stage + "/" + server)
  copy.replicate(stage + "/" + server)
end

paths_for.each_key do |server| 
  paths_for[server].each do |path|
    Rsync.rsync(real, server , stage + "/" + server, path, [] )
    end
end





