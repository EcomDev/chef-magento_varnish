magento_varnish_vmod node[:test][:name] do
  repository node[:test][:repository]
  revision node[:test][:revision] if node[:test][:revision]
end