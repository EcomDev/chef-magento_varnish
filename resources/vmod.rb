actions :install

attribute :name, :kind_of => [String, Symbol], :name_attribute => true # Name of the database

attribute :repository,  :kind_of => String, :required => true # Git repository of VMOD
attribute :revision,  :kind_of => [String, NilClass], :default => nil # Git branch of VMOD
attribute :src, :kind_of => [String, NilClass], :default => nil # Varnish sources location, by default is taken from magento/varnish/src_dir
attribute :path, :kind_of => [String, NilClass], :default => nil

def initialize(*args)
  super
  @action = :install
end