
class Shop::Features::AddAccessToken < Shop::ProductFeature

  def self.shop_product_feature_handler_info
    { 
      :name => 'Add an access token to a user',
      :callbacks => [ :purchase ],
      :options_partial => "/shop/features/add_access_token"
    }
  end
  
  def purchase(user,order_item,session)
    user.add_token!(options.access_token, :valid_until => self.options.valid_until, :valid_at => nil) if options.access_token
  end

  def self.options(val)
    Options.new(val)
  end
  
  class Options < HashModel
    attributes :access_token_id => nil, :period => 0
    validates_presence_of :access_token_id
    integer_options :period

    options_form(
                 fld(:access_token_id, :select, :options => :access_token_options, :description => "Token to added to the user. Use this token when\nsetting up the lock(s) for the paid section of your site."),
                 fld(:period, :text_field, :unit => 'days', :label => 'Valid for', :description => 'Leave blank to prevent expiration')
                 )

    def validate
      self.errors.add(:access_token_id, 'is invalid') if self.access_token_id && self.access_token.nil?
    end

    def valid_until
      self.period.to_i > 0 ? self.period.to_i.days.since : nil
    end

    def access_token
      @access_token ||= AccessToken.find_by_id self.access_token_id
    end

    def access_token_options
      options = AccessToken.select_options_with_nil nil, :conditions => {:editor => 0}
      if options.length == 1
        AccessToken.create :token_name => 'Paid Membership', :editor => 0, :description => ''
        options = AccessToken.select_options_with_nil nil, :conditions => {:editor => 0}
      end
      options
    end
  end
  
  
  def self.description(opts)
    opts = self.options(opts)
    valid_for = opts.period.to_i > 0 ? sprintf(" for %d days", opts.period.to_i) : ''
    opts.access_token ? sprintf("Add Access Token (%s)%s",opts.access_token.name, valid_for) : 'Access Token NOT FOUND!'
  end
end
