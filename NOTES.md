
## Assumptions

I assume that once an invoice and invoice item is created, never is updated. 

The usage is somehow stored in the system, once the billing period is finished, 
a invoice with its items is created and sync with Stripe, but an invoice cannot be modified 
(if there is a need for a charge back, a invoice with negative amount can be generated).

## The models

In the invoice_items, I added the concept to the describe the item, the number (quantity)
and the amount per unit (amount_per_unit)

I also store the id of the item in stripe (stripe_id) and a error if there has been one sync
this item (stripe_error).

In invoices I added the stripe_error, a state (pending, successful, error) and the current
number of retries, so we only retry N times.

More fields that I would add to the invoices table: 
  - a reference id (not the database id)
  - VAT information
  - if the invoice is paid or not
  - the next time it will try to charge
  - if the invoice has been charged back
  - the payment method used

In the invoice_items table I would add the VAT information for the item.

## About Sync process

In order to run the sync with Stripe I would do a rake task that is executed every hour/day
with Cron (using whenever for instance).

This task would call Invoice.stripe_sync_invoices. This method gets all the invoices that are
pending to sync (because are new or there has been an error previously) and enqueues an
ActiveJob task that syncs the invoice with Stripe (method Invoice#stripe_sync).

Invoice#stripe_sync would try to sync the Invoice and InvoiceItem, if there is a previous error,
it tries to sync again only the missing part. It syncs with Stripe until is successful or 
the number of retries has reached Invoice.MAX_RETRIES, this is a final state that someone
will need to review. In this case, we should alert customer service in order to review it manually.

When there is a final error after tried Invoice.MAX_RETRIES, we can use Invoice#error_message 
to show an error to the user.

## About Invoice.summarize_by_month

This method calculates the total invoiced by month. It makes a GROUP BY month(due_date) 
that SUMS all the amount of the invoice_items. 
I created a calculated column (due_month) with only the month, this way we can make an
index with the state (we only sum invoices that are sync with Stripe) and the month to 
make the aggregation faster, there is also an index in invoice_items.invoice_id to make 
the join faster.

I have not added a total_amount field in invoices because I don't like to abuse duplicating
data and calculating this field when creating the Invoice or adding invoice_items,
but if with real data we see that the query is too slow we can add this field, 
or even better, a separated table with the totals by month for the months that are closed. 
