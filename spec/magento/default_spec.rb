require 'spec_helper'

describe 'magento_varnish::default' do
  let(:chef_run) do
    chef_run_proxy.instance(platform: 'ubuntu', version: '12.04').converge(described_recipe)
  end

  before(:each) do
    allow_recipe('apt', 'varnish::default')
  end

  def node(&block)
    chef_run_proxy.block(:initialize) do |runner|
      if block.arity == 1
        block.call(runner.node)
      end
    end
  end

  it 'includes varnish recipe' do
    expect(chef_run).to include_recipe('varnish::default')
  end

  it 'includes openssl::upgrade recipe to keep our servers up to date' do
    expect(chef_run).to include_recipe('openssl::upgrade')
  end

  it 'creates a secret key file with secure password' do
    allow_any_instance_of(Chef::Recipe).to receive(:secure_password).and_return('password_key')
    expect(chef_run).to render_file(chef_run.node[:varnish][:secret_file]).with_content('password_key')
  end

  it 'does not create a secret key file if it is already exists' do
    stub_file_exists('varnish/secret')

    node do |n|
      n.set[:varnish][:secret_file] = 'varnish/secret'
    end

    expect(chef_run).not_to render_file('varnish/secret')
  end

  it 'downloads remote file of device detect library' do
    expect(chef_run).to create_remote_file(
                            ::File.join(chef_run.node[:varnish][:dir], 'devicedetect.vcl')
                        ).with(source: chef_run.node[:magento][:varnish][:device_detect_file])
  end

  it 'adds a notifier for device detect file' do
    remote_file = chef_run.remote_file(::File.join(chef_run.node[:varnish][:dir], 'devicedetect.vcl'))

    expect(remote_file).to notify('service[varnish]').to(:reload).delayed
    expect(remote_file).to notify('service[varnishlog]').to(:reload).delayed
  end

  it 'should set varnish VCL attribute to Magento one' do
    expect(chef_run.node[:varnish][:vcl_conf]).to eq('default.vcl')
  end

  it 'should set varnish VCL port to a value from magento/varnish/port' do
    expect(chef_run.node[:varnish][:listen_port]).to eq(chef_run.node[:magento][:varnish][:port])
  end

  it 'should set varnish VCL template and cookbook attributes' do
    expect(chef_run.node[:varnish][:vcl_source]).to eq('varnish.vcl.erb')
    expect(chef_run.node[:varnish][:vcl_cookbook]).to eq('magento_varnish')
  end

  it 'renders a magento varnish VCL file' do
    expect(chef_run).to render_file(::File.join(chef_run.node[:varnish][:dir], chef_run.node[:varnish][:vcl_conf]))
                        .with_content(
                          ::File.read(::File.join(::File.dirname(__FILE__), 'expected/varnish.vcl'))
                        )
  end

  it 'renders a magento varnish VCL file with GeopIP features' do
    node do |n|
      n.set[:magento][:varnish][:geoip] = true
      n.set[:magento][:varnish][:geoip_country_codes] = %w(US UA ES)
    end

    expect(chef_run).to render_file(::File.join(chef_run.node[:varnish][:dir], chef_run.node[:varnish][:vcl_conf]))
                        .with_content(
                          ::File.read(::File.join(::File.dirname(__FILE__), 'expected/varnish.geoip.vcl'))
                        )
  end

  it 'renders a magento varnish VCL file with additional options' do
    node do |n|
      n.set[:magento][:varnish][:ip_local] = %w(192.168.6.1)
      n.set[:magento][:varnish][:ip_admin] = %w(192.168.5.1)
      n.set[:magento][:varnish][:ip_refresh] = %w(192.168.4.1)
      n.set[:magento][:varnish][:hide_varnish_header] = %w(X-Header-Additional)
    end

    expect(chef_run).to render_file(::File.join(chef_run.node[:varnish][:dir], chef_run.node[:varnish][:vcl_conf]))
                        .with_content(
                            ::File.read(::File.join(::File.dirname(__FILE__), 'expected/varnish.options.vcl'))
                        )
  end

  it 'adds a notifier for template of magento varnish vcl' do
    template = chef_run.template(::File.join(chef_run.node[:varnish][:dir], chef_run.node[:varnish][:vcl_conf]))

    expect(template).to notify('service[varnish]').to(:reload).delayed
    expect(template).to notify('service[varnishlog]').to(:reload).delayed
  end

  it 'creates varnish configuration directory' do
    expect(chef_run).to create_directory(chef_run.node[:varnish][:dir])
  end

  it 'does not create varnish configuration directory if it already exists' do
    node do |n|
      n.set[:varnish][:dir] = '/etc/varnish'
    end

    stub_file_exists('/etc/varnish')
    expect(chef_run).to create_directory(chef_run.node[:varnish][:dir])
  end

  it 'adds varnish cookbook to ohai plugins' do
    expect(chef_run.node[:ohai][:plugins]).to include({magento_varnish: 'plugins'})
  end

  it 'includes git recipe' do
    expect(chef_run).to include_recipe('git::default')
  end

  it 'includes geoip recipe if attribute is set' do
    node do |n|
      n.set[:magento][:varnish][:geoip] = true
    end

    expect(chef_run).to include_recipe('magento_varnish::geoip');
  end

  it 'installs libvmod-header' do
    expect(chef_run).to install_magento_varnish_vmod('libvmod_header').with(
                          repository: 'https://github.com/varnish/libvmod-header.git'
                        )
  end

  it 'installs libvmod-cookie' do
    expect(chef_run).to install_magento_varnish_vmod('libvmod_cookie').with(
                            repository: 'https://github.com/lkarsten/libvmod-cookie.git'
                        )
  end

  it 'installs libvmod-querystring' do
    expect(chef_run).to install_magento_varnish_vmod('libvmod_querystring').with(
                            repository: 'https://github.com/Dridi/libvmod-querystring.git'
                        )
  end

  it 'install libvmod-var ' do
    expect(chef_run).to install_magento_varnish_vmod('libvmod_var').with(
                            repository: 'https://github.com/varnish/libvmod-var.git'
                        )
  end

  it 'install libvmod-ipcast ' do
    expect(chef_run).to install_magento_varnish_vmod('libvmod_ipcast').with(
                            repository: 'https://github.com/lkarsten/libvmod-ipcast.git'
                        )
  end

  it 'starts varnish server after the code is started' do
    expect(chef_run).to run_ruby_block('varnish_services_start');
  end
end