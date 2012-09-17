require 'net/ssh'
require 'net/scp'

#
# Execute commands in remote servers (SSH)
#
#     require 'shexy'
#
#     Shexy.user = 'test'
#     Shexy.password = 'test'
#     Shexy.host = 'test-host'
#     out, err = Shexy.exe 'ls -la'
#     out.empty? # no output
#     err.empty? # no error output
#
#     Shexy.exe 'la -la' do |out,err|
#       puts out
#       puts err
#     end
#
# Another way, assuming you are using SSH keys 
# and added them to the SSH agent (ssh-add ~/.ssh/my-priv-key):
#
#     Shexy.exe 'test@test-host', 'ls -la' do |out, err|
#       puts out
#     end
#     Shexy.exe 'echo hello' # no need to add host/user again
#
# Copying files (local -> remote):
#
#     Shexy.copy_to 'test@test-host', '/home/rubiojr/my-uber-file', '/tmp/'
#
module Shexy

  VERSION = '0.2'

  @flags = {}

  def self.password=(password); flags[:password] = password; end
  def self.password; flags[:password]; end
  def self.key=(key); flags[:keys] = [File.expand_path(key)]; end
  def self.key; flags[:keys]; end
  def self.use_sudo(v=true); @sudo = v; end
  def self.sudo?; @sudo ||= false; end

  class << self
    attr_accessor :host, :user, :flags
    attr_reader :cmd
  end

  def self.exe(*args)
    args.flatten!
    if args.size > 1
      @host = args[0]
      if @host =~ /@/
        @user, @host = @host.split '@'
      end
      @cmd = args[1]
    else
      @cmd = args[0]
    end
    Net::SSH.start(host, user, flags) do |sh|
      sh.open_channel do |ch| 
        if sudo?
          ch.request_pty 
          @cmd = "sudo #{@cmd}"
        end
        ch.exec cmd do
          # FIXME: I don't think it's a good idea
          # to implement access to stdout,stderr this way
          stdout = ""
          stderr = ""
          exit_code = -1
          exit_signal = -1
          ch.on_extended_data do |c2, type, data|
            # ERROR output here
            stderr << data
            yield nil, data if block_given?
          end
          ch.on_data do |c2, data|
            stdout << data
            yield data, nil if block_given?
          end
          ch.on_close do |c2|
            return stdout, stderr, exit_code, exit_signal
          end
          ch.on_request("exit-status") do |c2,data|
            exit_code = data.read_long
          end
          ch.on_request("exit-signal") do |c2, data|
            exit_signal = data.read_long
          end
        end
      end
    end
  end

  #
  # Shexy.copy_to 'root@foobar.com', 'source_file', 'dest_file'
  #
  # or
  #
  # Shexy.host = 'foobar.com'
  # Shexy.user = 'root'
  # Shexy.copy_to 'source_file', 'dest_file'
  # 
  def self.copy_to(*args)
    opts = {}
    if args.include?(:recursive)
      opts = { :recursive => true }
      args.delete :recursive
    end
    
    if args.size > 2
      # First arg assumed to be foo@host.net
      @host = args[0]
      if @host =~ /@/
        @user, @host = @host.split '@'
      end
      from = args[1]
      to = args[2]
    else
      # user, host already set via Shexy.host and
      # Shexy.user
      from = args[0]
      to = args[1]
    end
    from = File.expand_path from
    Net::SCP.start(host, user, flags) do |scp|
      scp.upload! from, to, opts
    end
  end

  # 
  # Detect distro version
  #
  def self.distro
    issue.match(/fedora|centos|frameos|debian|ubuntu|scientific linux/i)[0].gsub(" ", "_").downcase.to_sym
  end

  #
  # Detect distro release
  #
  def self.distro_release
    case distro 
    when :redhat,:centos,:frameos
      issue.split[2]
    when :fedora
      issue.split[2]
    when :ubuntu
      issue.split[1]
    when :debian
      issue.split[2]
    else
      '0'
    end
  end

  #
  # Lame but short, and it works (most of the times)
  #
  def self.issue
    issue, err = ((exe 'cat /etc/issue')[0].strip.chomp || Shexy.exe('lsb_release -i')[0].strip.chomp).lines.first
    raise Exception.new "Error reading release info." unless (err.nil? or err.empty?)
    issue
  end

end
