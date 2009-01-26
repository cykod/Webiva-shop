
class Shop::ShopOrder < DomainModel

  serialize :shipping_address
  serialize :billing_address
  serialize :payment_information
  
  has_many :order_items, :class_name => 'Shop::ShopOrderItem'
  
  has_many :shop_order_actions, :class_name => 'Shop::ShopOrderAction'

  has_many :transactions,
            :class_name => 'Shop::ShopOrderTransaction',
            :dependent => :destroy,
            :foreign_key => :shop_order_id,
            :order => 'shop_order_transactions.created_at DESC'
            
  belongs_to :shop_payment_processor, :class_name => 'Shop::ShopPaymentProcessor'
  belongs_to :shop_shipping_category, :class_name => 'Shop::ShopShippingCategory'
  belongs_to :end_user
            
  acts_as_state_machine :initial => :pending
  
  has_options :state, [ ['Waiting','initial' ], 
                        ['Pending', 'pending' ], 
                        ['Authorized','authorized'],
                        ['Paid','paid'],
                        ['Payment Declined','payment_declined'],
                        ['Shipped','shipped'],
                        ['Partially Refunded','partially_refunded'],
                        ['Fully Refunded','fully_refunded'],
                        ['Order Voided','voided']
                       ]
  
  has_options :payment_type, [ ['Standard Purchase','standard'],
                               ['Standard Purchase (Remember Payment info)','remember'],
                               ['Reference Purchase','reference' ],
                               ['Admin Purchase','admin'],
                               ['Admin Purcahse (Remember Payment info)','admin_remember' ],
                               ['Admin Reference Purchase','admin_reference' ] ]
  
  state :initial
  state :pending
  state :authorized
  state :paid
  state :shipped
  state :payment_declined
  state :partially_refunded
  state :fully_refunded
  state :voided
  
  event :payment_setup do 
    transitions :from => :initial, :to => :pending
    transitions :from => :pending, :to => :pending
  end
  
  event :payment_authorized do
    transitions :from => :pending,
                :to => :authorized
                
    transitions :from => :payment_declined,
                :to => :authorized
  end
  
  event :payment_voided do
    transitions :from => :authorized,
                :to => :voided
  
  end
  
  event :payment_captured do 
    transitions :from => :authorized,
                :to => :paid
  end


  event :transaction_declined do 
    transitions :from => :pending,
                :to => :payment_declined
                
    transitions :from => :payment_declined,
                :to => :payment_declined
                
    transitions :from => :authorized,
                :to => :authorized
  end
  
  event :shipped do 
    transitions :from => :paid,
                :to => :shipped
  end
  
  event :full_refund do
    transitions :from => :paid,
                :to => :fully_refunded
    transitions :from => :shipped,
                :to => :fully_refunded 
    transitions :from => :partially_refunded,
                :to => :fully_refunded 
  end
  
  event :partial_refund do 
    transitions :from => :paid,
                :to => :partially_refunded
  end
  
  
  def pending_payment(options)
    transaction do
      self.currency = options[:currency]
      self.tax = options[:tax]
      self.shipping = options[:shipping]
      self.shipping_address = (options[:shipping_address]||{}).symbolize_keys
      self.billing_address = (options[:billing_address]||{}).symbolize_keys
      self.shop_payment_processor_id = options[:shop_payment_processor].id
      self.payment_information = (options[:payment]||{}).to_hash.symbolize_keys
      self.shop_shipping_category_id = options[:shop_shipping_category_id] if  options[:shop_shipping_category_id]
      self.ordered_at = Time.now
      self.order_items.clear
      
      total = 0.0
      options[:cart].products.each do |product|
        subtotal = product.price(options[:currency]) * product.quantity
        total += subtotal
        self.order_items.create(:item_sku => product.sku,
                                :item_name => product.name,
                                :item_details => product.details,
                                :order_item_type => product.cart_item_type,
                                :order_item_id => product.cart_item_id,
                                :options => product.options,
                                :currency => options[:currency],
                                :unit_price => product.price(options[:currency]),
                                :quantity => product.quantity,
                                :subtotal => subtotal )
      end
      self.subtotal = total
      self.total = total + options[:tax].to_f + options[:shipping].to_f
      self.save
    end
  end
  
  # processor = Shop::ShopPaymentProcessor
  # payment = { :currency => 'USD', :subtotal => 12.95, :tax => 3.12, :shipping => 5.95 }
  # user_info = { :shipping_address => address_hash, :billing_address => address_hash, :user => EndUser }
  # request_options = { :remote_ip => user ip address }
  def authorize_payment(request_options = {})
    self.reload(:lock => true)
  
    request_options[:order_id] = self.id
    
    processor = self.shop_payment_processor
    transaction do
      user_info = { :shipping_address => self.shipping_address, :billing_address => self.billing_address }
      user_info[:user] = {
        :first_name => self.billing_address[:first_name] || self.end_user.first_name,
        :last_name => self.billing_address[:last_name] || self.end_user.last_name,
        :email => self.end_user.email,
        :user_id => self.end_user_id    }
      authorization = Shop::ShopOrderTransaction.authorize(
            self.end_user,processor,payment_information,currency,total,user_info,request_options
            )
      transactions.push(authorization)
      
      self.payment_type, self.payment_identifier, self.payment_reference = processor.payment_record(authorization,self.payment_information,:admin => request_options[:admin])
      self.payment_information = processor.sanitize(self.payment_information)
      if authorization.success?
        payment_authorized!
      else
        transaction_declined!
      end
      
      authorization
    end
  end
  
  def admin_capture_payment(captured_by,notes)
    if result = capture_payment
        self.shop_order_actions.create(:end_user => captured_by, :order_action => 'captured', :note => notes)
        result
    else
      false
    end
  
  end
  
  def capture_payment
   self.reload(:lock => true)
   processor = self.shop_payment_processor
   transaction do
      authorization = find_authorization
      capture = Shop::ShopOrderTransaction.capture(self.end_user,processor,authorization.reference,currency,total )
      transactions.push(capture)
      if capture.success?
        payment_captured!
      else
        transaction_declined!
      end

      return capture
    end
    return false
  end
  
  def admin_ship_order(shipped_by,notes)
    if result = ship_order
        self.shop_order_actions.create(:end_user => shipped_by, :order_action => 'shipped', :note => notes)
        result
    else
      false
    end
  end
  
  def ship_order()
     self.reload(:lock => true)
    if self.state == 'paid'
      self.update_attributes( :shipped_at => Time.now )
      shipped!
    else
      false
    end
  end
  
  def admin_refund_order(amount,refunded_by,notes)
    if result = refund_order(amount)
      self.shop_order_actions.create(:end_user => refunded_by,:order_action => 'refund', :note => notes)
      result
    else
      false
    end
  end
  
  def refund_order(amount)
    if(amount <= total)
      self.reload(:lock => true)
      processor = self.shop_payment_processor
      authorization = find_payment
      transaction do 
        refund_transaction = Shop::ShopOrderTransaction.refund(self.end_user,processor,authorization.reference,currency,amount)
        transactions.push(refund_transaction)
        if refund_transaction.success?
          # Determine the type of refund
          is_partial_refund = amount < total
          # Update the order - adjust the totals
          self.update_attributes(:total => (total - amount) , :refund => (refund + amount))
          is_partial_refund ? partial_refund! : full_refund!
        end
        return refund_transaction
      end
    end
    return false
  end 
  
  def admin_void_order(voided_by,notes)
    if result = void_order()
        self.shop_order_actions.create(:end_user => voided_by, :order_action => 'voided', :note => notes)
        result
    else
      false
    end
  end
  
  
  def void_order()
    if self.state == 'authorized'
      processor = self.shop_payment_processor
      authorization = find_authorization
      transaction do 
        void_transaction = Shop::ShopOrderTransaction.void(self.end_user,processor,authorization.reference)
        transactions.push(void_transaction)
        if void_transaction.success?
          payment_voided!
        end
        return void_transaction
      end
    end
    return false
  end
  
  def refundable?
    return %w(paid shipped partially_refunded).include?(self.state)
  end
  
  def self.remember_transaction(processor,user,options)
    if options[:admin]
      remember = '"remember","admin_remember"'
    else
      remember = '"remember"'
    end
    self.find(:first,:conditions => [ 'shop_payment_processor_id = ? AND payment_type IN (' + remember + ') AND end_user_id = ? AND `state` IN ("authorized","paid","shipped","partially_refunded","full_refunded")',
                                      processor.id,user.id ], :order => 'ordered_at DESC')
  
  
  end

  def display_total
    Shop::ShopProductPrice.localized_amount(total,currency)    
  end
  def display_tax
    Shop::ShopProductPrice.localized_amount(tax,currency)    
  end
  def display_subtotal
    Shop::ShopProductPrice.localized_amount(subtotal,currency)    
  end
  def display_shipping
    Shop::ShopProductPrice.localized_amount(shipping,currency)    
  end

  def display_refund
    Shop::ShopProductPrice.localized_amount(-1 * refund,currency)    
  end
  
  def amount(amt)
    Shop::ShopProductPrice.localized_amount(amt,currency)
  end
  
  def display_shipping_address
    display_address(self.shipping_address)
  end
  
  def display_billing_address
    display_address(self.billing_address)
  end
  
  def number
    sprintf("#%05d",self.id)
  end
  
  protected 
  def display_address(adr)
    "#{adr[:first_name]} #{adr[:last_name]}\n
     #{adr[:address]}\n" +
     (adr[:address_2] ? adr[:address_2] + "\n" : '') +
     "#{adr[:city]} #{adr[:state]}, #{adr[:zip]}\n#{adr[:county]}"
  end  
  
  def find_payment
    self.transactions.find(:first,:conditions => 'success = 1 AND action IN("capture","payment")',:order => 'id')
  end

  
  def find_authorization
    self.transactions.find(:first,:conditions => 'success = 1 AND action="authorization"')
  end
end
