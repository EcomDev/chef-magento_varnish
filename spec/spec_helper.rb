require 'chefspec'
require 'chefspec/berkshelf'
require 'ecomdev/chefspec'

EcomDev::ChefSpec::Helpers::Platform.platform_path = File.dirname(__FILE__)
EcomDev::ChefSpec::Helpers::Platform.platform_file = 'platforms.json'

ChefSpec::Coverage.start!