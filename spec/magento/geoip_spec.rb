require 'spec_helper'

describe 'magento_varnish::geoip' do
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

  platform({family: :debian}, true)  do |name, version|
    context 'In ' + name + ' ' + version +  ' systems it' do
      before (:each) do
        chef_run_proxy.options(platform: name, version: version)
      end

      it 'installs geoip packages' do
        expect(chef_run).to install_package('libgeoip-dev')
      end
    end
  end

  platform({family: :rhel}, true) do |name, version|
    context 'In ' + name + ' ' + version +  ' systems it' do
      before (:each) do
        chef_run_proxy.options(platform: name, version: version)
      end

      it 'installs geoip packages' do
        expect(chef_run).to install_package('GeoIP-devel')
      end
    end
  end

  it 'installs libvmod-geoip' do
    expect(chef_run).to install_magento_varnish_vmod('libvmod_geoip').with(
                            repository: 'https://github.com/lampeh/libvmod-geoip.git'
                        )
  end


end