include_recipe 'openssl::upgrade'

directory node[:varnish][:dir] do
  action :create
  user 'root'
  group 'root'
end

devicedetect = ::File.join(node[:varnish][:dir], 'devicedetect.vcl')

remote_file devicedetect do
  source node[:magento][:varnish][:device_detect_file]

  notifies(:reload, {:service => 'varnish'}, :delayed)
  notifies(:reload, {:service => 'varnishlog'}, :delayed)
  not_if { ::File.exists?(devicedetect) }
end

node.default[:varnish][:listen_port] = node[:magento][:varnish][:port]
node.default[:varnish][:vcl_source] = 'varnish.vcl.erb'
node.default[:varnish][:vcl_cookbook] = 'magento_varnish'

varnish_secret = secure_password

file node[:varnish][:secret_file] do
  content varnish_secret
  not_if { ::File.exists?(node[:varnish][:secret_file]) }
end

variables = Mash.new node[:magento][:varnish].to_hash

variables[:backend].each do |key, value|
  while value.is_a?(String) || value.is_a?(Symbol) do
    value = variables[:backend][value.to_s]
  end

  variables[:backend][key] = value
end

variables[:balancer].map! {|v| v.to_s }
variables[:balancer].keep_if { |v| variables[:backend].key?(v) }

variables[:ip_local_regexp] = ['127.0.0.1']
variables[:ip_admin_regexp] = ['127.0.0.1']
variables[:ip_refresh_regexp] = ['127.0.0.1']

variables[:ip_local].each { |ip| variables[:ip_local_regexp] << ip }
variables[:ip_admin].each { |ip| variables[:ip_admin_regexp] << ip }
variables[:ip_refresh].each { |ip| variables[:ip_refresh_regexp] << ip }

variables[:ip_admin_regexp].map! { |v| Regexp.escape(v) }
variables[:ip_local_regexp].map! { |v| Regexp.escape(v) }
variables[:ip_refresh_regexp].map! { |v| Regexp.escape(v) }


include_recipe 'varnish::default'

template = resources(:template => ::File.join(node[:varnish][:dir], node[:varnish][:vcl_conf]))
template.variables(variables)
template.notifies(:reload, {:service => 'varnishlog'}, :delayed)

varnishservice = resources(:service => 'varnish')
varnishservice.action :enable
varnishlogservice = resources(:service => 'varnishlog')
varnishlogservice.action :enable

include_recipe 'git::default'

magento_varnish_vmod 'libvmod_header' do
  repository 'https://github.com/varnish/libvmod-header.git'
end

magento_varnish_vmod 'libvmod_cookie' do
  repository 'https://github.com/lkarsten/libvmod-cookie.git'
end

magento_varnish_vmod 'libvmod_querystring' do
  repository 'https://github.com/Dridi/libvmod-querystring.git'
end

magento_varnish_vmod 'libvmod_var' do
  repository 'https://github.com/varnish/libvmod-var.git'
end

magento_varnish_vmod 'libvmod_ipcast' do
  repository 'https://github.com/lkarsten/libvmod-ipcast.git'
end

if variables[:geoip]
  include_recipe 'magento_varnish::geoip'
end

ruby_block 'varnish_services_start' do
  block do
    varnishservice.run_action(:start)
    varnishlogservice.run_action(:start)
  end
end