Ohai.plugin(:VarnishConfig) do
  provides 'varnish_config'

  def get_version_branch()
    lines = execute_varnish('-V')[:stderr].split("\n")
    lines.each do |line|
      case line
        when /^varnishd\s+\((varnish-\S+)\s/
          return $1
      end
    end
  end

  def get_version()
    branch = get_version_branch
    if branch.is_a?(::String)
      return branch.gsub(/^varnish-/, '')
    end
  end

  def execute_varnish(flags = '')
    @exec_varnish_data ||= {}
    return @exec_varnish_data[flags] if @exec_varnish_data[flags]
    status, stdout, stderr = run_command(:no_status_check => true, :command => "/usr/sbin/varnishd #{flags}")
    return @exec_varnish_data[flags] = {
        status: status,
        stdout: stdout,
        stderr: stderr
    }
  end

  collect_data(:linux) do
    varnish_config Mash.new
    varnish_config[:version] = get_version
    varnish_config[:version_branch] = get_version_branch
  end
end