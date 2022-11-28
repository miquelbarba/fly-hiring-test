
class InvoiceSyncJob < ApplicationJob
  queue_as :default

  def perform(invoice)
    invoice.stripe_sync
  end
end
