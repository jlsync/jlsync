#!/usr/local/bin/ruby

require "fileutils";

class Node 

    attr_reader :name, :nodes, :origpath

    def initialize(name, dir, parent)
        @name = name
        @dir = dir
        @parent = parent
        @origpath = dir + "/" + name
        @stat = File.lstat(@origpath)
        if self.directory?
            @nodes = []
            Dir.entries(@origpath).each { |f|
                next if f =~ /^(\.|\.\.)$/ 
                @nodes << Node.new(f , @origpath , self)
            }
        end
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
        puts self.fullpath
        destname = destdir +  "/" + @name
        if self.file?
            FileUtils.ln( @origpath, destname)
        elsif self.directory?
            FileUtils.mkdir destname # , @stat.mode.to_s
            nodes.each { |n| n.replicate(destname) }
            FileUtils.touch destname # , @stat.mtime
        elsif self.symlink?
            FileUtils.ln_s( @origpath, destname)
        else
            puts "unknown file type! " + @origpath
        end
    end

end


source = Node.new("", "/jlsync/source", nil)

stage = "/jlsync/stage/jlsync.rb"


FileUtils.rm_rf(stage)
#puts source.name
source.replicate(stage)


