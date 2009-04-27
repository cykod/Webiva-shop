
class Shop::ProcessorFeature < ParagraphFeature

  include ActionView::Helpers::FormTagHelper

 feature :full_cart, :default_feature => <<-FEATURE
    <cms:no_cart>
    You currently have no products in your shopping cart
    </cms:no_cart>
    <cms:cart>
      <cms:message><div class='cart_message'><cms:value/></div></cms:message>
    <table>
    <thead>
      <tr><th>Product</th><th>Unit Cost</th><th>Quantity</th><th>Cost</th></tr>
    </thead>
    <tbody>
    <cms:products>
      <cms:product>
      <tr>
          <td><b><cms:name/></b><br/><cms:details/></td>
          <td><cms:unit_cost/></td>
          <td><cms:quantity/></td>
          <td><cms:product_cost/></td>
      </tr>
      </cms:product>
    <tr>
      <td colspan='3' align='right'>Total:</td>
      <td><cms:total/></td>
    </tr>
    <tr>
      <td colspan='3' align='right'><cms:update_quantity>Update Quantity</cms:update_quantity></td>
    </tr>
    
    </cms:products>
    <tr>
    <td colspan='4'>
    <cms:coupon><cms:form>
     Promotional Code: <cms:code/> <cms:apply_button/>
    </cms:form></cms:coupon>
    </td>
    </tr>
    <tr>
      <td colspan='2' align='left'><cms:continue_shopping>Continue Shopping</cms:continue_shopping></td>
      <td colspan='2' align='right'><cms:checkout>Checkout</cms:checkout></td>
    </tr>
    </table>
    </cms:cart>
  FEATURE
      
 
def full_cart_feature(data)
   webiva_feature('full_cart') do |c|
      c.value_tag('user') { |t| myself.id ? myself.name : nil }
      c.expansion_tag('anonymous') { |t| !myself.id }
      c.expansion_tag('cart') { |t| data[:cart].products_count > 0 }

      c.expansion_tag('static') { |tag| data[:static] }
      
      c.define_tag 'cart:products' do |tag|
        <<-EOTAG
         <form action='' method='post'>
               <input type='hidden' name='shop#{data[:paragraph_id]}[action]' value='update_quantities'/>
          #{tag.expand}
          </form>
        EOTAG
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
            if tag.locals.cart_item.coupon?
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
            item_hash,opt_hash = quantity_hash(t.locals.cart_item)
            if t.attr['image']
             tag(:image, :name => "shop#{data[:paragraph_id]}[remove][#{item_hash}][#{opt_hash}]",:src => t.expand)
            else
             opts = t.attr.clone
             value = t.single? ? (opts.delete('value') || 'Remove') : t.expand
             tag(:input,  { :type => 'submit', :name => "shop#{data[:paragraph_id]}[remove][#{item_hash}][#{opt_hash}]",:value => value}.merge(t.attr))
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

          c.define_submit_tag('cart:products:update_quantity') { |t| !data[:static] }
      c.value_tag('message') { |t| data[:cart].messages.join("<br/>") }
      
      c.expansion_tag('cart:coupon') { |t| !data[:static] }
      c.form_for_tag('cart:coupon:form',"shop#{data[:paragraph_id]}",
        :code => "<input type='hidden' name='shop#{data[:paragraph_id]}[action]' value='coupon'/>" ) { |t| nil }
        c.field_tag('cart:coupon:form:code',:size => 10)
        c.submit_tag('cart:coupon:form:apply_button',:default => 'Apply')
          
          
      c.post_button_tag('cart:checkout',:button => 'Checkout',:method =>'get') { |t| data[:checkout_page] }
      c.post_button_tag('cart:continue_shopping',:button => 'Continue Shopping'.t,:method => 'get') { |t| session[:shop_continue_shopping_url_link] }
   end
  end
end
