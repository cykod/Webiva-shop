
class Shop::AddShopWizard < HashModel

  attributes :shop_id => nil, 
  :add_to_id=>nil,
  :add_to_subpage => 'shop',
  :add_to_existing => nil,
  :opts => ['cart','categories'],
  :add_processor => nil,
  :add_region => nil,
  :add_country => nil,
  :add_delivery => nil,
  :shipping_cost => 5.00

  boolean_options :add_processor, :add_region, :add_delivery
  float_options :shipping_cost

  page_options :add_to_id
  
  validates_format_of :add_to_subpage, :with => /^[a-zA-Z0-9\-_]+$/, :message => 'is an invalid url', :allow_blank => true
  validates_presence_of :add_to_id

  validates_presence_of :shop_id

  def validate
    if (self.add_to_existing.blank? && self.add_to_subpage.blank?) || 
       (!self.add_to_existing.blank? && self.add_to_node.node_type == 'R')
      self.errors.add(:add_to," must have a subpage selected or add\n to existing must be checked")
    end
  end

  def add_to_site!
    nd = SiteNode.find(self.add_to_id)

    if self.add_to_existing.blank?
      nd = nd.add_subpage(self.add_to_subpage)
    end

    # /cart
    cart_page = nd.add_subpage('cart')
    cart_page.save


    checkout_page = nd.add_subpage('checkout')
    checkout_page.save

    shop_revision = nd.page_revisions[0]
    cart_revision = cart_page.page_revisions[0]
    checkout_revision = checkout_page.page_revisions[0]
    
    list_para = shop_revision.add_paragraph('/shop/page','product_listing',
                                { 
                                  :detail_page_id => nd.id,
                                  :cart_page_id => cart_page.id,
                                  :shop_shop_id => self.shop_id, 
                                  :base_category_id => Shop::ShopCategory.get_root_category.id
                                }
                                )
    list_para.add_page_input(:input,:page_arg_0,:product_category_1)
    list_para.add_page_input(:detail,:page_arg_1,:product_url)
    list_para.save

    detail_para = shop_revision.add_paragraph('/shop/page','product_detail',
                              { 
                                  :cart_page_id => cart_page.id,
                                  :list_page_id => nd.id, 
                                  :shop_shop_id => self.shop_id
                              }
                              )
    detail_para.add_page_input(:category,:page_arg_0,:product_category_1)
    detail_para.add_page_input(:input,:page_arg_1,:product_id)
  
    detail_para.save

    
    cart_para = cart_revision.add_paragraph('/shop/processor','full_cart',
                                            {
                                              :checkout_page_id => checkout_page.id
                                            });

    cart_para.save

    checkout_para = checkout_revision.add_paragraph('/shop/processor','checkout',
                                                     {
                                                      :cart_page_id => cart_page.id,
                                                      :add_tags => 'ShopOrder'
                                                      });

    checkout_para.add_page_input(:input,:page_arg_0,:checkout_page)
    checkout_para.save


    if self.opts.include?('cart')
      
      cart_paragraph = shop_revision.add_paragraph('/shop/page','display_cart',
                              { 
                               :full_cart_page_id => cart_page.id 
                              },
                              :zone => 3
                              )

      cart_paragraph.save
    end

    if self.opts.include?('categories')
       cat_para = shop_revision.add_paragraph('/shop/page','category_listing',
                                { 
                                  :list_page_id => nd.id,
                                  :base_category_id => Shop::ShopCategory.get_root_category.id
                                },
                                :zone => 3
                                )
      cat_para.add_page_input(:input,:page_arg_0,:product_category_1)
      cat_para.save
    end

    shop_revision.make_real
    cart_revision.make_real
    checkout_revision.make_real

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
  end
end

