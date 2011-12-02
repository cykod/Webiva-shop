class Shop::AdminController < ModuleController
  permit 'shop_config'

  component_info 'Shop', :description => 'Shop Component', 
                              :access => :private
                              
  register_permission_category :shop, "Shop" ,"Permissions for Shop Actions"
  
  register_permissions :shop, [  [ :manage, 'Shop Manage', 'Mange Shop Orders and Catalog' ],
                                 [ :config, 'Shop Admin', 'Edit Shop Configuration']
                             ]

  

  # Register a handler feature
  register_handler :shop, :carrier_processor, "Shop::StandardCarrierProcessor"

  register_handler :shop, :payment_processor, "Shop::TestPaymentProcessor"
  register_handler :shop, :payment_processor, "Shop::PaypalPaymentProcessor"
  register_handler :shop, :payment_processor, "Shop::PaypalExpressPaymentProcessor"
  register_handler :shop, :payment_processor, "Shop::AuthorizeNetPaymentProcessor"
  register_handler :shop, :payment_processor, "Shop::PayflowProPaymentProcessor"

  register_handler :shop, :payment_processor, "Shop::BillLaterPaymentProcessor"
  register_handler :shop, :payment_processor, "Shop::CodPaymentProcessor"

  register_handler :shop, :product_feature, "Shop::Features::ProfilePriceAdjustment"
  register_handler :shop, :product_feature, "Shop::Features::ProfileQuantityOption"
  register_handler :shop, :product_feature, "Shop::Features::AddUserTag"
  register_handler :shop, :product_feature, "Shop::Features::AddAccessToken"

  register_handler :webiva, :widget, "Shop::ShopOrdersWidget"
  register_handler :webiva, :widget, "Shop::ShopRevenueWidget"
  register_handler :structure, :wizard, "Shop::AddShopWizard"
 
  register_handler :user_segment, :fields, 'Shop::ShopOrderSegmentField'
  register_handler :user_segment, :fields, 'Shop::ShopOrderItemSegmentField'

  register_handler :site_feature, :shop_product_detail, "Shop::Features::ProfileQuantityOption"

  register_handler :members, :view,  "Shop::ManageUserController"

  register_handler :editor, :auth_user_register_feature, 'Shop::UserRegisterExtension'

  register_action '/shop/processor/purchase',
    :description => 'Shop Purchase',
    :controller => '/shop/manage',
    :action => 'edit',
    :level => 5,
    :path => :target

  content_node_type "Shop Product", "Shop::ShopProduct",  :search => true

  content_model :shop

  protected
  def self.get_shop_info
    [
      {:name => "Shop",:url => { :controller => '/shop/manage' } ,:permission => 'shop_manage', :icon => 'icons/content/shop.gif' }
    ]
  end

  public

  def get_currencies
    Shop::ShopProductPrice.currency_select_options
  end

  def options

    cms_page_info [ ["Options",url_for(:controller => '/options') ], ["Modules",url_for(:controller => "/modules")], "Shop Module Options "], "options"

    if Shop::ShopShop.count == 0
      Shop::ShopShop.create_default_shop
      Shop::ShopCategory.get_root_category
    end

    @options = self.class.module_options(params[:options])

    if request.post? && @options.valid?
      Configuration.set_config_model(@options)
      cts = ContentType.find(:all,:conditions => { :component => 'shop', :container_type => 'Shop::ShopShop' })
      cts.each do |ct|
        if ct.url_field == 'url' && @options.category_in_url
          ct.update_attributes(:url_field => 'category_url')
        elsif ct.url_field == 'category_url' && !@options.category_in_url
          ct.update_attributes(:url_field => 'url')          
        end
      end
      flash[:notice] = "Updated shop options".t 
      redirect_to :controller => '/modules'
      return
    end

    @currencies = get_currencies


    options = @mod.options 
  end


  def self.module_options(vals=nil)
    Configuration.get_config_model(ShopModuleOptions,vals)
  end

  class ShopModuleOptions < HashModel
    attributes :shop_currency => nil, :shipping_template_id => nil,:category_in_url => true, :auto_capture => false

    boolean_options :category_in_url, :auto_capture

    validates_presence_of :shop_currency

    def currency
      self.shop_currency
    end

    def currencies
      [ self.shop_currency ]
    end
  end

end
