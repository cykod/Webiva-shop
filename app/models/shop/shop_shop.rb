

class Shop::ShopShop < DomainModel
  has_many :shop_products, :class_name => 'Shop::ShopProduct'
  has_many :shop_product_features, :class_name => 'Shop::ShopProductFeature'
  validates_presence_of :name, :abr

  content_node_type :shop, "Shop::ShopProduct", :content_name => :name, :url_field => Proc.new { |shp| Shop::AdminController.module_options.category_in_url ? :category_url : :url }

  def self.create_default_shop
    self.create(:name => 'Default Shop'.t,:abr => 'Shop')
  end

  def self.default_shop
    self.find(:first,:order => :id) || self.create_default_shop
  end

  def content_admin_url(shop_product_id)
    { :controller => '/shop/catalog', :action => 'edit', :path => [ shop_product_id ],
      :title => 'Edit Product' }
  end

  def content_type_name 
    "Shop"
  end

end
