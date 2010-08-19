require  File.expand_path(File.dirname(__FILE__)) + "/../../../../../../spec/spec_helper"

add_factory_girl_path(File.join(File.expand_path(File.dirname(__FILE__)),"..",".."))


describe Shop::PageRenderer, :type => :controller do
  
  controller_name :page

  integrate_views

# reset_domain_tables :shop_products,:shop_product_classes,:shop_product_options, :shop_product_features, :shop_product_files, :shop_product_options, :shop_product_prices 
  reset_domain_tables :shop_products # MyISAM has no transactions
  transaction_reset

  before do
    test_activate_module(:shop,:currency => "USD")
  end

  describe "Product List" do

    def product_listing_renderer(opts={},conns={})
      opts.merge!(:shop_shop_id => Shop::ShopShop.default_shop.id )
      build_renderer('/shop', '/shop/page/product_listing', opts, conns)
    end

    before(:each) do
      Shop::ShopShop.default_shop
      @other_shop = Shop::ShopShop.create(:name => 'My Shop',:abr => 'myshop')
      # Create a bunch of products form a couple different shops
      @products = (0..4).map { |n| Factory.create(:shop_product) } + 
                  (0..1).map { |n| Factory.create(:shop_product,:shop_shop_id => @other_shop.id) }
    end

    it "should be able to render a list of products" do
      @rnd = product_listing_renderer(:base_category_id => Shop::ShopCategory.get_root_category.id)
      @rnd.should_render_feature(:shop_product_listing)
      renderer_get @rnd
    end

    it "should search products" do
      @rnd = product_listing_renderer(:base_category_id => Shop::ShopCategory.get_root_category.id)
      # Run a search with an individual sku that shouldn't appear in the other products
      renderer_get @rnd,  { :search => @products[3].sku }

      response.should include_text(@products[3].name)
      response.should_not include_text(@products[0].name)
  
    end

    it "should display a the products on the page" do
      @rnd = product_listing_renderer(:base_category_id => Shop::ShopCategory.get_root_category.id, :per_page => 50)
      renderer_get @rnd
      response.should include_text(@products[3].name)
    end

    it "should not display products in a different shop" do
      @rnd = product_listing_renderer(:base_category_id => Shop::ShopCategory.get_root_category.id)
      renderer_get @rnd
      response.should_not include_text(@products[-1].name)
    end

    describe "Category Testing" do 
      before(:each) do
        @category = Factory.create(:shop_category)
        @category2 = Factory.create(:shop_category)
        @products[0..2].each { |prd| prd.add_category(@category) }
        @products[3..-1].each { |prd| prd.add_category(@category2,true) }
      end

  
      it "should not render anything if there's an invalid category" do
        @rnd = product_listing_renderer(:base_category_id => 0, :input => [ :product_category_1, 'SOMETHING'])
        renderer_get @rnd 
        response.should include_text("Invalid Category")
      end

      it "should not display products in a different category from the base" do
         @rnd = product_listing_renderer(:base_category_id => @category.id)
         
         renderer_get @rnd
         response.should include_text(@products[1].name)
         response.should_not include_text(@products[4].name)
      end

      it "should not display products in a different category if we're in a subcategory" do
        @rnd = product_listing_renderer({},{ :input => [ :product_category_1, @category2.url  ]})

        renderer_get @rnd
         response.should_not include_text(@products[1].name)
         response.should include_text(@products[4].name)

      end
    end

    describe "Adding Products to cart" do
      before(:each) do 
        mock_user
      end

      it "should add a product to the cart" do 
       @rnd = product_listing_renderer({:base_category_id => Shop::ShopCategory.get_root_category.id})

        assert_difference 'Shop::ShopCartProduct.count', 1 do 
          renderer_post @rnd, "shop#{@rnd.paragraph.id}" => { :action => 'add_to_cart',
                                                              :product => @products[4].id.to_s }
        end
      end
      
      it "should not add a product to the cart from a different shop" do 
       @rnd = product_listing_renderer({:base_category_id => Shop::ShopCategory.get_root_category.id})
       @rnd.should_render_feature(:shop_product_listing)

        assert_difference 'Shop::ShopCartProduct.count', 0 do 
          renderer_post @rnd, "shop#{@rnd.paragraph.id}" => { :action => 'add_to_cart',
                                                              :product => @products[-1].id.to_s }
        end
      end
    end
  end
  
  describe "Product Detail" do
    before(:each) do
      Shop::ShopShop.default_shop
      @other_shop = Shop::ShopShop.create(:name => 'My Shop',:abr => 'myshop')
      # Create a bunch of products form a couple different shops
      @products = (0..1).map { |n| Factory.create(:shop_product) } + 
                  (0..1).map { |n| Factory.create(:shop_product,:shop_shop_id => @other_shop.id) }
    end

    def product_detail_renderer(opts={},conns={})
      @page =  SiteVersion.default.root_node.add_subpage('shop_list_page')
      opts.merge!(:shop_shop_id => Shop::ShopShop.default_shop.id, :list_page_id => @page.id )
      build_renderer('/shop', '/shop/page/product_detail', opts, conns)
    end

    it "should properly render the feature" do
      @rnd = product_detail_renderer({},{ :input => [:product_id, @products[0].url] })
      renderer_get @rnd
      response.should include_text(@products[0].name)
    end

    it "should display an individual product from url" do 
      @rnd = product_detail_renderer({},{ :input => [:product_id, @products[0].url] })
      @rnd.should_render_feature(:shop_product_detail)
      renderer_get @rnd
      @rnd.should assign_to_feature(:product,@products[0])
    end

    it "should render nothing if we have a category link but no product" do
      @product = Factory.create(:shop_product,:description =>"Lorem mcipsum")
      @rnd = product_detail_renderer({},{ :category => [:product_category_1, "category"] })
      renderer_get @rnd
      response.should have_text(' ')
    end

    it "should display an individual product from paragraph options" do 
      @rnd = product_detail_renderer({:product_id => @products[1].id})
      @rnd.should_render_feature(:shop_product_detail)
      renderer_get @rnd
      @rnd.should assign_to_feature(:product,@products[1])
    end

    it "should display the product name and description" do 
      @product = Factory.create(:shop_product,:description =>"Lorem mcipsum")
      @rnd = product_detail_renderer({},{ :input => [:product_id, @product.url] })
      renderer_get @rnd
      response.should include_text(@product.name)
      response.should include_text(@product.description)
    end


    it "should not disply a product from the wrong shop" do 
      @rnd = product_detail_renderer({},{ :input => [:product_id, @products[2].url] })

      @rnd.should_render_feature(:shop_product_detail)

      renderer_get @rnd
      @rnd.should assign_to_feature(:product,nil)
    end

    it "should add a product to the cart" do
      @rnd = product_detail_renderer({},{ :input => [:product_id, @products[0].url] })
      mock_user

      assert_difference 'Shop::ShopCartProduct.count', 1 do 
          renderer_post @rnd, "shop#{@rnd.paragraph.id}" => { :action => 'add_to_cart',
                                                              :product => @products[0].id.to_s }
        end

    end

    it "should not add a product to the cart from the wrong shop" do
      @rnd = product_detail_renderer({},{ :input => [:product_id, @products[0].url] })
      mock_user

      assert_difference 'Shop::ShopCartProduct.count', 0 do 
        renderer_post @rnd, "shop#{@rnd.paragraph.id}" => { :action => 'add_to_cart',
                                                              :product => @products[-1].id.to_s }
      end
    end

  end


  describe "Display Cart" do
    renderer_builder '/shop/page/display_cart'
    before(:each) do
      @myself = mock_user
      @rnd = display_cart_renderer
    end

    it "should render the feature" do
      @rnd.should_render_feature("shop_display_cart")
      renderer_get @rnd
    end

    it "should display an empty cart" do
      renderer_get @rnd
      response.should include_text("Your cart is empty")
    end

    it "should display 1 product in cart" do 
      cart = Shop::ShopUserCart.new(@myself,"USD") 
      cart.add_product(Factory.create(:shop_product),1)
      renderer_get @rnd
      response.should include_text("You have 1 product in your cart")
    end

    it "should display multiple products in cart" do
      cart = Shop::ShopUserCart.new(@myself,"USD") 
      cart.add_product(Factory.create(:shop_product),1)
      cart.add_product(Factory.create(:shop_product),1)
      renderer_get @rnd
      response.should include_text("You have 2 products in your cart")
    end
  end

  # note: category listing uses the menu feature - 
  # see default feature for more info on the tests
  describe "Category Listing and Breadcrumbs" do
    renderer_builder "/shop/page/category_listing" do
       {  :base_category_id =>  Shop::ShopCategory.get_root_category.id }
    end
    renderer_builder "/shop/page/category_breadcrumbs" do
       {  :base_category_id =>  Shop::ShopCategory.get_root_category.id }
    end


    before do
      @category = Factory.create(:shop_category)
      @category2 = Factory.create(:shop_category)
      @sub_category1 = Factory.create(:shop_category,:parent_id => @category.id)
      @sub_category2 = Factory.create(:shop_category,:parent_id => @category.id)
      @sub_sub_category1 = Factory.create(:shop_category,:parent_id => @sub_category1.id)
      @sub_sub_category2 = Factory.create(:shop_category,:parent_id => @sub_category1.id)
      @page =  SiteVersion.default.root_node.add_subpage('shop_list')
    end

    it "should be able to display a category listing" do
       @rnd = category_listing_renderer(:list_page_id => @page.id)
       @rnd.should_render_feature(:menu)

       renderer_get @rnd
    end

    it "should say configure paragraph without a category" do 
        @rnd = category_listing_renderer(:base_category_id => nil)
        renderer_get @rnd 
        response.should include_text("Configure Paragraph")
      end

    it "should include links to each category" do
      @rnd = category_listing_renderer(:list_page_id => @page.id)
      renderer_get @rnd
      response.should have_tag("a[href=/shop_list/#{@category.url}]")
      response.should have_tag("a[href=/shop_list/#{@category2.url}]")
      response.should have_tag("a[href=/shop_list/#{@sub_category1.url}]")
      response.should have_tag("a[href=/shop_list/#{@sub_category2.url}]")
    end
    it "should not include links to each category below the set depth" do
      @rnd = category_listing_renderer(:list_page_id => @page.id,:depth => 1)
      renderer_get @rnd
      response.should have_tag("a[href=/shop_list/#{@category.url}]")
      response.should have_tag("a[href=/shop_list/#{@category2.url}]")
      response.should_not have_tag("a[href=/shop_list/#{@sub_category1.url}]")
      response.should_not have_tag("a[href=/shop_list/#{@sub_category2.url}]")
    end

    it "should not include links to above the base category" do
      @rnd = category_listing_renderer(:list_page_id => @page.id,:base_category_id => @category.id)
      renderer_get @rnd
      response.should_not have_tag("a[href=/shop_list/#{@category.url}]")
      response.should_not have_tag("a[href=/shop_list/#{@category2.url}]")
      response.should have_tag("a[href=/shop_list/#{@sub_category1.url}]")
      response.should have_tag("a[href=/shop_list/#{@sub_category2.url}]")
      response.should have_tag("a[href=/shop_list/#{@sub_sub_category1.url}]")
    end

    it "should highlight the selected category" do
      @rnd = category_listing_renderer({ :list_page_id => @page.id,:depth => 1 },
                                       { :input => [ :product_category_1, @category2.url ] } )
      renderer_get @rnd
      response.should have_tag("a[href=/shop_list/#{@category2.url}][class=selected]")
      response.should_not have_tag("a[href=/shop_list/#{@category.url}][class=selected]")
    end

    it "should say configure paragraph without a category" do 
      @rnd =  category_breadcrumbs_renderer(:base_category_id => nil)
      renderer_get @rnd 
      response.should include_text("Configure Paragraph")
    end

    it "should render the category_breadcrumbs feature" do
      @rnd = category_breadcrumbs_renderer({ :list_page_id => @page.id })
      @rnd.should_render_feature(:shop_page_category_breadcrumbs)
      renderer_get @rnd
    end

    it "should show a list of nested categories" do 
      @rnd = category_breadcrumbs_renderer({:list_page_id => @page.id},:input => [ :product_category_1, @sub_sub_category1.url ])
      
      renderer_get @rnd
      # shouldn't have the current category as a link 
      response.should include_text(@sub_sub_category1.name)
      response.should_not have_tag("a[href=/shop_list/#{@sub_sub_category1.url}]")
      response.should have_tag("a[href=/shop_list/#{@sub_category1.url}]")
      response.should have_tag("a[href=/shop_list/#{@category.url}]")
      response.should_not have_tag("a[href=/shop_list/#{@sub_sub_category2.url}]")
    end
  end

  describe "Search bar" do
    renderer_builder "/shop/page/search_bar" 

    it "should render the search bar paragraph" do
      @page =  SiteVersion.default.root_node.add_subpage('shop_list')
      @rnd = search_bar_renderer(:search_page_id => @page.id)
      @rnd.should_render_feature(:shop_page_search_bar)
      renderer_get @rnd
    end

    it "should display search" do 
      @page =  SiteVersion.default.root_node.add_subpage('shop_list')
      @rnd = search_bar_renderer(:search_page_id => @page.id)
      renderer_get @rnd
      response.should include_text("Search:")
    end

    it "should redirect on search" do
      @page =  SiteVersion.default.root_node.add_subpage('shop_list')
      @rnd = search_bar_renderer(:search_page_id => @page.id)
      renderer_post @rnd, :run_search => 'Yay'

      @rnd.should redirect_paragraph('/shop_list?search=Yay')
    end
  end

  
  
end

