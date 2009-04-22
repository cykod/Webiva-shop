

class Shop::UserFeature < ParagraphFeature


  feature :shop_user_orders, :default_feature => <<-FEATURE
    <cms:orders>
    <table>
    <thead>
      <tr>
        <th>Order #</td>
        <th>Ordered</th>
        <th>Address</th>
        <th>Total</th>
        <th>Status</th>
      </tr>
    </thead>
    <tbody>
    <cms:order>
    <tr>
      <td><cms:detail_link>#<cms:number/></cms:detail_link></td>
      <td><cms:ordered_at/></td>
      <td><cms:address/></td>
      <td><cms:total/></td>
      <td><cms:status/></td>
    </tr/>
    </cms:order>
    </tbody>
    </table>
    </cms:orders>
  FEATURE

  def shop_order_tags(c,data)
      c.value_tag('order:number') { |t| t.locals.order.id }
      c.link_tag('order:detail') { |t| data[:detail_url].to_s + "/" + t.locals.order.id.to_s }
      c.date_tag('order:ordered_at',DEFAULT_DATE_FORMAT.t) { |t| t.locals.order.ordered_at }
      c.value_tag('order:address') { |t| t.locals.order.shipping_address[:address] || t.locals.order.billing_address[:address] }
      c.value_tag('order:status') { |t| t.locals.order.state_display }
      c.value_tag('order:total') { |t| t.locals.order.display_total }
      c.date_tag('order:shipped_at', DEFAULT_DATE_FORMAT.t) { |t| t.locals.order.shipped_at }
      c.value_tag('order:subtotal') { |t| t.locals.order.display_subtotal }
      c.value_tag('order:tax') { |t| t.locals.order.display_tax }
      c.value_tag('order:shipping') { |t| t.locals.order.display_shipping }
      c.value_tag('order:refund') { |t| t.locals.order.display_refund if t.locals.order.refund > 0 }
      c.expansion_tag('order:shippable') { |t| t.locals.order.shop_shipping_category_id.to_i > 0  }
      c.user_tags('user') { |t| t.locals.order.end_user }
      c.value_tag('order:billing_address') { |t| t.locals.order.display_billing_address.gsub("\n","<br/>") }
      c.value_tag('order:shipping_address') { |t| t.locals.order.display_shipping_address.gsub("\n","<br/>") if t.locals.order.shop_shipping_category_id.to_i > 0 }
  end  
  

  def shop_user_orders_feature(data)
    webiva_feature(:shop_user_orders) do |c|
      c.loop_tag('order') { |t| data[:orders] }
        shop_order_tags(c,data)
        c.pagelist_tag('orders:pages') { |t| data[:pages] }
    end
  end
  feature :shop_user_order_detail, :default_feature => <<-FEATURE
      <cms:order>
      <h2>Order #<cms:number/></h2>
      Ordered <cms:ordered_at/> by <cms:user:name /><br/><br/>
      <b>Bill To:</b><br/>
      <cms:billing_address/><br/>
      <cms:shipping_address>
      <b>Ship To:</b><br/>
      <cms:value/>      
      </cms:shipping_address>
      <table class='order_table' width='100%'>
      <cms:shipment>
        <tr>
          <td colspan='5'>
           <b>Shipped <cms:shipped_at/> <cms:carrier_name/> <cms:tracking>Tracking Number:<cms:value/></cms:tracking></b><br/>
           <cms:deliver_on><b>Estimated Delivery: <cms:value/></b><br/></cms:deliver_on>
          </td>
        </tr>
        <tr><th>Item</th><th>Unit Cost</th><th colspan='2'>Qty.</th><th>Subtotal</th></tr>
        <cms:item>
        <tr>
          <td valign='baseline'><cms:name/><br/><cms:details/></td>
          <td valign='baseline'><cms:unit_cost/></td>
          <td valign='baseline'>X</td>
          <td valign='baseline'><cms:quantity/></td>
          <td align='right' valign='baseline'><cms:subtotal/></td>
        </tr>
        </cms:item>
      </cms:shipment>
      <cms:unshipped>
      <cms:shippable><tr><td colspan='5'><b>Items not yet shipped</b></td></tr></cms:shippable>
        <tr><th>Item</th><th>Unit Cost</th><th colspan='2'>Qty.</th><th>Subtotal</th></tr>
        <cms:item>
        <tr>
          <td valign='baseline'><cms:name/><br/><cms:details/></td>
          <td valign='baseline'><cms:unit_cost/></td>
          <td valign='baseline'>X</td>
          <td valign='baseline'><cms:quantity/></td>
          <td align='right' valign='baseline'><cms:subtotal/></td>
        </tr>
        </cms:item>
      </cms:unshipped>
      <tr><td colspan='5'><hr/></td></tr>
      <tr><td colspan='4' align='right'>Subtotal:</td><td align='right'><cms:subtotal/></td></tr>
      <tr><td colspan='4' align='right'>Tax:</td><td align='right'><cms:tax/></td></tr>
      <tr><td colspan='4' align='right'>Shipping:</td><td align='right'><cms:shipping/></td></tr>
      <cms:refund><tr><td colspan='4' align='right'>Refund:</td><td align='right'><cms:value/></td></tr></cms:refund>
      <tr><td colspan='4' align='right'>Total:</td><td align='right'><cms:total/></td></tr>
      </table>
      </cms:order>
      <cms:no_order>
        Invalid Order
      </cms:no_order>
  FEATURE
  

  def shop_user_order_detail_feature(data)
    webiva_feature(:shop_user_order_detail) do |c|
      c.expansion_tag('order') { |t| t.locals.order=data[:order] }
       shop_order_tags(c,data)
       c.loop_tag('shipment') { |t| data[:order].shop_order_shipments }
         c.value_tag('shipment:carrier_name') { |t| t.locals.shipment.shop_carrier ? t.locals.shipment.shop_carrier.name : nil }
         c.value_tag('shipment:tracking') { |t| t.locals.shipment.tracking_number }
         c.date_tag('shipment:deliver_on') { |t| t.locals.shipment.deliver_on }
         c.loop_tag('shipment:item') { |t| t.locals.shipment.order_items }
          define_items_tag(c,'shipment:item:')
       c.expansion_tag('unshipped') { |t| t.locals.order.unshipped_items.length > 0 }
       c.define_tag('unshipped:item') { |t| c.each_local_value(t.locals.order.unshipped_items,t,"item") }
         define_items_tag(c,'unshipped:item:')
    end
  end
  
  def define_items_tag(c,name_base) 
    c.value_tag(name_base + 'sku') { |t| t.locals.item.item_sku }
    c.value_tag(name_base + 'name') { |t| t.locals.item.item_name }
    c.value_tag(name_base + 'details') { |t| t.locals.item.item_details }
    c.value_tag(name_base + 'unit_cost') { |t| t.locals.item.display_unit_price }
    c.value_tag(name_base + 'quantity') { |t| t.locals.item.quantity }
    c.value_tag(name_base + 'subtotal') { |t| t.locals.item.display_subtotal }
  end


end
