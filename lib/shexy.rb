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
    
  VERSION = '0.3.5'

  [:user, :password, :key, :cmd, :host, :port].each do |n|
    instance_eval %{
      def #{n}; Thread.current[:shexy_#{n}]; end
      def #{n}=(v); Thread.current[:shexy_#{n}] = v; end
    }
  end

  def self.flags=(f);Thread.current[:shexy_flags] = f;end
  def self.flags; Thread.current[:shexy_flags] ||= {} ; end
  def self.sudo?;Thread.current[:shexy_use_sudo]; end
  def self.use_sudo(v = true); Thread.current[:shexy_use_sudo] = v; end

  def self.wait_for_ssh(timeout = 60)
    Timeout.timeout(timeout) do
      begin
        sleep(1) until tcp_test_ssh do
        end
      rescue Errno::ECONNRESET
        # safe to ignore, we need to retry all the time.
      end
    end
    true
  rescue Exception => e
    $stderr.puts e.message
    false
  end

  def self.tcp_test_ssh
    tcp_socket = TCPSocket.new(host, 22)
    readable = IO.select([tcp_socket], nil, nil, 5)
    if readable
      yield
      true
    else
      false
    end
  rescue Errno::ETIMEDOUT, Errno::EPERM
    false
  rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ENETUNREACH
    sleep 2
    false
  ensure
    tcp_socket && tcp_socket.close
  end

  def self.exe(*args)
    args.flatten!
    if args.size > 1
      self.host = args[0]
      self.user, self.host = self.host.split '@' if self.host =~ /@/
      self.cmd = args[1]
    else
      self.cmd = args[0]
    end
    self.flags[:password] = self.password if self.password
    self.flags[:keys] = [self.key] if self.key
    self.flags[:port] = self.port if self.port
    Net::SSH.start(self.host, self.user, self.flags) do |sh|
      sh.open_channel do |ch| 
        #
        # Note, too, that when a pty is requested, user's shell configuration 
        # scripts (.bashrc and such) are not run by default, 
        # whereas they are run when a pty is not present.
        #
        # http://net-ssh.github.com/net-ssh/classes/Net/SSH/Connection/Channel.html#method-i-request_pty
        #
        # FIXME: may not be successful, warn about it
        ch.request_pty 
        if sudo?
          regexp = /(&&|\|\||&|\|)/
          if cmd =~ regexp
            new_cmd = cmd.split(regexp).map do |t| 
              t =~ /^(&&|\|\||&|\|)$/ ? t : "sudo #{t}"
            end
            self.cmd = new_cmd.join ''
          end
          self.cmd = "sudo #{cmd}"
          puts "SHEXY: #{cmd}" if $DEBUG
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

  def self.batch(&block)
    require 'tempfile'
    def self.script(script)
      f = Tempfile.new 'shexy'
      begin
        f.puts script 
        f.flush
        copy_to f.path, "#{f.path}.remote"
        out, err, ecode, esig = exe "/bin/bash #{f.path}.remote" 
      ensure
        f.close
        f.unlink
      end
      return out, err, ecode, esig
    end
    instance_eval &block
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
      self.host = args[0]
      if self.host =~ /@/
        self.user, self.host = self.host.split '@'
      end
      from = args[1]
      to = args[2]
    else
      # user, host already set via Shexy.host and
      # Shexy.user
      from = args[0]
      to = args[1]
    end
    self.flags[:password] = self.password if self.password
    self.flags[:keys] = [self.key] if self.key
    self.flags[:port] = self.port if self.port
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

  def self.copy_ssh_pubkey(path, dest_dir = '~/.ssh')
    path = File.expand_path path
    raise ArgumentError.new("Invalid key file") unless File.exist?(path)
    key = File.read path
    batch do
      script <<-EOH
      mkdir -p #{dest_dir} && chmod 700 #{dest_dir}
      echo '#{key}' >> #{dest_dir}/authorized_keys
      EOH
    end
  end

  #
  # Set PermitRootLogin to value in /etc/ssh/sshd_config
  # value accepted: yes,now, without-password
  #
  def self.permit_root_login(value)
    value = value.to_s
    unless value =~ /^(yes|no|without-password)$/
      raise ArgumentError.new "Argument should be yes|no|without-password"
    end

    using_sudo = Shexy.sudo?
    Shexy.use_sudo unless Shexy.user == 'root'
    out, err = batch do
      script <<-EOH
      sed -i 's/^#\\?PermitRootLogin.*$/PermitRootLogin\\ #{value}/' /etc/ssh/sshd_config
      test -f /etc/init.d/ssh && /etc/init.d/ssh restart
      test -f /etc/init.d/sshd && /etc/init.d/sshd restart
      EOH
    end
    Shexy.use_sudo(false) unless using_sudo
    return out, err
  end

end
