#!/usr/local/bin/ruby -w

# jlsync.rb - jlsync in ruby
# Jason Lee, jlsync@jason-lee.net.au, 
# Copyright 2006 Jason Lee Pty. Ltd.
# $Id: jlsync.rb,v 1.5 2006/03/19 13:40:24 plastic Exp $
#

require "fileutils";
require "getoptlong";

jlsync_config = "/jlsync/etc/jlsync.config"
jlsync_source = "/jlsync/source"

class Config

    def initialize(config_file)

        @masks_of = {}
        @hosts_with = {}
        # read in config_file
        File.open(config_file).readlines.each do |line|
            next if line =~ /^#|^\s*$/
            masks = line.chomp.split(/\s+/)
            if ( @masks_of[masks.last] )
                puts "Error duplicat entries for #{masks.last} in #{config_file}. exiting. "
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

        dup = self.dup  # "shallow" copy 

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
                   puts "adding " + a.name 
                   a.name =~ /\.#{mask}\.a~/
                   basename = $` 
                   basename_re = Regexp.escape( basename )
                   fnodes = fnodes.select { |f| f.name !~ /#{basename_re}(\.\w+\.[ade]~)?$/ }
                   a.name = basename
                   fnodes.push a
               }

            dlist = fnodes.select { |node| node.name =~ /\.#{mask}\.d~/ }
            dlist.each { |d|
                   puts "delete " + d.name 
                   d.name =~ /\.#{mask}\.d~/
                   basename = Regexp.escape( $` )
                   fnodes = fnodes.select { |f| f.name !~ /#{basename}(\.\w+\.[ade]~)?$/ }
               }

            elist = fnodes.select { |node| node.name =~ /\.#{mask}\.e~/ }
            elist.each { |e|
                   puts "excluding " + e.name 
                   e.name =~ /\.#{mask}\.e~/
                   basename =  $`
                   basename_re = Regexp.escape( basename )
                   fnodes = fnodes.select { |f| f.name !~ /#{basename_re}(\.\w+\.[ade]~)?$/ }
                   exclude_patterns.push basename
               }
        }

        return fnodes, exclude_patterns
    end


    def atime
        @stat.atime
    end

    def directory?
        @stat.directory?
    end

    def file?
        @stat.file?
    end

    def symlink?
        @stat.symlink?
    end

    def fullpath
        @parent ? @parent.fullpath + "/" + @name : @name
    end

    def replicate(destdir)
        puts destdir
        destname = destdir +  "/" + @name
        puts destname
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
            puts "unknown file type! " + @origpath
        end
    end
end


config = Config.new(jlsync_config)
source = Node.new
source.source("", jlsync_source, nil)

stage = "/jlsync/stage/jlsync.rb"


FileUtils.rm_rf(stage)
copy = source.build_image("server94",config)
puts source.class
puts source.nodes[0].nodes[0].nodes[3].nodes.each {|x| puts x.name }
puts source.nodes[0].nodes[0].nodes[3].nodes[6].name
puts
puts copy.class
puts copy.nodes[0].nodes[0].nodes[3].nodes.each {|x| puts x.name }
puts copy.nodes[0].nodes[0].nodes[3].nodes[6].name

copy.replicate(stage)


