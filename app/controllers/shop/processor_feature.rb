
class Shop::ProcessorFeature < ParagraphFeature

  include ActionView::Helpers::FormTagHelper

 feature :shop_full_cart, :default_css_file => '/components/shop/stylesheets/cart.css',  :default_feature => <<-FEATURE
 <div id='shop_full_cart'>
    <cms:no_cart><div class='cart_empty'>You currently have no products in your shopping cart</div></cms:no_cart>
    <cms:cart>
     <cms:message><div class='cart_message'><cms:value/></div></cms:message>
     <table cellspacing='0'>
       <thead>
         <tr>
            <th>Product</th>
            <th>Unit Cost</th>
            <th class='last'>Quantity</th>
            <th class='last'>Cost</th>
        </tr>
       </thead>
       <tbody>
       <cms:products>
         <cms:product>
           <tr>
             <td><b><cms:name/></b><br/><cms:details/></td>
             <td><cms:unit_cost/></td>
             <td class='last'><cms:quantity/></td>
             <td class='last'><cms:product_cost/></td>
           </tr>
        </cms:product>
        <tr class='total'><td colspan='3'>Shipping:</td><td><cms:shipping/></td></tr>
        <tr class='total'><td colspan='3'>Tax:     </td><td><cms:tax/></td></tr>
        <tr class='total'><td colspan='3'>Total:   </td><td><cms:total/></td></tr>
        <tr class='total'><td colspan='3'><cms:update_quantity/></td></tr>
     </cms:products>
     <tr class='buttons'><td colspan='4'>
       <cms:coupon><cms:form>
          <br/>Promotional Code: <cms:code/> <cms:apply_button/>
       </cms:form></cms:coupon>
     </td></tr>
     <tr class='buttons'><td>&nbsp;</td></tr>
     <tr class='buttons'>
       <td colspan='2' class='last'><cms:continue_shopping>Continue Shopping</cms:continue_shopping></td>
       <td colspan='2' class='last'><cms:checkout>Checkout</cms:checkout></td>
     </tr>
     </tbody>
     </table>
    </cms:cart>
</div>
FEATURE
      
 
def shop_full_cart_feature(data)
  webiva_feature('shop_full_cart',data) do |c|
      c.value_tag('user') { |t| myself.id ? myself.name : nil }
      c.expansion_tag('anonymous') { |t| !myself.id }
      c.expansion_tag('cart') { |t| data[:cart].products_count > 0 }

      c.expansion_tag('static') { |tag| data[:static] }
      
      c.define_tag 'cart:products' do |tag|
        if data[:static]
          tag.expand
        else
      <<-EOTAG
            #{form_tag('')}
               <input type='hidden' name='shop#{data[:paragraph_id]}[action]' value='update_quantities'/>
          #{tag.expand}
          </form>
        EOTAG

        end
      end
      c.define_tag('cart:product') { |tag| c.each_local_value(data[:cart].products,tag,'cart_item') }
          c.value_tag('cart:product:name') { |tag|  tag.locals.cart_item.name }
          c.value_tag('cart:product:details') { |tag| tag.locals.cart_item.details(data[:cart]) }

          c.define_tag 'cart:product:unit_cost' do |tag|
            if tag.locals.cart_item.coupon?
              ''
            else
              Shop::ShopProductPrice.localized_amount(tag.locals.cart_item.price(data[:cart]),data[:currency])
            end
          end
          c.define_tag 'cart:product:quantity' do |tag|
            if tag.locals.cart_item_type == 'Shop::ShopCoupon'
              ''
            elsif data[:static]
              tag.locals.cart_item.quantity
            else
              opts = { :size => 4, :class => 'quantity_field' }.merge(tag.attr)
              # Need to create an hash for the options and the item as we may not have an id
              # if this is a session situation
              item_hash,opt_hash = quantity_hash(tag.locals.cart_item)
              text_field_tag "shop#{data[:paragraph_id]}[quantity][#{item_hash}][#{opt_hash}]", tag.locals.cart_item.quantity, opts
            end
          end
          c.define_tag 'cart:product:product_cost' do |tag|
            price = tag.locals.cart_item.price(data[:cart]) * tag.locals.cart_item.quantity
            Shop::ShopProductPrice.localized_amount(price,data[:currency])
          end

          c.define_tag 'cart:product:remove' do |t|
            if data[:static]
              ''
            else
              item_hash,opt_hash = quantity_hash(t.locals.cart_item)
              if t.attr['type'].to_s == 'image'
               tag(:input, { :type => 'image', :value => 1, :name => "shop#{data[:paragraph_id]}[remove][#{item_hash}][#{opt_hash}]",:src => t.expand }.merge(t.attr))
              else
               opts = t.attr.clone
               value = t.single? ? (opts.delete('value') || 'Remove') : t.expand
               tag(:input,  { :type => 'submit', :name => "shop#{data[:paragraph_id]}[remove][#{item_hash}][#{opt_hash}]",:value => value}.merge(t.attr))
              end
            end
          end

          c.value_tag('cart:total') { |t| Shop::ShopProductPrice.localized_amount(data[:cart].total,data[:currency]) }
          
          c.expansion_tag('cart:shippable') { |t| data[:cart].shippable? }
          c.define_tag 'cart:shipping' do |tag|
            if data[:cart].shippable?
              data[:cart].shipping ? Shop::ShopProductPrice.localized_amount(data[:cart].shipping,data[:currency]) : "(Next Step)"
            else
              Shop::ShopProductPrice.localized_amount(0.0,data[:currency])
            end
          end
          c.value_tag('cart:tax') { |t|
             if data[:cart].tax 
                Shop::ShopProductPrice.localized_amount(data[:cart].tax,data[:currency])
             else
               "(Next Step)"
             end
          }

          c.define_button_tag('cart:products:update_quantity',:value => 'Update') { |t| !data[:static] }
      c.value_tag('message') { |t| data[:cart].messages.join("<br/>") }
      
      c.expansion_tag('cart:coupon') { |t| !data[:static] }
      c.form_for_tag('cart:coupon:form',"shop#{data[:paragraph_id]}",
        :code => "<input type='hidden' name='shop#{data[:paragraph_id]}[action]' value='coupon'/>" ) { |t| DefaultsHashObject.new({}) }
        c.field_tag('cart:coupon:form:code',:size => 10)
        c.button_tag('cart:coupon:form:apply_button',:value => 'Apply')
          
          
      c.post_button_tag('cart:checkout',:button => 'Checkout',:method =>'get') { |t| data[:checkout_page] }
      c.post_button_tag('cart:continue_shopping',:button => 'Continue Shopping'.t,:method => 'get') { |t| session[:shop_continue_shopping_url_link] }
   end
  end


  feature :shop_checkout, :default_css_file => '/components/shop/stylesheets/checkout.css', :default_feature => <<-FEATURE
<div class='shop_checkout'>
<cms:login_page>
<cms:cart/>
<h4>Please login or register to continue checking out</h4>
  <cms:login_form>
  <cms:errors/>
  <div class='webiva_form shop_form shop_login_form'>
   <ol class='shop_form webiva_form'>
    <li><cms:email_label/> <cms:email/></li>
    <li><cms:password_label/><cms:password/></li>
    <li><cms:login_button/></li>
   </ol>
  </div>
  </cms:login_form>

  <h4>New User? Please enter your name and email to continue</h4>
  <cms:register_form>
   <cms:errors/>
   <ol class='webiva_form shop_form shop_register_form'>
    <li><cms:first_name_label/><cms:first_name/></li>
    <li><cms:last_name_label/><cms:last_name/></li>
    <li><cms:email_label/><cms:email/></li>
    <cms:guest_allowed>
      <li><h4>Create an account by entering a password(optional)</h4></li>
    </cms:guest_allowed>
    <li><cms:password_label/><cms:password/></li>
    <li><cms:confirmation_label/><cms:confirmation/></li>
    <li><cms:register_button/></li>
   </ol>
  </cms:register_form>
</cms:login_page>

<cms:address_page>
 <cms:cart/>
 <div class='webiva_form shop_form shop_address_form'>
   <h2>Please enter your <cms:shippable>shipping and billing addresses</cms:shippable>
                      <cms:not_shippable>billing address</cms:not_shippable> </h2>
   <cms:shippable>
     <h4>Shipping Address</h4>
     <cms:shipping_address/>
   </cms:shippable>
 
   <h4>Billing Address</h4>
   <cms:billing_address/>

   <div class='webiva_form_button'>
      <cms:continue_button/>
   </div>

  </div>
</cms:address_page>

<cms:payment_page>
  <cms:cart/>
  <div class='shop_payment_form'>
  <cms:message><div class='error'><cms:value/></div></cms:message>
  <b><cms:name/></b>, please confirm your order and enter your payment information.
  
  <h4>Order addresses (<cms:edit_link>Edit</cms:edit_link>)</h4>
  <div class='shop_order_address'>
     Bill To:<br/><cms:billing_address/>
  </div>
  
  <cms:shippable>
    <div class='shop_order_address'>
       Ship To:<br/><cms:shipping_address/>
    </div>
  
  <h4>Shipping Options:</h4>
  <cms:shipping_options/>
  <cms:no_shipping>There are no shipping options available to your destination</cms:no_shipping>
  </cms:shippable>

  <cms:show_gift>
   <h4>Gift Options</h4>
   <cms:gift/>
  </cms:show_gift>
  
  <cms:payment_options>
  <h4>Payment:</h4>
    <cms:value/>
  </cms:payment_options>
  <cms:no_payment><div class='error'>There are no payment processors available</div></cms:no_payment>

  
  <div class='webiva_form_button'>
      <cms:payment_button/>
  </div>
  
  </div>
</cms:payment_page>
<cms:processing_page>
  Please wait your order is processing..
</cms:processing_page>

<cms:success_page>
  Your Order has been processed successfully
</cms:success_page>
</div>
FEATURE

 def shop_checkout_feature(data)
  webiva_feature('shop_checkout') do |c|
    c.define_tag('cart') { |c| data[:cart_feature] }
    c.expansion_tag('shippable') { |c| data[:order_processor].shippable }
    c.value_tag('name') { |t| myself.name }

    c.expansion_tag('login_page') { |c| data[:page] == 'login' }
       c.value_tag('login_page:login_form:errors') { |t| data[:invalid_login] ? "Please verify your login credentials".t : nil }
       c.form_for_tag('login_page:login_form',:login) { |t| data[:login] }
         c.field_tag('login_page:login_form:email')
         c.field_tag('login_page:login_form:password',:control => 'password_field')
         c.button_tag('login_page:login_form:login_button', :value => 'Login')
       c.form_error_tag('login_page:register_form:errors')
       c.form_for_tag('login_page:register_form',:register) { |t| data[:user] }
         c.field_tag('login_page:register_form:first_name')
         c.field_tag('login_page:register_form:last_name')
         c.field_tag('login_page:register_form:email')
         c.expansion_tag('login_page:register_form:guest_allowed') { |t| data[:options].guest_allowed } 
         c.field_tag('login_page:register_form:password',:control => 'password_field')
         c.field_tag('login_page:register_form:confirmation',:control => 'password_field',:field => 'password_confirmation')
         c.button_tag('login_page:register_form:register_button', :value => 'Continue')
              
    c.define_tag('address_page') do |t| 
        if data[:page] == 'address' 
           address_javascript + form_tag('') + t.expand + "</form>"
        else
          nil
        end
    end
      c.define_tag('address_page:shipping_address') do |t| 
        shipping_opts = { :size => 15,:required => true }
        render_to_string(:partial => '/shop/processor/address_form', :locals => {
            :address_type => 'shipping',
            :opts => shipping_opts,
            :order_processor => data[:order_processor],
            :state_info => data[:order_processor].state_information(:shipping),
            :countries => data[:countries],
            :same_address => false,
            :options => data[:options] })
      end

      c.define_tag('address_page:billing_address') do |t| 
           billing_opts = { :size => 15, :required => true, 
             :disabled => data[:order_processor].shippable && data[:order_processor].same_address } 
        render_to_string(:partial => '/shop/processor/address_form', :locals => {
            :address_type => 'billing',
            :order_processor => data[:order_processor],
            :state_info => data[:order_processor].state_information(:billing),
            :countries => data[:countries],
            :opts => billing_opts,
            :same_address =>  data[:order_processor].shippable && data[:order_processor].same_address,
            :options => data[:options] })
      end

      c.button_tag('address_page:continue_button', :value => "Continue")

    c.define_tag('payment_page') do |t| 
      if data[:page] == 'payment'
        form_tag('',:id => 'submit_form') + 
          "<input type='hidden' name='update' id='shopping_form_update' value='0' />" +
          t.expand + 
          "</form>"
      else
        nil
      end
    end
       c.value_tag('payment_page:message') { |t| 
         if data[:message]  
           "There was a problem processing your transaction. (#{data[:message]})"
         elsif data[:order_processor].errors
           if  data[:order_processor].errors.is_a?(Array)
             data[:order_processor].errors.join(", ")
           else
             data[:order_processor].errors.full_messages.join(", ")
           end
         end
       }
    
       c.link_tag('payment_page:edit') { |t| data[:address_page] }


       c.value_tag('payment_page:billing_address') { |t| data[:order_processor].billing_address.display(t.attr['separator'] || "<br/>") }
       c.value_tag('payment_page:shipping_address') { |t| data[:order_processor].shipping_address.display(t.attr['separator'] || "<br/>") }
    
       c.expansion_tag('payment_page:shipping') { |t|  data[:order_processor].shipping_options.length > 0 }
       c.define_tag('payment_page:shipping_options') do |t|
          if  data[:order_processor].shipping_options.length > 0 
            render_to_string :partial => '/shop/processor/shipping_options', :locals => {
              :order_processor => data[:order_processor]
            } 
          end
       end

       c.expansion_tag('payment_page:show_gift') { |t|  data[:options].show_gift }
       c.define_tag('payment_page:show_gift:gift') do |t|
         render_to_string :partial => '/shop/processor/gift_options', :locals => {
              :order => data[:order_processor].order,
              :order_processor => data[:order_processor]
         }
       end

       c.expansion_tag('payment_page:payment') { |t|  data[:order_processor].payment_processors.length > 0 }
       c.define_value_tag('payment_page:payment_options') do |t|
         if data[:order_processor].payment_processors.length > 0 && data[:order_processor].cart.total > 0
          render_to_string  :partial => '/shop/processor/payment_processors', :locals => {
                  :payment_processors => data[:order_processor].payment_processors,
                  :admin => false, 
                  :payment => data[:order_processor].payment, 
                  :user => data[:order_processor].user } 
         end
       end

       c.button_tag('payment_page:payment_button',:value => 'Process Order')
    
    c.expansion_tag('processing_page') { |t| data[:page] == 'processing' }
    c.expansion_tag('success_page') { |t| data[:page] == 'success' }
  end

 end


 def address_javascript
   <<-JAVASCRIPT
<script>
  var AddressManager = {
    updateBilling: function(disableBilling) {
      fields =  $A([ 'company','first_name','last_name','address','address_2','city','state','zip','phone','fax','country','state_select' ]);
      fields.each(function(fld) {
          if($('billing_address_' + fld))
            $('billing_address_' + fld).disabled = disableBilling;
      });
    },
    
    updateShippingCountry : function(country) {
    
      var existingState = '';
      if($('shipping_address_state_select'))
        existingState = $('shipping_address_state_select').value;
      else if($('shipping_address_state'))
        existingState = $('shipping_address_state').value;
      var params = { state: existingState, country: country };      
      new Ajax.Request('#{url_for :controller => "/shop/processor", :action => "update_shipping_country"}',
                       { parameters: params});
    
    },
    
    updateBillingCountry: function(country) {
    
      if($('billing_address_state_select'))
        existingState = $('billing_address_state_select').value;
      else if($('billing_address_state'))
        existingState = $('billing_address_state').value;
      var params = { state: existingState, country: country };
      
      new Ajax.Request('#{url_for :controller => "/shop/processor", :action => "update_billing_country"}',
                       { parameters: params });
    
    }
  }
</script>

JAVASCRIPT
 end
end
