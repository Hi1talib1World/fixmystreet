BEGIN;

ALTER TABLE problem
    ADD COLUMN send_fail_types TEXT;

COMMIT;
