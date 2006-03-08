#!/usr/local/bin/ruby -w

require "fileutils";

jlsync_config = "/jlsync/etc/jlsync.config"
jlsync_source = "/jlsync/source"

class Config

    def initialize(config_file)

        @masks_of = {}
        @hosts_with = {}
        # read in config_file
        File.open(config_file) do |file|
            while line = file.gets
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
    end

    def masks_of(hostname)
        @masks_of[hostname]
    end

    def hosts_with(mask)
        @hosts_with[mask]
    end

end


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
            FileUtils.ln @origpath, destname
        elsif self.directory?
            FileUtils.mkdir destname, :mode => @stat.mode & 07777 
            FileUtils.chown @stat.uid.to_s, @stat.gid.to_s, destname
            nodes.each { |n| n.replicate(destname) }
            File.utime @stat.atime, @stat.mtime, destname 
        elsif self.symlink?
            FileUtils.ln_s @origpath, destname
        else
            puts "unknown file type! " + @origpath
        end
    end

    def build_image(destdir, client, config)
        masks = config.masks_for(client)
        exclude_patterns = []
        puts self.fullpath
        destname = destdir +  "/" + @name
        if self.file?
            FileUtils.ln @origpath, destname
        elsif self.directory?
            FileUtils.mkdir destname, :mode => @stat.mode & 07777 
            FileUtils.chown @stat.uid.to_s, @stat.gid.to_s, destname
            # nodes.each ... filter control files....
            # filtered.each { |n| push'n'map exclustions  <-n.replicate(destname) }
            
            File.utime @stat.atime, @stat.mtime, destname 
        elsif self.symlink?
            FileUtils.ln_s @origpath, destname
        else
            puts "unknown file type! " + @origpath
        end
        return exclude_patterns
    end

end


config = Config.new(jlsync_config)
source = Node.new("", jlsync_source, nil)

stage = "/jlsync/stage/jlsync.rb"


FileUtils.rm_rf(stage)
#puts source.name
#source.replicate(stage)
#source.build_image(stage, "server94", config)

puts config.hosts_with("SOLARIS")
puts
puts config.masks_of("server94").join(" ")



