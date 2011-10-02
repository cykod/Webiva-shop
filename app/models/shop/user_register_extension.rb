
class Shop::UserRegisterExtension < Handlers::ParagraphFormExtension

  def self.editor_auth_user_register_feature_handler_info
    { 
      :name => 'Shop Order Registration',
      :paragraph_options_partial => '/shop/handler/auth_user_register'
    }
  end

  # Paragraph Setup options
  def self.paragraph_options(val={})
    opts = UserRegisterExtensionParagraphOptions.new(val)
  end

  # Generates called with the paragraph parameters
  def generate(params); end

  # Called before the feature is displayed
  def feature_data(data); end

  # Adds any feature related tags
  def feature_tags(c,data); end

  # Validate the submitted data
  def valid?; true; end

  # After everything has been validated 
  # Perform the actual form submission
  def post_process(user)
    address = user.default_address
    adr = {
      :first_name => user.first_name,
      :last_name => user.last_name,
      :address => address.address,
      :city => address.city,
      :state => address.state,
      :zip => address.zip,
      :country => address.country
    }

    order = Shop::ShopOrder.create(:end_user_id => user.id,
                                   :name => user.name,
                                   :ordered_at => Time.now,
                                   :currency => 'USD',
                                   :state => 'success',
                                   :subtotal => 0.0,
                                   :total => 0.0,
                                   :tax => 0.0,
                                   :shipping => 0.0,
                                   :shipping_address => adr,
                                   :billing_address =>  adr)
    order.update_attribute(:state,'paid')

    order.order_items.create(:item_name => @options.shop_product.name,
                             :order_item => @options.shop_product,
                             :currency => 'USD',
                             :unit_price => 0.0,
                             :quantity => 1,
                             :subtotal => 0.0)

    order.shop_order_actions.create :order_action => 'note', :note => '[Add via Registration]'

    session = {}
    order.post_process user, session
  end


  class UserRegisterExtensionParagraphOptions < HashModel
    attributes :shop_product_id => nil

    validates_presence_of :shop_product_id

     options_form(
                  fld(:shop_product_id, :select, :options => :shop_product_options)
                  )

    def shop_product_options
      Shop::ShopProduct.select_options_with_nil
    end

    def shop_product
      @shop_product ||= Shop::ShopProduct.find_by_id self.shop_product_id
    end

    def validate
      self.errors.add(:shop_product_id, 'is invalid') if self.shop_product_id && self.shop_product.nil?
    end
  end
end
