require  File.expand_path(File.dirname(__FILE__)) + "/../../../../../../spec/spec_helper"


require  File.expand_path(File.dirname(__FILE__)) + '/shop_order_process_spec'


describe Shop::ShopCoupon do
   include ShopOrderProcessHelper # Get some help from the shop_order_process_spec functionality

 reset_domain_tables :shop_products, :shop_orders, :shop_order_items, :shop_payment_processors, :shop_product_prices,
                      :end_users,:end_user_address, :shop_cart_products, :shop_coupon, :end_user_tags


  before(:each) do
    @shirt_cost = 14.95
    @shirt = Shop::ShopProduct.create(:name => 'A Shirt', :price_values => {'USD' => @shirt_cost})
    
    @coat_cost = 18.88
    @coat =  Shop::ShopProduct.create(:name => 'A Coat', :price_values => { 'USD' => @coat_cost})

    @cart_session = []
    @cart = Shop::ShopSessionCart.new(@cart_session,'USD')

  end
  
  def coupon_factory(opts)
    Shop::ShopCoupon.create(
          { :internal_name => 'test', :cart_name=>'cart test',:code => 'TEST1212'}.merge(opts) 
          
          )
  
  end
  

  it "should be able to add an amount coupon to a cart and have the cart price be correct" do
    @cart.add_product(@shirt,2)
    @cart.add_product(@coat,1)
    
    @cart.total.should == (@shirt_cost * 2 + @coat_cost)
    @coupon = coupon_factory(:discount_type => 'amount',:discount_amount => 6.00)
    @cart.add_product(@coupon,1)
    
    @cart.total.should == (@shirt_cost * 2 + @coat_cost - 6.00) # Make sure the total has the coupon discount amount
  end
  
  it "should be able to add a percentage coupon to a cart and have the cart price be correct" do
    @cart.add_product(@shirt,2)
    @cart.add_product(@coat,1)
    
    @cart.total.should == (@shirt_cost * 2 + @coat_cost)
    @coupon = coupon_factory(:discount_type => 'percentage',:discount_percentage => 10.00)
    @cart.add_product(@coupon,1)
    
    # Make sure the total has the coupon discount amount - should be - 10% of the total, rounded
    @cart.total.should == (@shirt_cost * 2 + @coat_cost) - ((@shirt_cost * 2 + @coat_cost) * 0.10).round(2) 
  end
  
  it "shouldn't be added to a cart if it's not active" do 
    @cart.add_product(@shirt,2)
    @cart.add_product(@coat,1)
    
    @coupon = coupon_factory(:discount_type => 'percentage',:discount_percentage => 10.00,:active => false)
    @cart.add_product(@coupon,1)
    @cart.validate_cart!
    @cart.products_count.should == 2
    @cart.total.should == (@shirt_cost * 2 + @coat_cost)
  end
  
  it "shouldn't be added to a cart if it's expired" do
    @cart.add_product(@shirt,2)
    @cart.add_product(@coat,1)
    
    @coupon = coupon_factory(:discount_type => 'percentage',:discount_percentage => 10.00,:active => true,:expires_at => (Time.now-10.minutes))
    @cart.add_product(@coupon,1)
    @cart.validate_cart!
    @cart.products_count.should == 2
    @cart.total.should == (@shirt_cost * 2 + @coat_cost)
  end
  
  it "should only apply a discount to the affected products and remove itself if it doesn't apply" do
    @cart.add_product(@shirt,3)
    @cart.add_product(@coat,12)
    
    @coupon = coupon_factory(:discount_type => 'percentage',:discount_percentage => 10.00, :shop_product_ids => [ @coat.id ], :all_products => false )
    @cart.add_product(@coupon,1)
    @cart.validate_cart!
    @cart.products_count.should == 3
    
    # Make sure the total has the coupon discount amount - should be - 10% of the total, rounded
    @cart.total.should be_close((@shirt_cost * 3 + @coat_cost * 12) - ((@coat_cost * 12) * 0.10).round(2),0.001)
    
    # make sure coupon removes itself
    @cart.edit_product(@coat,0)
    @cart.validate_cart!
    @cart.products_count.should == 1
  end
  
  it "shouldn't let you use the same coupon twice" do
    create_test_payment_processor # Get us a @payment_processor
    create_test_user # Get the @user variable
    @cart = Shop::ShopUserCart.new(@user,'USD')
  
    @cart.add_product(@shirt,3)
    @cart.add_product(@coat,12)
    
    @coupon = coupon_factory(:discount_type => 'percentage',:discount_percentage => 10.00,:active => true, :one_time => true)
    @cart.add_product(@coupon,1)
    
    @cart.validate_cart!
    @cart.products_count.should == 3
    @order = create_order(@cart)
    @transaction = @order.authorize_payment(:remote_ip => '127.0.0.1' )    
    
    @transaction.should be_success
    @order.state.should == 'authorized'
    
    @new_cart = Shop::ShopUserCart.new(@user,'USD')
    @new_cart.add_product(@shirt,3)
    @new_cart.add_product(@coat,12)
    
    @new_cart.add_product(@coupon,1)
    @new_cart.validate_cart!
    
    @new_cart.products_count.should == 2
  end    
  
  it "should only allow tagged users to use the coupon" do
    create_test_user # Get the @user variable
    @cart = Shop::ShopUserCart.new(@user,'USD')
  
    @cart.add_product(@shirt,3)
    @cart.add_product(@coat,12)
    
    @coupon = coupon_factory(:discount_type => 'percentage',:discount_percentage => 10.00,:active => true, :one_time => true,:tag => 'Coupontag')
    @cart.add_product(@coupon,1)

    @cart.validate_cart!
    @cart.products_count.should == 2
    
    @user.tag_names_add('Coupontag')

    @user.reload

    @cart = Shop::ShopUserCart.new(@user,'USD')
    @cart.add_product(@shirt,3)
    @cart.add_product(@coat,12)

    @cart.add_product(@coupon,1)
    
    @cart.validate_cart!
    @cart.products_count.should == 3
    
  end  
  
  it "should only allow first_order coupons to be used on the first order" do
    create_test_payment_processor # Get us a @payment_processor
    create_test_user # Get the @user variable
    @cart = Shop::ShopUserCart.new(@user,'USD')
  
    @cart.add_product(@shirt,3)
    @cart.add_product(@coat,12)
    @first_coupon = coupon_factory(:discount_type => 'percentage',:discount_percentage => 10.00,:active => true, :one_time => false,:first_order => true)
    @cart.add_product(@first_coupon,1)
    @cart.validate_cart!
    @cart.products_count.should == 3
    
    @order = create_order(@cart)
    @transaction = @order.authorize_payment(:remote_ip => '127.0.0.1' )    
    
    @transaction.should be_success
    @order.state.should == 'authorized'
    

    @new_cart = Shop::ShopUserCart.new(@user,'USD')
    @new_cart.add_product(@shirt,3)
    @new_cart.add_product(@coat,12)
    
    @second_coupon = coupon_factory(:discount_type => 'percentage',:discount_percentage => 10.00,:active => true, :one_time => false,:first_order => true)
    @new_cart.add_product(@second_coupon,1)
    
    @new_cart.validate_cart!
    @new_cart.products_count.should == 2

  end  
end
