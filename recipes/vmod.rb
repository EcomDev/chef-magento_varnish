include_recipe 'ohai::default'

packages = value_for_platform_family(
    debian: %w(autoconf automake1.11 autotools-dev groff-base make libedit-dev libncurses-dev libpcre3-dev libtool
               pkg-config python-docutils),
    rhel: %w(automake autoconf groff libedit-devel libtool ncurses-devel pcre-devel pkgconfig python-docutils),
    default: []
)

packages.each do |pkg_name|
  package pkg_name
end

ruby_block 'check_vagrant_installment' do
  block do
    resources(:ohai => 'custom_plugins').run_action(:reload)
    unless node.deep_fetch(:varnish_config, :version_branch)
      raise RuntimeError.new 'Cannot determine installed varnish version, aborting'
    end
  end
end

varnish_src = "#{Chef::Config[:file_cache_path]}/varnish_source"

git varnish_src do
  repository node[:magento][:varnish][:git_source]
  revision lazy { node.deep_fetch(:varnish_config, :version_branch) }
end

link node[:magento][:varnish][:src_dir] do
  to varnish_src
end

bash 'compile_varnish_source' do
  cwd varnish_src
  code ['./autogen.sh',
        './configure --prefix=' + node[:magento][:varnish][:prefix],
        'make'].join("\n")
  not_if { ::File.exists?(::File.join(varnish_src, 'bin', 'varnishtest', 'varnishtest')) }
end