#!/usr/local/bin/ruby -w

# jlsync.rb - jlsync in ruby
# Jason Lee, jlsync@jason-lee.net.au, 
# Copyright 2006,2007 Jason Lee Pty. Ltd.
# $Id: jlsync.rb,v 1.10 2007/01/24 18:12:52 plastic Exp $
#



require 'rubygems'
require_gem 'term-ansicolor'
include Term::ANSIColor
class String
  include Term::ANSIColor
end
require "fileutils"
require 'erb'

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


class NodeErbBinding

  attr_accessor :name, :dir, :parent, :imagepath, :origpath, :matched_mask, :original_mask, :stat, :client

  def initialize( params )
      @name          = params[:name]
      @dir           = params[:dir]
      @parent        = params[:parent]
      @imagepath     = params[:imagepath]
      @origpath      = params[:origpath]
      @matched_mask  = params[:matched_mask]
      @original_mask = params[:original_mask]
      @stat          = params[:stat]
      @client        = params[:client]
  end

  # Stat .atime .directory? .file?  .symlink?   
  def method_missing(method_id, *args)
    if @stat.respond_to?(method_id)
      @stat.send(method_id, *args)
    else
      super
    end
  end

  def get_binding
      binding
  end

end



class Node 

  attr_accessor :name, :dir, :parent, :imagepath, :nodes, :exclude_patterns, :erb, :erb_binding
  attr_reader   :origpath, :stat

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

  def erb?
      erb
  end

  def replicate(destdir)
    destname = destdir +  "/" + @name
    if self.erb? && self.file?
      self.erb_binding.imagepath = destname
      template = ERB.new(File.read(@origpath))
      File.open(destname,"w") do |file|
        file.write template.result(self.erb_binding.get_binding)
      end
      File.chmod @stat.mode
      File.lchown @stat.uid, @stat.gid, destname
      File.utime @stat.atime, @stat.mtime, destname 
    elsif self.file?
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
    @erb = false                  # erb processing required? set later in filter_controlfiles
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

      rlist = fnodes.select { |node| node.name =~ /\.#{mask}\.r~/ }
      rlist.each { |a|
        puts "erb:#{a.origpath}".magenta
        a.name =~ /\.(#{mask})\.r~/
        basename = $` 
        original_mask = $1
        basename_re = Regexp.escape( basename )
        fnodes = fnodes.select { |f| f.name !~ /#{basename_re}(\.\w+\.[ader]~)?$/ }
        a.name = basename
        fnodes.push a
        a.erb = true
        a.erb_binding = NodeErbBinding.new( :original_mask => original_mask, :matched_mask => mask, :name => basename, :stat => a.stat, :origpath => a.origpath, :client => client )
      }

      alist = fnodes.select { |node| node.name =~ /\.#{mask}\.a~/ }
      alist.each { |a|
        puts "add:#{a.origpath}".green
        a.name =~ /\.#{mask}\.a~/
        basename = $` 
        basename_re = Regexp.escape( basename )
        fnodes = fnodes.select { |f| f.name !~ /#{basename_re}(\.\w+\.[ader]~)?$/ }
        a.name = basename
        fnodes.push a
      }

      dlist = fnodes.select { |node| node.name =~ /\.#{mask}\.d~/ }
      dlist.each { |d|
        puts "del:#{d.origpath}".red
        d.name =~ /\.#{mask}\.d~/
        basename = Regexp.escape( $` )
        fnodes = fnodes.select { |f| f.name !~ /#{basename}(\.\w+\.[ader]~)?$/ }
      }

      elist = fnodes.select { |node| node.name =~ /\.#{mask}\.e~/ }
      elist.each { |e|
        puts "exc:#{e.origpath}".cyan
        e.name =~ /\.#{mask}\.e~/
        basename =  $`
        basename_re = Regexp.escape( basename )
        fnodes = fnodes.select { |f| f.name !~ /#{basename_re}(\.\w+\.[ader]~)?$/ }
        exclude_patterns.push basename
      }
    }

    # now remove any other remainting control files for other masks
    fnodes = fnodes.select { |f| f.name !~ /\w+\.\w+\.[ader]~$/ }

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



def list_of_lists_intersection(lists)
    if lists.nil?
        return nil
    elsif lists.size == 1
        return lists.shift
    else
        return lists.shift & list_of_lists_intersection(lists)
    end
end


def matching_clients(clientarg, config)
    clients = []

    clientarg.split(/,/).each do |set|
        if set =~ /^=(.*)/
            masklist = $1
            masks = masklist.split(/=/)
            masks.each do |mask|
                if config.hosts_with(mask).nil?
                    puts "#{mask} not found in file #{jlsync_config}. exiting.".red.bold
                    exit 1
                end
            end

            clients |= list_of_lists_intersection(masks.map{ |mask| config.hosts_with(mask) })
        else
            if config.masks_of(set).nil?
                puts "#{set} not found in file #{jlsync_config}. exiting.".red.bold
                exit 1
            end

            clients |= [ set ]
        end
    end
    return clients
end




config = JlConfig.new(jlsync_config)

paths_for = {}

ARGV.each { |arg|
  arg =~ /(.+):(\/.*)/
  clientarg = $1
  patharg = $2
  matching_clients(clientarg, config).each do |client|
      paths_for[client] = patharg
  end
}


source = Node.new
print "reading #{jlsync_source} repository... "
source.source_root(jlsync_source)
puts "done."

stage = "/jlsync/stage"


paths_for.each_key do |server| 
  print "Server: ".on_magenta.black, "#{server}".on_magenta.black.bold , "  masks: ".on_magenta.black
  print config.masks_of(server).join(" ").on_magenta.blue.bold
  print " building memory image...".on_magenta.black
  puts 
  copy = source.build_image(server,config)
  print "disk image ".on_magenta.black, (stage + "/" + server).on_magenta.black.bold, " deleting old...".on_magenta.black
  FileUtils.rm_rf(stage + "/" + server)
  print ", building new... ".on_magenta.black
  copy.replicate(stage + "/" + server)
  print "done.".on_magenta.black.bold
  puts reset
end

paths_for.each_key do |server| 
  paths_for[server].each do |path|
    Rsync.rsync(real, server , stage + "/" + server, path, [] )
    end
end





