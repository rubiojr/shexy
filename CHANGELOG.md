# 0.3.3

* Always request_pty by default

  http://net-ssh.github.com/net-ssh/classes/Net/SSH/Connection/Channel.html#method-i-request_pty

  Useful to be able to use sudo when requiretty is enabled in /etc/sudoers
  without having to Shexy.use_sudo

# 0.3.2

* Fix Shexy.wait_for_ssh

# 0.3.1

* Bug fixes

# 0.3

* Bug fixes
* Shexy should be thread safe now
* Added some more methods (see README)
  - Shexy.permit_root_login
  - Shexy.copy_ssh_pubkey
  - Shexy.batch

