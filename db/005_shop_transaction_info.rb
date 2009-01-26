class ShopTransactionInfo < ActiveRecord::Migration
  def self.up
    add_column :shop_order_transactions, :end_user_id, :integer
    add_column :shop_order_transactions, :transaction_reference, :integer
    
    add_column :shop_orders, :payment_type, :string, :default => 'standard'
    add_column :shop_orders, :payment_identifier, :string, :default => ''
  end

  def self.down
    
    remove_column :shop_order_transactions, :end_user_id
    remove_column :shop_order_transactions, :transaction_reference
    
    remove_column :shop_orders, :payment_type
    remove_column :shop_orders, :payment_identifier
  end

end
