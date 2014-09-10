name             'magento_varnish'
maintainer       'Ivan Chepurnyi'
maintainer_email 'ivan.chepurnyi@ecomdev.org'
license          'GPLv3'
description      'Installs varnish adopted for Magento installments'
long_description 'Installs varnish adopted for Magento installments'
version          '0.1.0'

depends 'ecomdev_common'
depends 'openssl'
depends 'varnish'
depends 'ohai', '~> 2.0'
depends 'git'
depends 'yum-epel'

%w(ubuntu debian centos).each do |os|
  supports os
end