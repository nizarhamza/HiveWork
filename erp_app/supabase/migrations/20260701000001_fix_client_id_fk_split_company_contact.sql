-- Replace the broken client_id FK (pointed at unused 'clients' table) with
-- proper company_id and contact_id columns referencing the CRM tables.
--
-- Background: the client picker lets users pick either a Company or a Contact
-- from the CRM. Storing the result as a single client_id→clients FK was wrong
-- because the UI never wrote to 'clients'. The snapshot JSONB was handling
-- display, but there was no referential integrity.
--
-- Existing client_id values in invoices were orphaned (matched neither
-- companies nor contacts) so no data migration is needed.

DROP VIEW IF EXISTS client_stats;

ALTER TABLE quotes   DROP CONSTRAINT quotes_client_id_fkey;
ALTER TABLE invoices DROP CONSTRAINT invoices_client_id_fkey;

ALTER TABLE quotes
  ADD COLUMN company_id UUID REFERENCES companies(id) ON DELETE SET NULL,
  ADD COLUMN contact_id UUID REFERENCES contacts(id)  ON DELETE SET NULL;

ALTER TABLE invoices
  ADD COLUMN company_id UUID REFERENCES companies(id) ON DELETE SET NULL,
  ADD COLUMN contact_id UUID REFERENCES contacts(id)  ON DELETE SET NULL;

ALTER TABLE quotes   DROP COLUMN client_id;
ALTER TABLE invoices DROP COLUMN client_id;
