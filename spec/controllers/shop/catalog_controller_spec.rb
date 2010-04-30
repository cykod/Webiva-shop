require  File.expand_path(File.dirname(__FILE__)) + "/../../../../../../spec/spec_helper"

add_factory_girl_path(File.join(File.expand_path(File.dirname(__FILE__)),"..",".."))

describe Shop::CatalogController do 

   transaction_reset
#  reset_domain_tables :shop_products,:shop_product_classes,:shop_product_options, :shop_product_features, :shop_product_files, :shop_product_options, :shop_product_prices 

  integrate_views

  before(:each) do 
    test_activate_module(:shop,:currency => "USD")
    mock_editor
    @class1 = Factory.create(:shop_product_class)
    @shop = Shop::ShopShop.default_shop
    @products = 5.times.map { Factory.create(:shop_product, :shop_product_class_id => @class1.id, :shop_shop_id => @shop.id) }
  end

  it "should display the index page" do
    get :index
    response.should render_template('index')
  end

  it 'should display the catalog table' do
    controller.should handle_active_table(:product_table) do |args|
      post :catalog_table, args      
    end
  end

  it "should be display the edit product page for an existing product" do
    get :edit, :path => [ @products[1].id.to_s ]
    response.should render_template('edit')
  end

  it "should be able to display the edit product page for a new product" do
    get :edit, :path => []
    response.should render_template('edit')
  end

  it "should be able to update a product" do
    # set all the text attributes on a hash to make it easier to test
    text_attr =  { :name => 'Updated Product Name', 
                    :sku => 'UPDATED-SKU',
                    :brand => "Updated Brand",
                    :detailed_description => "<p>Detailed desc goes here</p>",
                    :internal_sku => "UPDATED-I-SKU",
                    :dimensions => "12x43x1million",
                    :unit_quantity => "1 box",
                    :name_2 => "Updated line two"
                   }
   post :edit, :path => [ @products[1].id.to_s ], 
      :product => text_attr.merge(:shippable => '',:weight => 12.5, :price_values => { 'USD' => "41.00" })
   @products[1].reload
   text_attr.each do |atr,val|
     @products[1].send(atr).should == val
   end
   @products[1].shippable.should be_false
   @products[1].weight.should == 12.5
   @products[1].unit_cost("USD").should == 41.00  
   response.should redirect_to :action => "index"
  end


  it "should be able to create a product" do
    assert_difference "Shop::ShopProduct.count", 1 do 
      post :edit, :path => [ ], 
        :product => { :name => 'New Product Name', 
          :shippable =>  '1',
          :sku => 'NEW-SKU',  
          :price_values => { 'USD' => "12.06" }
      }
    end
    @product = Shop::ShopProduct.find(:last)
    @product.reload
    @product.name.should == 'New Product Name'
    @product.shippable.should be_true
    @product.sku.should == 'NEW-SKU'
    @product.get_unit_cost("USD").should == 12.06
    response.should redirect_to :action => "index"
  end


  it "should be able to pull the options for a product" do
    get :update_options, :product_class_id => @class1.id.to_s
    response.should render_template("_options")
  end

  it "should be able to add a feature in" do
   get :add_feature, :feature_handler => "shop/features/profile_price_adjustment"
   response.should render_template("_feature")
  end

  it "should render nothing if it's an invalid feature" do
    get :add_feature, :feature_handler => "/shop/features/invalid_feature"
   response.should_not render_template("_feature")
  end

  it "should display the import template" do
    get :import
    response.should render_template("import")
  end

  it "should run the product import" do
    importer_mock = mock(:valid? => true)
    importer_mock.should_receive(:run_import).and_return([])
    Shop::Utility::ImportCatalog.should_receive(:new).and_return(importer_mock)
    post :import, :import => "Dummy"
    response.should render_template("imported")
  end

end
