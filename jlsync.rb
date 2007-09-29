#!/usr/local/bin/ruby -w

# jlsync.rb - jlsync in ruby
# Jason Lee, jlsync@jason-lee.net.au, 
# Copyright 2006,2007 Jason Lee Pty. Ltd.
# $Id: jlsync.rb,v 1.16 2007/09/29 14:07:15 plastic Exp $
#
# == NAME
# 
# jlsync - rsync wrapper to deploy files from a central repository to
# client hosts and for ongoing configuration management.
# 
# == SYNOPSIS
# 
#  jlsync [--real] [--nocolor] [--verbose] clienthost:/path/to/pushout 
#          [clienthost2:/another/path2/pushout]...
# 
#  jlsync --get [--real] [--mask=NAME] clienthost:/path/to/pullin
#          [clienthost2:/another/path2/pullin]...
# 
#  jlsync --report [--email=address] clienthost:/path/to/check 
#          [clienthost2:/another/path2/check]...
# 
# == VERSION
# 
# This documentation refers to jlsync version 3.0. ($Revision: 1.16 $)
# 
# == DESCRIPTION
# 
# jlsync is a rsync wrapper that allows files and directories to be
# syncronised from a central repository to many client hosts. jlsync can
# be used for initial installation and also for ongoing configuration
# managment. Files can be grouped into file templates that individual
# client hosts can "subscribe" to. The repository is constructed from
# regular unix files and directories (package management formats like
# rpm, deb, pkg are not required or directly supported). The repository
# supports special template files using the erb (embeded ruby) format.
# jlsync works well with ssh key authentication to avoid rsync over ssh
# being prompted for remote client root passwords.
# 
# == OPTIONS
# 
# <tt>--nocolor</tt> turns of color text highlighting. By default rsync commands
# and other actions are highlighted in different colors.
# 
# <tt>--verbose</tt> turn on more debug output.
# 
# <tt>--get</tt> pull files from the remote client into the repository (instead
# of the default behaviour which is to push out files form the
# repository).
# 
# <tt>--real</tt> do not prompt for confirmation of actions. Use this option
# with caution!
# 
# <tt>--mask=template_name</tt> when pulling files from a remote client put them
# into the repostitory with and add mask of template_name.
# 
# <tt>--report</tt> print out a report of differences between client pathnames
# and staging image taken using the rsync --dry-run output.
# 
# <tt>--email=address</tt> Report is emailed to the email address "address"
# instead of being printed out.
# 
# 
# == BASIC USAGE
# 
# To distribute /usr/java from the repository to a host called jav04
# run the following commands:
# 
# First run
# 
#  jlsync jav04:/usr/java  
# 
# this will build a staging image for jav04 and then do a rsync --dry-run
# of +/usr/java+ to jav04. Look closely at the output to verify the
# additions and deletions on the remote host are as expected. You will
# then be prompted with "would you like to run rsync now for real? ".
# Answer yes to run rsync again without the --dry-run rysnc option (ie. go
# ahead and make changes to client for "real").
# 
# Only if you're 100% sure that jlsync is going add and delete
# the correct files you can run with the <tt>--real</tt> option
# 
#  jlsync --real jav04:/usr/java
# 
# when the <tt>--real</tt> option you are not prompted and rsync to the client
# does not use the rsync --dry-run option. BE CAREFUL, incorrect usage or
# incorrect configuration in the repository could easily result in the
# permanent deletion of important files on the client.
# 
# === Getting remote files into the repository
# 
# To quickly gather files and/or directories from a remote host back 
# into the repostory the <tt>--get</tt> option can be used. 
# A specific template for the gathered files can be named with the
# <tt>--mask</tt> option.  For example to get a freshly installed httpd binary
# back from client host web01 into the repostory for the file template
# "WEBSERVERS" run
# 
#  jlsync --get --mask=WEBSERVERS web01:/usr/local/apache/bin/httpd
# 
# This will result in <tt>usr/local/apache/bin/httpd.WEBSERVERS.a~</tt> being
# added to the repostitory.  Once the file is in the repository it can be
# deployed to other clients that subscribe to the WEBSERVERS template.
# 
# Files can be gathered into the special DEFAULT file template
# 
#  jlsync --get --mask=DEFAULT  holly:/usr/local/bin/rsync
# 
# will result in <tt>usr/local/bin/rsync</tt> being added to the repostitory.
# 
# When a <tt>--mask</tt> option is not given gathered files will be added to the
# clients own host template. e.g.
# 
#  jlsync --get goanna:/etc/hosts
# 
# would result in <tt>etc/hosts.goanna.a~</tt> being added to the repository. 
# 
# === The config file
# 
# Each client host has an entry in the <tt>jlsync.config</tt> file that lists
# the file templates that it subscribes to. A template is made up of
# files and control files in the repository that share same template/mask
# name.  Using templates is a convenient way of grouping files that
# should only be deployed to a certain category of hosts such as "web
# servers" or "database servers".
# 
# Every client must subscribe to the base template called DEFAULT.  Also
# each client also must subscribe to a template that is the same as that
# client's hostname.
# 
# Templates filesets are layered one upon another to build the jlsync
# client image in the staging area before the image is rsync'ed to the
# client.  The control files for templates are applied in reverse order
# as they are listed in the control file, ie. right to left. So when
# multiple control files with the same basename exist the most
# significate control file is used. Hostname control files are always the
# most significant and the DEFAULT control files are always the least
# significant.
# 
# The following example <tt>jlsync.config</tt> entry shows a host, jav04, entry
# that only contains the minimum of the DEFAULT template and it's own
# template.
# 
#  DEFAULT      jav04
# 
# The next example <tt>jlsync.config</tt> entry shows a host, www05, who's final
# file image is made up of 3 additional file templates
# 
#  DEFAULT WEBSERVERS prodservers london www05
# 
# === The respository 
# 
# All the files for the all the file templates are stored in the
# repostitory under the same directory root. Control files for
# different templates are named with filename suffix <tt>.templatename.X~</tt>
# notation. Files in the DEFAULT template don't need the suffix notation.
# 
# === Control Files
# 
# 
# ==== the Add .templatename.a~ controlfile
# 
# Files and/or directories from the repository for a given template with
# with Add control file suffix, <tt>.templatename.a~</tt> , get added to the final
# staging image for clients that subscribe to I<templatename>.
# 
# ==== the Delete .templatename.d~ controlfile
# 
# If a file with the Delete control file suffix exists in the repository
# then the corresponding file or directory with the same basename will
# not be added the staging image for that client.
# 
# Rsync will delete files on remote hosts that aren't found in the local
# file image (that is unless they have also been excluded from the rsync
# comparision).
# 
# The easiest way to create Delete and Exclude control files is to simply
# "touch" them.
# 
# ==== the Exclude .templatename.e~ controlfile
# 
# Files with Exclude suffix, <tt>.templatename.e~</tt> , are added to the list
# of files to be excluded from the rsync comparision. Any files or
# directories that are excluded will not be deployed from the staging
# area or updated/deleted from the client host.
# 
# The following Exclude file will cause the <tt>/var/run/sendmail.pid</tt> file
# to be be ignored (left alone) by the rsync for all client hosts
# 
# 
#  /var/run/sendmail.pid.DEFAULT.e~
# 
# This next exclude bontrol file will cause the entire <tt>/var/mysql</tt>
# directory to be ignored for any client hosts that are listed with the
# "databaseservers" template in the jlsync.config file.
# 
#  /var/mysql.databaseservers.e~
# 
# Exclude control files can also contain regular expressions (as defined
# and used by rsync) to match multiple files. For example, to exclude any
# file ending in .pid in <tt>/app/sendSMS</tt> use
# 
#  /app/sendSMS/*.pid.DEFAULT.e~
# 
# To exclude the syslogd messages files (messages, messages.1, etc.) you
# could use
# 
#  /var/log/messages*.DEFAULT.e~
# 
# To exlude all files in a directory (but make sure the directory is part
# of the template) use something like
# 
#  /var/mysql/*.databaseservers.e~
# 
# == ADVANCED USAGE
# 
# Multiple files from the same client can be deployed at the same time
#       
#  jlsync jav04:/etc/passwd jav04:/etc/shadow
# 
# this style of usage is useful when base directory of the files is not
# fully syncronised with the repository. It's also quicker than two
# individual invocations of jlsync as the staging image is only built
# once.
# 
# Multiple clients can be deployed in a single command
# 
#  jlsync jav03:/opt/apache jav04:/opt/apache
# 
# with this sytle of usage the staging image for each client will be
# built first before files are deployed.
# 
# Any combination of host:/path arguments can be used on the jlsync 
# command line. e.g.
# 
#  jlsync db01:/u01 nfs1:/export anyhost:/any/path
# 
# === Advanced Control Files
# 
# A control file can belong to multiple masks at once by separating the
# masks with a comma "," e.g.
# 
#  /opt/apache.www3,www4.a~
# and
#  /etc/motd.INTERNAL,EXTERNAL,DMZ.e~
# 
# === Advanced command line with multiple hosts
# 
# When the same path needs to be jlsynced to multiple hosts those hosts 
# can given as a single comma separated list prior to the path. e.g.
# 
#  jlsync sol01,sol02,sol03,sol04,sol05,sol06,sol07:/opt/csw
# 
# === Advanced command line with matching template/mask names
# 
# The <tt>=templatename:/path</tt> command line notation can be used to match
# all hosts that "subscribe" to that templatename in the jlsync.config
# file. For example to select all hosts that have the SOLARIS template
# listed in as part configuration in jlsync.config the following could be
# used.
# 
#  jlsync =SOLARIS:/etc/nscd.conf
# 
# And because all hosts must subscribe to the DEFAULT template the
# following will jlsync to all configured hosts
# 
#  jlsync =DEFAULT:/etc/issue
# 
# It's possible to get the intersection of muliple templates by chaining
# them together. For example the following would match all production
# debian hosts in newyork
# 
#  jlsync =PROD=DEBIAN=newyork:/usr/local/etc/timezone
# 
# To get the union of multiple templates you can separate them by
# commas.  e.g. All hosts in London and Melbourne
# 
#  jlsync =LONDON,=MELBOURNE:/etc/passwd =LONDON,=MELBOURNE:/etc/shadow
# 
# == REPORT OPTION
# 
# Ad-hoc filesystem changes made on a client can cause it's configuration
# to "drift" away from it's jlsync repository configuration. The
# <tt>--report</tt> option can help maintain discipline over client and jlsync
# repository changes by reporting any differences found. e.g.
# 
#  jlsync --report bill:/usr/local ben:/usr/local
# 
# will generate an onscreen report of changes between the <tt>/usr/local</tt>
# directors on clients bill and ben and the repository. Using the
# <tt>--email</tt> option will cause the report to be sent via email e.g.
# 
#  jlsync --report --email=admin@company.com mailhub:/etc/mail
# 
# Scheduling jlsync reports in cron can be a useful way to keep an eye on
# client/repository drift.
# 
# == ABSOLUTELY NO WARRANTY
# 
# Because the program is licensed free of charge, there is no warranty
# for the program, to the extent permitted by applicable law. Except when
# otherwise stated in writing the copyright holders and/or other parties
# provide the program "as is" without warranty of any kind, either
# expressed or implied, including, but not limited to, the implied
# warranties of merchantability and fitness for a particular purpose. The
# entire risk as to the quality and performance of the program is with
# you. Should the program prove defective, you assume the cost of all
# necessary servicing, repair or correction.
# 
# In no event unless required by applicable law or agreed to in writing
# will any copyright holder, or any other party who may modify and/or
# redistribute the program as permitted above, be liable to you for
# damages, including any general, special, incidental or consequential
# damages arising out of the use or inability to use the program
# (INCLUDING BUT NOT LIMITED TO LOSS OF DATA or DATA BEING RENDERED
# INACCURATE or losses sustained by you or third parties or a failure of
# the program to operate with any other programs), even if such holder or
# other party has been advised of the possibility of such damages.
# 
# == BUGS
# 
# yes there are few bugs. 
# 
# == SEE ALSO
# 
# The rsync(1) man page.
# The jlsync website http://www.jlsync.com/
# 
# == AUTHOR
# 
# Jason Lee
# 



require 'rubygems'
require 'term-ansicolor'
include Term::ANSIColor
class String
  include Term::ANSIColor
end
require "fileutils"
require 'erb'

require 'getoptlong'
real = false
get  = false
getmask  = nil
nocolor = false
eport = false
email = nil

opts = GetoptLong.new( [ "--real", "-r",           GetoptLong::NO_ARGUMENT], 
                       [ "--get", "-g",           GetoptLong::REQUIRED_ARGUMENT], 
                       [ "--nocolor", "-n",        GetoptLong::NO_ARGUMENT], 
                       [ "--report",                GetoptLong::NO_ARGUMENT], 
                       [ "--email", "-e",          GetoptLong::REQUIRED_ARGUMENT]
                     )

opts.each do |opt, arg|
  case opt
  when "--real" 
    real = true
  when "--get"
    get = true
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

class Rsync
  @rsync = '/usr/local/bin/rsync';
end

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

  attr_accessor :name, :dir, :parent, :imagepath, :origpath, :matched_mask, :file_mask, :stat, :client, :masks

  def initialize( params )
      @name          = params[:name]
      @dir           = params[:dir]
      @parent        = params[:parent]
      @imagepath     = params[:imagepath]
      @origpath      = params[:origpath]
      @matched_mask  = params[:matched_mask]
      @file_mask     = params[:file_mask]
      @stat          = params[:stat]
      @client        = params[:client]
      @masks         = params[:masks]
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
    @parent ? File.join(@parent.fullpath, @name) : @name
  end

  def erb?
      erb
  end

  def replicate(destdir)
    destname = File.join(destdir, @name)
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
    @origpath = File.join(dir, name)  # my on disk location
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

    #destname = File.join(destdir, @name)

    dup = self.dup  # shallow copy

    dup.dir = dir
    dup.name = name
    dup.parent = parent
    dup.imagepath = File.join(dir, name)

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

      mask_re = / ( (\w+,)* #{mask} (,\w+)* ) /x
      control_re = / \. (\w+,)* \w+ \. (a|d|e|r) ~ $  /x

      r_re = Regexp.new( "\." + mask_re.to_s + "\.r~$" )
      rlist = fnodes.select { |node| node.name =~ r_re }
      rlist.each { |r|
        puts "erb: #{r.origpath}".magenta
        basename = r_re.match(r.name).pre_match 
        basename_re = Regexp.escape( basename )
        file_mask = r_re.match(r.name)[1]

        fnodes = fnodes.select { |f| f.name !~ Regexp.new( basename_re.to_s + control_re.to_s ) }
        r.name = basename
        r.erb = true
        r.erb_binding = NodeErbBinding.new( :file_mask => file_mask, :matched_mask => mask, :name => basename, :stat => r.stat, :origpath => r.origpath, :client => client, :masks => config.masks_of(client) )
        fnodes.push r
      }

      a_re = Regexp.new( "\." + mask_re.to_s + "\.a~$" )
      alist = fnodes.select { |node| node.name =~ a_re }
      alist.each { |a|
        puts "add: #{a.origpath}".green
        basename = a_re.match(a.name).pre_match 
        basename_re = Regexp.escape( basename )
        fnodes = fnodes.select { |f| f.name !~ Regexp.new( basename_re.to_s + control_re.to_s ) }
        a.name = basename
        fnodes.push a
      }

      d_re = Regexp.new( "\." + mask_re.to_s + "\.d~$" )
      dlist = fnodes.select { |node| node.name =~ d_re }
      dlist.each { |d|
        puts "del: #{d.origpath}".red
        basename_re = Regexp.escape( d_re.match(d.name).pre_match )
        fnodes = fnodes.select { |f| f.name !~ Regexp.new( basename_re.to_s + control_re.to_s ) }
      }

      e_re = Regexp.new( "\." +  mask_re.to_s + "\.e~$" )
      elist = fnodes.select { |node| node.name =~ e_re }
      elist.each { |e|
        puts "exc: #{e.origpath}".cyan
        basename =  e_re.match(e.name).pre_match 
        basename_re = Regexp.escape( basename )
        fnodes = fnodes.select { |f| f.name !~ Regexp.new( basename_re.to_s + control_re.to_s ) }
        exclude_patterns.push basename
      }
    }

    # now remove any other remainting control files for other masks
    fnodes = fnodes.select { |f| f.name !~ /\w+\.\w+\.[ader]~$/ }

    return fnodes, exclude_patterns
  end


end

class Rsync
  # @rsync is defined above in configuration section

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

  # TODO
  def self.get (real, client, src_root_dir, path, excludepatterns = [] )

    puts "TODO"

    #Dir.chdir src_root_dir

    #command = "#{@rsync} --rsync-path=/usr/local/bin/rsync --verbose --itemize-changes --compress --archive --delete --recursive --links --relative"

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

lastclient = nil
lastdir = nil

ARGV.each { |arg|
  if  arg =~ /(.+):(\/.*)/ 
     lastclient = clientarg = $1
     patharg = $2
     lastdir = File.dirname(patharg)
  elsif arg =~ /^\/.*/
     clientarg = lastclient 
     patharg = arg
     lastdir = File.dirname(patharg)
  else
     clientarg = lastclient 
     patharg = File.join(lastdir,arg)
  end

  matching_clients(clientarg, config).each do |client|
      paths_for[client] = (( paths_for[client].nil? ? [] :  paths_for[client] ) << patharg ).uniq
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
  print "disk image ".on_magenta.black, File.join(stage, server).on_magenta.black.bold, " deleting old...".on_magenta.black
  FileUtils.rm_rf(File.join(stage, server))
  print ", building new... ".on_magenta.black
  copy.replicate(File.join(stage, server))
  print "done.".on_magenta.black.bold
  puts reset
end

paths_for.each_key do |server| 
  paths_for[server].each do |path|
    if get
      Rsync.get(real, server , File.join(stage,server), path, [] )
    else
      Rsync.rsync(real, server , File.join(stage,server), path, [] )
    end
  end
end


