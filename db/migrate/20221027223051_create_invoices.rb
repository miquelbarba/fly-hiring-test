class CreateInvoices < ActiveRecord::Migration[7.0]
  def change
    create_table :invoices do |t|
      t.string :stripe_id
      t.string :stripe_customer_id

      t.string :stripe_error
      t.integer :stripe_num_retries, default: 0, limit: 1
      t.string :stripe_sync_state, default: 'pending'

      t.date :due_date
      t.timestamp :invoiced_at

      t.timestamps

      t.index([:stripe_sync_state, :due_month])
    end

    up_only do
      execute <<-SQL
        ALTER TABLE invoices
        ADD COLUMN due_month
        GENERATED ALWAYS AS (strftime('%m', due_date))
      SQL
    end
  end
end
