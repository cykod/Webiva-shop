
class Shop::AddShopWizard < HashModel

  attributes :shop_id => nil, 
  :add_to_id=>nil,
  :add_to_subpage => nil,
  :add_to_existing => nil,
  :opts => ['cart','categories'],
  :add_processor => nil,
  :add_region => nil,
  :add_country => nil,
  :add_delivery => nil,
  :shipping_cost => 5.00

  boolean_options :add_processor, :add_region, :add_delivery
  float_options :shipping_cost
  
  validates_format_of :add_to_subpage, :with => /^[a-zA-Z0-9\-_]+$/, :message => 'is an invalid url', :allow_blank => true
  validates_presence_of :add_to_id

  validates_presence_of :shop_id

  def validate
    if self.add_to_existing.blank? && self.add_to_subpage.blank?
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
    cart.save

    checkout_page = nd.add_subpage('checkout')
    checkout_page.save

    success_page = nd.add_subpage('success')
    success_page.save

    shop_revision = nd.page_revisions[0]
    cart_revision = cart_page.page_revisions[0]
    checkout_revision = checkout_page.page_revisions[0]
    success_revision = sucesss_page.page_revisions[0]
    
    list_para = shop_revision.add_paragraph('/shop/page','product_listing',
                                { 
                                  :detail_page => nd.id,
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
                                                      :success_page_id => success_page.id,
                                                      :add_tags => 'ShopOrder'
                                                      });

    checkout_para.add_page_input(:input,:page_arg_0,:checkout_page)
    checkout_para.save


    success_revision.page_paragraphs[0].body = "<h1>Order Received</h1><p>Thank you, your order has been sucessfully received"
    success_revision.page_paragraphs[0].save


    if self.opts.include?('cart')
      
      cart_paragraph = detail_revision.add_paragraph('/shop/page','display_cart',
                              { 
                               :full_cart_page_id => cart_page.id 
                              },
                              :zone => 3
                              )

      cart_paragraph.save
    end

    if self.opts.include?('categories')
       cat_para = list_revision.add_paragraph('/shop/page','category_listing',
                                { 
                                  :list_page_id => nd.id,
                                  :base_category_id => Shop::ShopCategory.get_root_category.id
                                },
                                :zone => 3
                                )
      cat_para.add_page_input(:input,:page_arg_0,:product_category_1)
      cat_para.save
    end

    shop_revision.make_real!
    cart_revision.make_real!
    checkout_revision.make_real!
    success_revision.make_real!

  end
end
