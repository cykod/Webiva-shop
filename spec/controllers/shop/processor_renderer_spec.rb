require  File.expand_path(File.dirname(__FILE__)) + "/../../../../../../spec/spec_helper"

add_factory_girl_path(File.join(File.expand_path(File.dirname(__FILE__)),"..",".."))


describe Shop::ProcessorRenderer, :type => :controller do
  
  controller_name :page

  integrate_views

  reset_domain_tables  :shop_shops, :shop_products, :shop_categories, :shop_category_products, :shop_cart_products,:site_version, :site_nodes, :shop_orders, :configurations,:end_users,:end_user_addresses, :shop_regions, :shop_region_countries, :shop_payment_processors, :shop_shipping_categories, :shop_carriers

   let(:payment_info) do 
             {
              :shipping_category => @shipping_category.id.to_s,
              :selected_processor_id => @payment_processor.id.to_s,
              @payment_processor.id.to_s => {
               :type => 'standard',
               :card_type => 'visa',
               :cc => '1',
               :cvc => '1',
               :exp_month => '1',
               :exp_year => '2200'
             } }
        end


   let(:payment_processor) do
      prc = Shop::ShopPaymentProcessor.new(
            :name => 'Test Processor',
            :currency => 'USD',
            :payment_type => 'Credit Card',
            :options => { :force_failure => "no" },
            :active => true)
      prc.processor_handler = 'shop/test_payment_processor'
      prc.save
      prc
   end

  before do
    Configuration.set_config_model(Shop::AdminController.module_options(:shop_currency => 'USD'))
  end

  describe "Full Cart Paragraph" do
    renderer_builder "/shop/processor/full_cart"

    before do
      @products = (0..4).map { |n| Factory.create(:shop_product) } 
    end

    it "should be able to render the full cart paragraph" do
      @rnd = full_cart_renderer
      @rnd.should_render_feature(:shop_full_cart)
      renderer_get @rnd
    end

    it "should tell you that you have not products if your cart is empty" do
      @rnd = full_cart_renderer
      renderer_get @rnd

      response.should include_text('You currently have no products in your shopping cart')      
    end


    it "it should list products if you do have products for an anonymous user" do
       session[:shopping_cart] ||= []
       @cart = Shop::ShopSessionCart.new(session[:shopping_cart],'USD')
       @cart.add_product(@products[0],1)
       @cart.add_product(@products[2],175)
       @rnd = full_cart_renderer

       renderer_get @rnd

       response.should include_text(@products[0].name)
       response.should include_text(@products[2].name)
       response.should_not include_text(@products[1].name)
    end

    it "should list products if you do have products for a mock user" do
      @myself = mock_user
      @cart = Shop::ShopUserCart.new(@myself,"USD") 
      @cart.add_product(@products[3],1)
       @cart.add_product(@products[1],175)
       @rnd = full_cart_renderer

       renderer_get @rnd

       response.should include_text(@products[3].name)
       response.should include_text(@products[1].name)
       response.should_not include_text(@products[0].name)
    end

    it "should transfer products from session user to a  mock user" do
      session[:shopping_cart] ||= []
       @cart = Shop::ShopSessionCart.new(session[:shopping_cart],'USD')
       @cart.add_product(@products[0],1)
       @cart.add_product(@products[2],175)
       @myself = mock_user
       @rnd = full_cart_renderer


       assert_difference "Shop::ShopCartProduct.count", 2 do 
         renderer_get @rnd
       end

       response.should include_text(@products[0].name)
       response.should include_text(@products[2].name)
       response.should_not include_text(@products[1].name)
    end

    describe "Cart Actions" do 

      before do
        @myself = mock_user
        @cart = Shop::ShopUserCart.new(@myself,"USD") 
        @cart.add_product(@products[3],1)
        @cart.add_product(@products[1],175)
        @rnd = full_cart_renderer
      end

      it "should let your remove items" do 
        @item_hash, @opt_hash = @cart.products[0].quantity_hash

        assert_difference "Shop::ShopCartProduct.count", -1 do 
          renderer_post @rnd, "shop#{@rnd.paragraph.id}" => { :action => 'update_quantities',
                                                         :remove => { @item_hash => { @opt_hash => 1 }}}
        end
      end

      it "should let you update items" do 
        @item_hash, @opt_hash = @cart.products[0].quantity_hash

        renderer_post @rnd, "shop#{@rnd.paragraph.id}" => { :action => 'update_quantities',
                                                         :quantity => { @item_hash => { @opt_hash => "164" }}}

        @prd = @cart.products[0]
        @prd.reload
        @prd.quantity.should == 164
      end

      it "should let you try to add a coupon" do
        Shop::ShopCoupon.should_receive(:search_coupon).and_return(Shop::ShopCoupon.new)
        renderer_post @rnd, "shop#{@rnd.paragraph.id}" => { :action => 'coupon',:code => 'test_code' }
      end

    end
  end

  describe "Checkout Process" do
    renderer_builder "/shop/processor/checkout"

    before do
      @products = (0..4).map { |n| Factory.create(:shop_product) } 
      session[:shopping_cart] ||= []
      @cart = Shop::ShopSessionCart.new(session[:shopping_cart],'USD')
      @cart.add_product(@products[0],1)
      @cart.add_product(@products[2],175)
      UserClass.create_built_in_classes
    end

    let(:address_data) do
      { :first_name => "Svend", :last_name => "Karlson",
        :address => '123 Elm St',
        :city => "Boston",:state => "MA",
        :country => "United States", :zip => "02113"  }
    end

    describe "Login Register Page" do
      it "should take you right to the address page if you already have a user" do
        mock_user
        @rnd = checkout_renderer 
        @rnd.should_render_feature(:shop_checkout)
        renderer_get @rnd
        @rnd.should assign_to_feature(:page,'address')
      end

      it "should render the checkout feature with a login form if you don't" do
        @rnd = checkout_renderer 
        @rnd.should_render_feature(:shop_checkout)
        renderer_get @rnd
        @rnd.should assign_to_feature(:page,'login')
      end

      it "should create a new (unregistered) user and redirect to the address page if the user submits correcti info without a password" do
         @rnd = checkout_renderer 
         assert_difference "EndUser.count", 1 do 
           renderer_post @rnd, { :register => { :first_name => "Svend", :last_name => "Karlsonorino", :email => "svend@webiva.org" } }

         end
         @rnd.should redirect_paragraph("/shop/address")
         @user = EndUser.find(:last)
         @user.email.should == "svend@webiva.org"
         @user.registered.should be_false
         session[:shop_user_id].should == @user.id
      end

        it "should create a new (registered) user and redirect to the address page if the user submits correcti info with a password" do
         @rnd = checkout_renderer 
         assert_difference "EndUser.count", 1 do 
           renderer_post @rnd, { :register => { :first_name => "Svend", :last_name => "Karlsonorino", :email => "svend@webiva.org", :password => "bananana", :password_confirmation => "bananana" } }

         end
         @rnd.should redirect_paragraph("/shop/address")
         @user = EndUser.find(:last)
         @user.email.should == "svend@webiva.org"
         @user.registered.should be_true
      end

      it "should let you login if you already have an account" do 
        @rnd = checkout_renderer
        @user = EndUser.create(:email => "svender@webiva.org",:password=>"test",:password_confirmation=>"test",:registered => true)
        @rnd.should_receive(:process_login).with(@user)
        renderer_post @rnd, { :login => {:email => "svender@webiva.org", :password => "test" } }
        @rnd.should redirect_paragraph("/shop/address")
      end

      it "shouldn't let you login with an invalid password" do
        @rnd = checkout_renderer
        @user = EndUser.create(:email => "svender@webiva.org",:password=>"test",:password_confirmation=>"test")
        @rnd.should_render_feature(:shop_checkout)
        renderer_post @rnd, { :login => {:email => "svend@webiva.org", :password => "WRONG!" } }
      end

    end

    describe "Address Page" do

      it "should render the address page" do
        mock_user
        @rnd = checkout_renderer({},:input => [ :checkout_page, "address" ]) 
        @rnd.should_render_feature(:shop_checkout)
        renderer_get @rnd
        @rnd.should assign_to_feature(:page,'address')
      end

      it "should accept an address and redirect to the payment page" do
        mock_user
        @rnd = checkout_renderer({},:input => [ :checkout_page, "address" ]) 
        @address_data = { :first_name => "Svend", :last_name => "Karlson",
            :address => "123 Elm St",:city => "Boston",:state => "MA",
            :country => "United States", :zip => "02113"  }
        renderer_post @rnd, :shipping_address => @address_data, :same_address => true
        @rnd.should redirect_paragraph("/shop/payment")
      end

      it "should stay on the address page if there are errors in the address" do
        mock_user
        @rnd = checkout_renderer({},:input => [ :checkout_page, "address" ]) 
        @rnd.should_render_feature(:shop_checkout)
        address_data.merge!(:address => '')
        renderer_post @rnd, :shipping_address => address_data, :same_address => true
        @rnd.should assign_to_feature(:page,'address')
      end
    end
    
    describe "Order Processing" do 
      before do
        @myself = mock_user
        @myself.create_billing_address(address_data)
        @myself.create_shipping_address(address_data.merge(:city => 'Cambridge',:zip => '02139'))
      end
      describe "Payment Page" do

        it "should redirect to the address page if there isn't a valid country address" do
          @rnd = checkout_renderer({}, :input => [ :checkout_page, "payment" ])
          renderer_get @rnd
          @rnd.should redirect_paragraph('/shop/address')
        end

        describe "Valid address - no processors or shipping" do

          before do
            @region= Factory.create(:shop_region)
          end

          it "should render the checkout feature for the payment page" do
            @rnd = checkout_renderer({}, :input => [ :checkout_page, "payment" ])
            @rnd.should_render_feature(:shop_checkout)
            renderer_get @rnd
            @rnd.should assign_to_feature(:page,'payment')
          end

          it "should display the billing and shipping address" do
            @rnd = checkout_renderer({}, :input => [ :checkout_page, "payment" ])
            renderer_get @rnd
            response.should include_text("02139")
            response.should include_text("02113")
            response.should include_text("Cambridge")
            response.should include_text("Boston")
          end

          it "should have no payment or shipping options" do
            @rnd = checkout_renderer({}, :input => [ :checkout_page, "payment" ])
            renderer_get @rnd
            response.should include_text('no shipping options available')
            response.should include_text('no payment processors available')
          end
        end

        describe "Payment Checkout - valid processor and shipping setup" do
          before do
            # Creates a region and carrier
            @shipping_category = Factory.create(:shop_shipping_category)
            # Factory girl can't handle objects with an "options" attribute
            @payment_processor = payment_processor
          end

          it "should render the checkout page and ask for payment information" do
            @rnd = checkout_renderer({}, :input => [ :checkout_page, "payment" ])
            renderer_get @rnd
            response.should include_text(@shipping_category.name)
            response.should_not include_text('no payment processors available')
          end


          it "should create and start processing the order" do

            @rnd = checkout_renderer({}, :input => [ :checkout_page, "payment" ])
            assert_difference "Shop::ShopOrder.count" ,1 do 
              renderer_post(@rnd, :payment => payment_info, :commit => 'Process Order')
            end
            response.should include_text("Please wait your order is processing.")

            @order = Shop::ShopOrder.find(:last)
            @order.state.should == 'pending'
            @order.gift_order.should be_false
          end

          it "should create and start processing a gift order" do

            @rnd = checkout_renderer({}, :input => [ :checkout_page, "payment" ])
            assert_difference "Shop::ShopOrder.count" ,1 do 
              renderer_post(@rnd, :payment => payment_info, :commit => 'Process Order',
                            :order => { :gift_order => 'true', :gift_message => 'Happy Solstice Day!' })
            end
            response.should include_text("Please wait your order is processing.")

            @order = Shop::ShopOrder.find(:last)
            @order.state.should == 'pending'
            @order.gift_order.should be_true
            @order.gift_message.should == "Happy Solstice Day!"
          end
        end


      end

      describe "Processing and Success Pages" do
        before do
          @user = mock_user
          @myself.create_billing_address(address_data)
          @myself.create_shipping_address(address_data)
        end

        def pending_order(payment_override={})
          # Creates a region and carrier
          @shipping_category = Factory.create(:shop_shipping_category)
          # Factory girl can't handle objects with an "options" attribute
          @payment_processor = payment_processor

          session[:shop] = {}
          @order_processor = Shop::OrderProcessor.new(@user,session[:shop],@cart)
          @order_processor.set_order_address(true)
          payment_info[payment_info[:selected_processor_id]].merge!(payment_override)
          @order_processor.validate_payment(false,payment_info,{})
          @order_processor.process_payment
          session[:shop][:stage] = 'processing'

          @order_processor.order
        end

        it "should be able to process an order with a correct CC number" do
          @order = pending_order()
          @order.state.should == 'pending'
          @rnd = checkout_renderer({}, :input => [ :checkout_page, "processing" ])
          renderer_get @rnd  
          @rnd.should redirect_paragraph('/shop/success')

          @order.reload
          @order.state.should == 'authorized'
        end

        it "should redirect back to the payment page with an invalid CC" do
          # Test payment processor returns failure on a "2" for a cc
          @order = pending_order(:cc => '2')
          @order.state.should == 'pending'
          @rnd = checkout_renderer({}, :input => [ :checkout_page, "processing" ])
          renderer_get @rnd  
          @rnd.should redirect_paragraph('/shop/payment')

          @order.reload
          @order.state.should == 'payment_declined'

        end
    
        it "should display the success page after correct payment" do
          @order = pending_order()
          @order_processor.process_payment
          session[:shop][:stage] = 'success'
          @rnd = checkout_renderer({}, :input => [ :checkout_page, "success" ])
          @rnd.should_render_feature(:shop_checkout)
          renderer_get @rnd  
        end
      end

    end

  end


end
