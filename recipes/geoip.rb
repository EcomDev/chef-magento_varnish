
packages = value_for_platform_family(
    debian: %w(libgeoip-dev),
    rhel: %w(GeoIP-devel),
    default: []
)

if rhel?
  include_recipe 'yum-epel'
end

packages.each do |pkg|
  package pkg
end

magento_varnish_vmod 'libvmod_geoip' do
  repository 'https://github.com/lampeh/libvmod-geoip.git'
end