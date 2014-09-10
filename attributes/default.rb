namespace 'magento', precedence: default do
  namespace 'varnish', precedence: default do
    port 80

    backend node1: { ip: '127.0.0.1', port: '8080', weight: '1' },
            admin: 'node1'

    probe '/status'
    probe_options interval: '30s',
                  timeout: '0.3s',
                  window: '8',
                  threshold: '3',
                  initial: '3',
                  expected_response: '200'

    balanced_backend_options first_byte_timeout: '300s',
                             connect_timeout: '5s',
                             between_bytes_timeout: '2s'

    non_balanced_backend_options first_byte_timeout: '6000s',
                                 connect_timeout: '1000s',
                                 between_bytes_timeout: '2s'

    balancer [:node1]

    device_detect_file 'https://raw.githubusercontent.com/willemk/varnish-mobiletranslate/master/mobile_detect.vcl'

    segment_cookie 'segment_checksum'
    admin_path 'admin'
    ip_local Array.new
    ip_admin Array.new
    ip_refresh Array.new

    hide_varnish_header Array.new

    git_source 'git://git.varnish-cache.org/varnish-cache'
    src_dir '/usr/src/varnish-src'
    prefix '/usr'
    vmod_dir value_for_platform_family(
                 :rhel => '/usr/lib64/varnish/vmods',
                 :default => '/usr/lib/varnish/vmods'
             )
    geoip false
    geoip_country_codes Array.new
  end
end

default[:ohai][:plugins][:magento_varnish] = 'plugins'
default[:varnish][:version] = '3.0'