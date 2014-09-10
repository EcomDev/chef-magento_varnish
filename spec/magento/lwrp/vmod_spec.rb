require 'spec_helper'

describe 'magento_varnish_test::install_vmod' do
  let(:chef_run) do
    chef_run_proxy.instance(step_into: ['magento_varnish_vmod']) do |node|
      node.set[:test][:name] = 'test'
      node.set[:test][:repository] = 'repository'
    end.converge(described_recipe)
  end

  def node(&block)
    chef_run_proxy.block(:initialize) do |runner|
      if block.arity == 1
        block.call(runner.node)
      end
    end
  end

  it 'installs a test vmod' do
    expect(chef_run).to install_magento_varnish_vmod('test')
  end

  it 'automatically includes varnish and varnish vmod recipes' do
    expect(chef_run).to include_recipe('magento_varnish::default')
    expect(chef_run).to include_recipe('magento_varnish::vmod')
  end

  it 'syncs git repository of the vmod' do
    node do |n|
      n.set[:test][:repository] = 'git@test.com:project.git'
    end

    expect(chef_run).to sync_git("#{Chef::Config[:file_cache_path]}/varnish-vmod-test")
                         .with(repository: 'git@test.com:project.git')
  end

  it 'syncs git repository with revision, if specified' do
    node do |n|
        n.set[:test][:repository] = 'git@test.com:project.git'
        n.set[:test][:revision] = 'v1.0.1'
    end

    expect(chef_run).to sync_git("#{Chef::Config[:file_cache_path]}/varnish-vmod-test")
                        .with(
                            repository: 'git@test.com:project.git',
                            revision: 'v1.0.1'
                        )
  end

  it 'installs vmod from source' do
    node do |n|
      n.set[:test][:repository] = 'git@test.com:project.git'
      n.set[:test][:revision] = 'v1.0.1'
    end

    expect(chef_run).to run_bash('install_vmod_test').with(
                          cwd: "#{Chef::Config[:file_cache_path]}/varnish-vmod-test",
                          code: [
                              './autogen.sh',
                              './configure VARNISHSRC=' + chef_run.node[:magento][:varnish][:src_dir] +
                                  ' VMODDIR=' + chef_run.node[:magento][:varnish][:vmod_dir],
                              'make',
                              'make install'
                          ].join("\n")
                        )
  end

  it 'does not install vmod if vmod.so is in place alraedy' do
    node do |n|
      n.set[:test][:repository] = 'git@test.com:project.git'
      n.set[:test][:revision] = 'v1.0.1'
    end

    stub_file_exists('/usr/lib/varnish/vmods/test.so')

    expect(chef_run).not_to sync_git("#{Chef::Config[:file_cache_path]}/varnish-vmod-test")
    expect(chef_run).not_to run_bash('install_vmod_test')
  end
end