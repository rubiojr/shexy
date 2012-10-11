# Shexy

SSH, the way I like it.

## Install

    gem install shexy

## Do it 

    require 'shexy'

    Shexy.user = 'test'
    Shexy.password = 'test'
    Shexy.host = 'test-host'
    out, err = Shexy.exe 'ls -la'
    out.empty? # no output
    err.empty? # no error output

    Shexy.exe 'la -la' do |out,err|
      puts out
      puts err
    end

Another way, assuming you are using SSH keys 
and added them to the SSH agent (ssh-add ~/.ssh/my-priv-key):

    Shexy.exe 'test@test-host', 'ls -la' do |out, err|
      puts out
    end
    Shexy.exe 'echo hello' # no need to add host/user again


Specify key to use:

    Shexy.key = '~/.ssh/id_rsa'
    out, err, exit_code = Shexy.exe 'test@test-host', 'ls -la'

Copying files (local -> remote):

    Shexy.copy_to 'test@test-host', '/home/rubiojr/my-uber-file', '/tmp/'

Batch mode:

    Shexy.batch do
      script <<-EOH
        echo > /tmp/foo
        ls -la
        sed -i s/foo/bar/ /etc/foo
      EOH
    end

Use sudo:

     Shexy.use_sudo
     # sudo will be used to run the commands
     Shexy.exe 'test@foobar.com', 'echo | cat' # => sudo echo | sudo cat

Query the server OS:

     Shexy.distro          # => :ubuntu, :redhat, :centos, :fedora, :debian
     Shexy.distro_release  # => 12.04, 5.8, etc.

More helpers:

     Shexy.user = 'rubiojr'
     Shexy.password = 'secret'
     Shexy.host = 'foo.com'
     # Copy the key to /home/rubiojr/.ssh/authorized_keys in remote server
     Shexy.copy_ssh_pubkey '~/.ssh/id_rsa.pub'
     # Set PermitRootLogin to without-password in /etc/ssh/sshd_config
     # requires sudo in remote server (unless using root user).
     Shexy.permit_root_login 'without-password'

## Caution

I was bored writing net-ssh boilerplate, so I created this highly 
experimental sh*t (a small amount of it, but experimental).

## Copyright

Copyright (c) 2012 Sergio Rubio. See LICENSE.txt for
further details.

