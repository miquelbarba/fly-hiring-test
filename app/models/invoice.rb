class Invoice < ApplicationRecord
  has_many :invoice_items, dependent: :destroy

  validates :stripe_sync_state, inclusion: { in: %w[pending successful error] },
                                presence: true

  def self.stripe_sync_invoices
    where(stripe_sync_state: :pending).find_each do |invoice|
      InvoiceSyncJob.perform_later(invoice)
    end
  end

  def self.summarize_by_month
    arr = InvoiceItem
            .select("invoices.due_month month, "\
                    'SUM(invoice_items.amount_per_unit * invoice_items.quantity) total')
            .joins(:invoice)
            .where(invoices: { stripe_sync_state: :successful })
            .group('invoices.due_month')

    arr.map do |item|
      item.slice(:month, :total)
    end
  end

  MAX_RETRIES = 5
  TIMEOUT = 10.seconds

  def stripe_sync
    # We execute this inside Timeout to simulate it. In real life this is not needed,
    # the timeout would be raised from the connection
    Timeout::timeout(TIMEOUT) do
      _stripe_sync
    end
  rescue Timeout::Error
    update(stripe_error: 'Timeout sync with Stripe')
    increase_num_retries
  end

  def successful? = stripe_sync_state == 'successful'

  def error? = stripe_sync_state == 'error'

  def pending? = stripe_sync_state == 'pending'

  def error_message
    stripe_error || invoice_items.find(&:stripe_error)&.stripe_error
  end

  private

  def _stripe_sync
    return if final_state?

    # we only sync invoices with items, otherwise there is nothing to charge
    return if invoice_items.empty?

    create_in_stripe if !invoice_in_stripe?

    sync_all_items if self.stripe_id.present?
  rescue Stripe::StripeError => e
    update!(stripe_error: e.message)
    increase_num_retries
  rescue Timeout::Error
    update(stripe_error: 'Timeout sync with Stripe')
    increase_num_retries
  end

  def final_state? = successful? || error?

  def invoice_in_stripe?
    Stripe::Invoice.retrieve(id)
    true
  rescue Stripe::InvalidRequestError
    false
  end

  def create_in_stripe
    stripe_invoice = Stripe::Invoice.create(id: id, customer: stripe_customer_id)
    update!(stripe_id: stripe_invoice.stripe_id)
  end

  def increase_num_retries
    return update!(stripe_sync_state: :error) if stripe_num_retries == MAX_RETRIES

    update!(stripe_num_retries: stripe_num_retries + 1)
  end

  def sync_all_items
    result = invoice_items.map do |invoice_item|
      invoice_item.stripe_sync
    end

    return update!(stripe_sync_state: 'successful') if result.all?

    increase_num_retries
  end
end
