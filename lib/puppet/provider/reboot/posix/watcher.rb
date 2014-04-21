class Watcher
  require 'tempfile'

  attr_reader :pid, :timeout, :command

  def initialize(argv)
    @pid = argv[0].to_i
    @timeout = argv[1].to_i
    @command = argv[2]

    # this should go to eventlog
    @path = Tempfile.new('puppet-reboot-watcher').path
    File.open(@path, 'w') {|fh| }
  end

  def agent_stopped?(pid)
    while begin
      Process.getpgid(pid)
      true
    rescue Errno::ESRCH
      false
    end
  end

  def waitpid
    # TODO: implement support for timeout
    sleep(1) until agent_stopped(@pid)
    :completed
  end

  def execute
    case waitpid
    when :completed
      log_message("Process completed; executing '#{command}'.")
      system(command)
    when :timeout
      log_message("Timed out waiting for process to exit; reboot aborted.")
    else
      log_message("Failed to wait on the process (#{get_last_error}); reboot aborted.")
    end
  end

  def log_message(message)
    File.open(@path, 'a') { |fh| fh.puts(message) }
  end
end

if __FILE__ == $0
  watcher = Watcher.new(ARGV)
  begin
    watcher.execute
  rescue Exception => e
    watcher.log_message(e.message)
    watcher.log_message(e.backtrace)
  end
end
