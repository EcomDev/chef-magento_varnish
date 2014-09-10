
# Support whyrun
def whyrun_supported?
  true
end


action :install do
  run_context.include_recipe('magento_varnish::default')
  run_context.include_recipe('magento_varnish::vmod')

  src_dir = node[:magento][:varnish][:src_dir]
  vmod_dir = node[:magento][:varnish][:vmod_dir]

  if new_resource.src
    src_dir = new_resource.src
  end

  vmod_src_dir = "#{Chef::Config[:file_cache_path]}/varnish-vmod-#{new_resource.name}"

  git vmod_src_dir do
    repository new_resource.repository
    revision new_resource.revision if new_resource.revision
    not_if { ::File.exists?(::File.join(vmod_dir, new_resource.name + '.so')) }
  end

  bash "install_vmod_#{new_resource.name}" do
    cwd vmod_src_dir
    code ['./autogen.sh',
          './configure VARNISHSRC=' + src_dir + ' VMODDIR=' + vmod_dir,
          'make',
          'make install'].join("\n")
    not_if { ::File.exists?(::File.join(vmod_dir, new_resource.name + '.so')) }
  end
end