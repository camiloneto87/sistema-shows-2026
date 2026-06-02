-- ═══════════════════════════════════════════════════════════════
--  SISTEMA FINANCEIRO — Ana Clara & Ítalo 2026
--  Cole este SQL no Supabase → SQL Editor → New query → Run
-- ═══════════════════════════════════════════════════════════════

-- 1. TABELA DE SHOWS
CREATE TABLE IF NOT EXISTS shows (
  id           UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at   TIMESTAMPTZ DEFAULT now(),
  user_id      UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  show_id      TEXT NOT NULL,
  data         DATE NOT NULL,
  local        TEXT NOT NULL,
  uf           CHAR(2) NOT NULL,
  cache        NUMERIC(12,2) DEFAULT 0,
  comissao     NUMERIC(12,2) DEFAULT 0,
  custo        NUMERIC(12,2) DEFAULT 0,
  sinal        NUMERIC(12,2) DEFAULT 0,
  status       TEXT NOT NULL DEFAULT 'CONFIRMADO',
  obs          TEXT DEFAULT ''
);

-- 2. TABELA DE DESPESAS
CREATE TABLE IF NOT EXISTS despesas (
  id           UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at   TIMESTAMPTZ DEFAULT now(),
  user_id      UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  desp_id      TEXT NOT NULL,
  data         DATE NOT NULL,
  categoria    TEXT NOT NULL,
  descricao    TEXT DEFAULT '',
  valor        NUMERIC(12,2) NOT NULL,
  show_ref     TEXT DEFAULT ''
);

-- 3. TABELA DE PERFIS (admin ou viewer)
CREATE TABLE IF NOT EXISTS perfis (
  id        UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  nome      TEXT,
  role      TEXT DEFAULT 'viewer',
  criado_em TIMESTAMPTZ DEFAULT now()
);

-- 4. ATIVAR SEGURANÇA POR LINHA (RLS)
ALTER TABLE shows    ENABLE ROW LEVEL SECURITY;
ALTER TABLE despesas ENABLE ROW LEVEL SECURITY;
ALTER TABLE perfis   ENABLE ROW LEVEL SECURITY;

-- 5. POLÍTICAS — SHOWS
CREATE POLICY "shows: admin vê tudo"
  ON shows FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM perfis WHERE id = auth.uid() AND role = 'admin')
    OR user_id = auth.uid()
  );

CREATE POLICY "shows: admin insere"
  ON shows FOR INSERT
  WITH CHECK (
    EXISTS (SELECT 1 FROM perfis WHERE id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "shows: admin atualiza"
  ON shows FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM perfis WHERE id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "shows: admin exclui"
  ON shows FOR DELETE
  USING (
    EXISTS (SELECT 1 FROM perfis WHERE id = auth.uid() AND role = 'admin')
  );

-- viewer pode ver todos os shows do admin (sem filtro de user_id)
CREATE POLICY "shows: viewer vê tudo"
  ON shows FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM perfis WHERE id = auth.uid() AND role = 'viewer')
  );

-- 6. POLÍTICAS — DESPESAS
CREATE POLICY "despesas: admin vê tudo"
  ON despesas FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM perfis WHERE id = auth.uid() AND role = 'admin')
    OR user_id = auth.uid()
  );

CREATE POLICY "despesas: admin insere"
  ON despesas FOR INSERT
  WITH CHECK (
    EXISTS (SELECT 1 FROM perfis WHERE id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "despesas: admin atualiza"
  ON despesas FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM perfis WHERE id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "despesas: admin exclui"
  ON despesas FOR DELETE
  USING (
    EXISTS (SELECT 1 FROM perfis WHERE id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "despesas: viewer vê tudo"
  ON despesas FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM perfis WHERE id = auth.uid() AND role = 'viewer')
  );

-- 7. POLÍTICAS — PERFIS
CREATE POLICY "perfis: cada um vê o próprio"
  ON perfis FOR SELECT
  USING (id = auth.uid());

CREATE POLICY "perfis: admin vê todos"
  ON perfis FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM perfis WHERE id = auth.uid() AND role = 'admin')
  );

-- 8. TRIGGER: criar perfil automaticamente ao cadastrar usuário
CREATE OR REPLACE FUNCTION public.criar_perfil()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.perfis (id, nome, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'nome', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'role', 'viewer')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.criar_perfil();

