require 'puppet/type'
require 'open3'

Puppet::Type.type(:reboot).provide :linux do
  confine :kernel => :linux
  defaultfor :kernel => :linux

  def self.shutdown_command
    # TODO: figure out where else Linux distros might keep this binary and
    # update accordingly.
    '/sbin/shutdown'
  end

  commands :shutdown => shutdown_command

  def self.instances
    []
  end

  def cancel_transaction
    Puppet::Application.stop!
  end

  def reboot
    if @resource[:apply] == :finished && @resource[:when] == :pending
      Puppet.warning("The combination of `when => pending` and `apply => finished` is not a recommended or supported scenario. Please only use this scenario if you know exactly what you are doing. The puppet agent run will continue.")
    end

    if @resource[:apply] != :finished
      cancel_transaction
    end

    shutdown_path = command(:shutdown)
    timeout = @resource[:timeout] == 0 ? 0 : [@resource[:timeout] / 60, 1].max

    shutdown_cmd = [shutdown_path, '-h', "+#{timeout}", "\"#{@resource[:message]}\""].join(' ')
    async_shutdown(shutdown_cmd)
  end

  def async_shutdown(shutdown_cmd)
    if Puppet[:debug]
      $stderr.puts(shutdown_cmd)
    end

    # execute a ruby process to shutdown after puppet exits
    watcher = File.join(File.dirname(__FILE__), 'posix', 'watcher.rb')
    if not File.exists?(watcher)
      raise ArgumentError, "The watcher program #{watcher} does not exist"
    end

    Puppet.debug("Launching 'ruby #{watcher}'")
    pid = Process.spawn("ruby '#{watcher}' #{Process.pid} #{@resource[:catalog_apply_timeout]} '#{shutdown_cmd}'")
    Puppet.debug("Launched process #{pid}")
  end
end
