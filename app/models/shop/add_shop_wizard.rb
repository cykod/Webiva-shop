
class Shop::AddShopWizard < WizardModel

  def self.structure_wizard_handler_info
    { :name => "Add an E-commerce shop to your Site",
      :description => 'This wizard will add an e-commerce shop to your site complete with cart and checkout',
      :permit => "shop_config",
      :url => self.wizard_url
    }
  end

  attributes :shop_id => nil, 
  :add_to_id=>nil,
  :add_to_subpage => 'shop',
  :add_to_existing => nil,
  :opts => ['cart','categories','dummy_products'],
  :add_processor => nil,
  :add_region => nil,
  :add_country => nil,
  :add_delivery => nil,
  :shipping_cost => 5.00,
  :add_dummy_products => true

  boolean_options :add_processor, :add_region, :add_delivery
  float_options :shipping_cost

  page_options :add_to_id
  
  validates_format_of :add_to_subpage, :with => /^[a-zA-Z0-9\-_]+$/, :message => 'is an invalid url', :allow_blank => true
  validates_presence_of :add_to_id

  validates_presence_of :shop_id

  def wizard_partial; '/shop/wizard/form'; end

  def validate
    if (self.add_to_existing.blank? && self.add_to_subpage.blank?) || 
       (!self.add_to_existing.blank? && self.add_to_node.node_type == 'R')
      self.errors.add(:add_to, "must have a subpage selected or add\n to existing must be checked")
    end
  end

  def shop
    @shop ||= Shop::ShopShop.find(self.shop_id) if self.shop_id
  end

  def set_defaults(params)
    self.shop_id = Shop::ShopShop.default_shop.id
  end

  def run_wizard
    base_node = SiteNode.find(self.add_to_id)

    if self.add_to_existing.blank?
      base_node = base_node.add_subpage(self.add_to_subpage)
    end

    base_node.push_subpage('cart') do |cart_page, cart_revision|
      base_node.push_subpage('checkout') do |checkout_page, checkout_revision|
        base_node.new_revision do |shop_revision|
          self.destroy_basic_paragraph(shop_revision)
          self.destroy_basic_paragraph(cart_revision)
          self.destroy_basic_paragraph(checkout_revision)

          shop_revision.push_paragraph('/shop/page','product_listing',
                                       { :detail_page_id => base_node.id,
                                         :cart_page_id => cart_page.id,
                                         :shop_shop_id => self.shop_id, 
                                         :base_category_id => Shop::ShopCategory.get_root_category.id
                                       }) do |para|
            para.add_page_input(:input,:page_arg_0,:product_category_1)
            para.add_page_input(:detail,:page_arg_1,:product_url)
          end

          shop_revision.push_paragraph('/shop/page','product_detail',
                                       { :cart_page_id => cart_page.id,
                                         :list_page_id => base_node.id, 
                                         :shop_shop_id => self.shop_id
                                       }) do |para|
            para.add_page_input(:category,:page_arg_0,:product_category_1)
            para.add_page_input(:input,:page_arg_1,:product_id)
          end

    
          cart_revision.push_paragraph('/shop/processor','full_cart',
                                       { :checkout_page_id => checkout_page.id
                                       })


          checkout_revision.push_paragraph('/shop/processor','checkout',
                                           { :cart_page_id => cart_page.id,
                                             :add_tags => 'ShopOrder'
                                           }) do |para|
            para.add_page_input(:input,:page_arg_0,:checkout_page)
          end


          if self.opts.include?('cart')
            shop_revision.push_paragraph('/shop/page','display_cart',
                                         { :full_cart_page_id => cart_page.id 
                                         }, :zone => 3)
          end

          if self.opts.include?('categories')
            shop_revision.push_paragraph('/shop/page','category_listing',
                                         { :list_page_id => base_node.id,
                                           :base_category_id => Shop::ShopCategory.get_root_category.id
                                         }, :zone => 3) do |para|
              para.add_page_input(:input,:page_arg_0,:product_category_1)
            end
          end
        end
      end
    end

    mod_opts = Shop::AdminController.module_options
    if self.add_processor
      processor = Shop::ShopPaymentProcessor.new(
        :name => 'Test Processor',
        :currency => mod_opts.currency,
        :payment_type => 'Credit Card',
        :options => { :force_failure => "no" },
        :active => true)
      processor.processor_handler = 'shop/test_payment_processor'
      processor.save
    end

    if self.add_region
      # Add automatic subregions for US
      region = Shop::ShopRegion.new(:name => self.add_country,:tax => 0.0,
                                    :has_subregions => self.add_country == 'United States',
                                   :subregion_type => 'state')
      region.countries.build(:country => self.add_country)
      region.save
    end

    if self.add_delivery
      region ||= Shop::ShopRegion.find(:first) 
      if region
        carrier = Shop::ShopCarrier.new(:name => "Standard Carrier")
        carrier.carrier_processor = "shop/standard_carrier_processor"
        carrier.save

        category = Shop::ShopShippingCategory.create(
                                  :name => "Standard Shipping",
                                  :shop_carrier_id => carrier.id,
                                  :shop_region_id => region.id,
                                  :active => 1,
                                  :options => { :classes_shipping_cost => "item",
                                                :items => [ "" ],
                                                :item_prices => [ self.shipping_cost.to_s ],
                                                :items_shipping_cost => "item",
                                                :shipping_calculation => "items" })
      end
    end

    if self.opts.include?('dummy_products') && self.shop.shop_products.count == 0
      (0..2).each do |idx|
        self.create_dummy_product
      end
    end
  end

  def shop_folder
    @shop_folder ||= DomainFile.find(:first,:conditions => "name = 'Shop' and parent_id = #{DomainFile.root_folder.id}") || DomainFile.create(:name => 'Shop', :parent_id => DomainFile.root_folder.id, :file_type => 'fld')
  end

  def create_dummy_products
    return if @products
    @products = []
    (1..3).each do |idx|
      product = DomainFile.find(:first, :conditions => {:parent_id => self.shop_folder.id, :file_type => 'img', :name => "no#{idx}_product.png"})
      if product
        @products << product
      else
        File.open("#{RAILS_ROOT}/vendor/modules/shop/public/images/no#{idx}_product.png", "r") do |fd|
          @products << DomainFile.create(:filename => fd, :parent_id => self.shop_folder.id, :process_immediately => true)
        end
      end
    end
  end

  def dummy_product_image
    @shop_product_idx ||= -1
    @shop_product_idx+=1
    @shop_product_idx = @shop_product_idx % 3
    @products[@shop_product_idx]
  end

  def create_dummy_product
    create_dummy_products
    self.shop.shop_products.create :name => DummyText.words(1).split(' ')[0..2].join(' '), :price_values => {'USD' => 10.00}, :description => DummyText.paragraph, :image_file_id => self.dummy_product_image.id
  end
end

