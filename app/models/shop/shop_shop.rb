

class Shop::ShopShop < DomainModel
  has_many :shop_products, :class_name => 'Shop::ShopProduct'
  validates_presence_of :name

  content_node_type :shop, "Shop::ShopProduct", :content_name => :name, :url_field => :url

  def self.create_default_shop
    self.create(:name => 'Default Shop')
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
