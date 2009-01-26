class Shop::AdminController < ModuleController
  permit 'shop_admin'

  component_info 'Shop', :description => 'Shop Component', 
                              :access => :private
                              
  register_permission_category :shop, "Shop" ,"Permissions for Shop Actions"
  
  register_permissions :shop, [  [ :manage, 'Shop Manage', 'Mange Shop Orders and Catalog' ],
                                 [ :admin, 'Shop Admin', 'Edit Shop Configuration']
                             ]

  

  # Register a handler feature
  register_handler :shop, :carrier_processor, "Shop::StandardCarrierProcessor"

  register_handler :shop, :payment_processor, "Shop::TestPaymentProcessor"
  register_handler :shop, :payment_processor, "Shop::PaypalPaymentProcessor"
  register_handler :shop, :payment_processor, "Shop::AuthorizeNetPaymentProcessor"
  register_handler :shop, :payment_processor, "Shop::PayflowProPaymentProcessor"

  register_handler :shop, :payment_processor, "Shop::BillLaterPaymentProcessor"
  register_handler :shop, :payment_processor, "Shop::CodPaymentProcessor"

  register_handler :shop, :product_feature, "Shop::Features::ProfilePriceAdjustment"
  register_handler :shop, :product_feature, "Shop::Features::ProfileQuantityOption"
  register_handler :site_feature, :shop_product_detail, "Shop::Features::ProfileQuantityOption"

  register_handler :members, :view,  "Shop::ManageUserController"



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
    get_module
    

    @options = ShopModuleOptions.new(params[:options] || @mod.options || {})

    if request.post?
      if @options.valid?
        @mod.options  = @options.to_h
        @mod.save
        flash[:notice] = "Updated shop options".t 
        redirect_to :controller => '/modules'
        return
      end
    end

    @currencies = get_currencies
    

    options = @mod.options 
  end


  def self.module_options
    md = SiteModule.find_by_name('shop')
    opts = ShopModuleOptions.new(md ? md.options : {})
  end

  class ShopModuleOptions < HashModel
      default_options :shop_currency => 'USD'

      validates_presence_of :shop_currency
      
      def currencies
        [ self.shop_currency ]
      end
  end
 
end
