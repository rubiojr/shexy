# Shexy

SSH, the way I like it.

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

Copying files (local -> remote):

    Shexy.copy_to 'test@test-host', '/home/rubiojr/my-uber-file', '/tmp/'

## Caution

I was bored writing net-ssh boilerplate, so I created this highly 
experimental sh*t (a small amount of it, but experimental).

## Copyright

Copyright (c) 2012 Sergio Rubio. See LICENSE.txt for
further details.

