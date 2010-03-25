require  File.expand_path(File.dirname(__FILE__)) + "/../../../../../../spec/spec_helper"

add_factory_girl_path(File.join(File.expand_path(File.dirname(__FILE__)),"..",".."))


describe Shop::PageRenderer, :type => :controller do
  
  controller_name :page

  integrate_views

  reset_domain_tables :shop_products

  describe 

  def product_listing_renderer(opts={})
     build_renderer('/shop', '/shop/page/product_listing', {}, opts)
  end
 
  before(:each) do
    @products = (0..10).map { |n| Factory.create(:shop_product) }
  end

  it "should be able to display a list of products" do
    @rnd = product_listing_renderer

    renderer_get @rnd
  end
  
end

