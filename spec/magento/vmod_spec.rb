require 'spec_helper'

describe 'magento_varnish::vmod' do
  let(:chef_run) do
    chef_run_proxy.instance.converge(described_recipe)
  end

  def node(&block)
    chef_run_proxy.block(:initialize) do |runner|
      if block.arity == 1
        block.call(runner.node)
      end
    end
  end

  it 'does not include default recipe' do
    expect(chef_run).not_to include_recipe('magento_varnish::default')
  end

  it 'sets default varnish source git repo' do
    expect(chef_run.node[:magento][:varnish][:git_source]).to eq('git://git.varnish-cache.org/varnish-cache')
  end

  it 'sets varnish source link location' do
    expect(chef_run.node[:magento][:varnish][:src_dir]).to eq('/usr/src/varnish-src')
  end

  it 'downloads source code for installed varnish version' do
    node do |n|
      n.set[:varnish_config][:version_branch] = 'varnish-3.0.2'
    end

    expect(chef_run).to sync_git("#{Chef::Config[:file_cache_path]}/varnish_source")
                        .with(repository: 'git://git.varnish-cache.org/varnish-cache',
                              revision: 'varnish-3.0.2')
  end

  it 'symlinks a source code directory to a /usr/src/varnish-src branch' do
    node do |n|
      n.set[:varnish_config][:version_branch] = 'varnish-3.0.2'
    end

    expect(chef_run).to create_link('/usr/src/varnish-src')
                        .with(to: "#{Chef::Config[:file_cache_path]}/varnish_source")
  end

  it 'comiples varnish sources' do
    expect(chef_run).to run_bash('compile_varnish_source').with(
                            cwd: "#{Chef::Config[:file_cache_path]}/varnish_source",
                            code: [
                                './autogen.sh',
                                './configure --prefix=' + chef_run.node[:magento][:varnish][:prefix],
                                'make'
                            ].join("\n")
                        )
  end

  it 'includes ohai default recipe' do
    expect(chef_run).to include_recipe('ohai::default')
  end

  it 'checks varnish version installment' do
    node do |n|
      n.set[:varnish_config][:version_branch] = 'varnish-3.0.2'
    end

    allow_recipe('ohai::default')

    chef_run_proxy.options(step_into: ['ruby_block'])

    expect(chef_run).to run_ruby_block('check_vagrant_installment')
  end

  it 'rises an exception if version is not available' do
    allow_recipe('ohai::default')

    chef_run_proxy.options(step_into: ['ruby_block'])

    expect { chef_run }.to raise_error(RuntimeError)
  end

  platform({family: :debian}, true)  do |name, version|
    context 'In ' + name + ' ' + version +  ' systems it' do
      before (:each) do
        chef_run_proxy.options(platform: name, version: version)
      end

      it 'installs auto tools' do
        expect(chef_run).to install_package('autoconf')
        expect(chef_run).to install_package('automake1.11')
        expect(chef_run).to install_package('autotools-dev')
        expect(chef_run).to install_package('groff-base')
      end

      it 'installs make' do
        expect(chef_run).to install_package('make')
      end

      it 'installs libraries' do
        expect(chef_run).to install_package('libedit-dev')
        expect(chef_run).to install_package('libncurses-dev')
        expect(chef_run).to install_package('libpcre3-dev')
        expect(chef_run).to install_package('libtool')
      end

      it 'installs pkg-config' do
        expect(chef_run).to install_package('pkg-config')
      end

      it 'installs python docutils' do
        expect(chef_run).to install_package('python-docutils')
      end
    end
  end

  platform({family: :rhel}, true) do |name, version|
    context 'In ' + name + ' ' + version +  ' systems it' do
      before (:each) do
        chef_run_proxy.options(platform: name, version: version)
      end

      it 'installs auto tools' do
        expect(chef_run).to install_package('automake')
        expect(chef_run).to install_package('autoconf')
        expect(chef_run).to install_package('groff')
      end

      it 'installs libraries' do
        expect(chef_run).to install_package('libedit-devel')
        expect(chef_run).to install_package('libtool')
        expect(chef_run).to install_package('ncurses-devel')
        expect(chef_run).to install_package('pcre-devel')
      end

      it 'installs pkg-config' do
        expect(chef_run).to install_package('pkgconfig')
      end

      it 'installs python docutils' do
        expect(chef_run).to install_package('python-docutils')
      end
    end
  end


end