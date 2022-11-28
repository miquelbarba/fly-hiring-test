CREATE TABLE IF NOT EXISTS "schema_migrations" ("version" varchar NOT NULL PRIMARY KEY);
CREATE TABLE IF NOT EXISTS "ar_internal_metadata" ("key" varchar NOT NULL PRIMARY KEY, "value" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE TABLE IF NOT EXISTS "invoices" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "stripe_id" varchar, "stripe_customer_id" varchar, "stripe_error" varchar, "stripe_num_retries" integer(1) DEFAULT 0, "stripe_sync_state" varchar DEFAULT 'pending', "due_date" date, "invoiced_at" datetime, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, due_month
        GENERATED ALWAYS AS (strftime('%m', due_date)));
CREATE TABLE sqlite_sequence(name,seq);
CREATE INDEX "index_invoices_on_stripe_sync_state_and_due_month" ON "invoices" ("stripe_sync_state", "due_month");
CREATE TABLE IF NOT EXISTS "invoice_items" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "invoice_id" integer NOT NULL, "concept" varchar NOT NULL, "quantity" integer NOT NULL, "amount_per_unit" decimal(8,2) NOT NULL, "stripe_id" varchar, "stripe_error" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_25bf3d2c5e"
FOREIGN KEY ("invoice_id")
  REFERENCES "invoices" ("id")
);
CREATE INDEX "index_invoice_items_on_invoice_id" ON "invoice_items" ("invoice_id");
INSERT INTO "schema_migrations" (version) VALUES
('20221027223051'),
('20221128083206');


