-- Core data models for TaxFlow foundation

-- Tax years table
CREATE TABLE IF NOT EXISTS tax_years (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  year INTEGER NOT NULL,
  status TEXT DEFAULT 'open',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE (user_id, year)
);

-- Categories table
CREATE TABLE IF NOT EXISTS categories (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
  description TEXT,
  is_system BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Readiness status table
CREATE TABLE IF NOT EXISTS readiness_status (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  tax_year_id UUID REFERENCES tax_years(id) ON DELETE CASCADE,
  score NUMERIC(5, 2) DEFAULT 0,
  status TEXT DEFAULT 'not_started',
  missing_items JSONB DEFAULT '[]'::jsonb,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE (user_id, tax_year_id)
);

-- Income entries table
CREATE TABLE IF NOT EXISTS income_entries (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  tax_year_id UUID REFERENCES tax_years(id) ON DELETE SET NULL,
  amount NUMERIC(12, 2) NOT NULL CHECK (amount >= 0),
  currency TEXT DEFAULT 'USD',
  received_date DATE NOT NULL,
  source TEXT,
  description TEXT,
  category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Expense entries table
CREATE TABLE IF NOT EXISTS expense_entries (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  tax_year_id UUID REFERENCES tax_years(id) ON DELETE SET NULL,
  amount NUMERIC(12, 2) NOT NULL CHECK (amount >= 0),
  currency TEXT DEFAULT 'USD',
  expense_date DATE NOT NULL,
  vendor TEXT,
  payment_method TEXT,
  receipt_url TEXT,
  description TEXT,
  category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Audit log table
CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  entity_type TEXT NOT NULL,
  entity_id UUID NOT NULL,
  action TEXT NOT NULL,
  changes JSONB NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Optional category linkage for transactions
ALTER TABLE transactions
  ADD COLUMN IF NOT EXISTS category_id UUID REFERENCES categories(id) ON DELETE SET NULL;

-- Indexes for lookups
CREATE INDEX IF NOT EXISTS tax_years_user_id_idx ON tax_years(user_id);
CREATE INDEX IF NOT EXISTS categories_user_id_idx ON categories(user_id);
CREATE INDEX IF NOT EXISTS readiness_status_user_id_idx ON readiness_status(user_id);
CREATE INDEX IF NOT EXISTS readiness_status_tax_year_id_idx ON readiness_status(tax_year_id);
CREATE INDEX IF NOT EXISTS income_entries_user_id_idx ON income_entries(user_id);
CREATE INDEX IF NOT EXISTS income_entries_tax_year_id_idx ON income_entries(tax_year_id);
CREATE INDEX IF NOT EXISTS expense_entries_user_id_idx ON expense_entries(user_id);
CREATE INDEX IF NOT EXISTS expense_entries_tax_year_id_idx ON expense_entries(tax_year_id);
CREATE INDEX IF NOT EXISTS audit_logs_user_id_idx ON audit_logs(user_id);

-- Enable RLS
ALTER TABLE tax_years ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE readiness_status ENABLE ROW LEVEL SECURITY;
ALTER TABLE income_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE expense_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- RLS policies
CREATE POLICY "Users can view own tax years" ON tax_years
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own tax years" ON tax_years
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own tax years" ON tax_years
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can view own categories" ON categories
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own categories" ON categories
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own categories" ON categories
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own categories" ON categories
  FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "Users can view own readiness status" ON readiness_status
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own readiness status" ON readiness_status
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own readiness status" ON readiness_status
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can view own income entries" ON income_entries
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own income entries" ON income_entries
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own income entries" ON income_entries
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own income entries" ON income_entries
  FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "Users can view own expense entries" ON expense_entries
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own expense entries" ON expense_entries
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own expense entries" ON expense_entries
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own expense entries" ON expense_entries
  FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "Users can view own audit logs" ON audit_logs
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own audit logs" ON audit_logs
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Audit trigger function
CREATE OR REPLACE FUNCTION log_audit_change()
RETURNS TRIGGER AS $$
DECLARE
  record_id UUID;
  record_user_id UUID;
  changes JSONB;
BEGIN
  IF (TG_OP = 'DELETE') THEN
    record_id := OLD.id;
    record_user_id := OLD.user_id;
    changes := jsonb_build_object('before', to_jsonb(OLD));
  ELSIF (TG_OP = 'UPDATE') THEN
    record_id := NEW.id;
    record_user_id := NEW.user_id;
    changes := jsonb_build_object('before', to_jsonb(OLD), 'after', to_jsonb(NEW));
  ELSE
    record_id := NEW.id;
    record_user_id := NEW.user_id;
    changes := jsonb_build_object('after', to_jsonb(NEW));
  END IF;

  INSERT INTO audit_logs (user_id, entity_type, entity_id, action, changes)
  VALUES (COALESCE(auth.uid(), record_user_id), TG_TABLE_NAME, record_id, TG_OP, changes);

  IF (TG_OP = 'DELETE') THEN
    RETURN OLD;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Attach audit triggers
DROP TRIGGER IF EXISTS audit_transactions ON transactions;
CREATE TRIGGER audit_transactions
  AFTER INSERT OR UPDATE OR DELETE ON transactions
  FOR EACH ROW EXECUTE FUNCTION log_audit_change();

DROP TRIGGER IF EXISTS audit_categories ON categories;
CREATE TRIGGER audit_categories
  AFTER INSERT OR UPDATE OR DELETE ON categories
  FOR EACH ROW EXECUTE FUNCTION log_audit_change();

DROP TRIGGER IF EXISTS audit_readiness_status ON readiness_status;
CREATE TRIGGER audit_readiness_status
  AFTER INSERT OR UPDATE OR DELETE ON readiness_status
  FOR EACH ROW EXECUTE FUNCTION log_audit_change();
