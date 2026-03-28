-- De mba vakio tsara
-- ==========================================================
-- 1. EXTENSIONS ET NETTOYAGE (Optionnel)
-- ==========================================================

DROP TABLE IF EXISTS audit_inscription;
DROP TABLE IF EXISTS inscription;
DROP TABLE IF EXISTS utilisateurs;

-- ==========================================================
-- 2. TABLES DE RÉFÉRENCE
-- ==========================================================

-- Table des utilisateurs pour l'authentification via l'API
CREATE TABLE utilisateurs (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    role VARCHAR(20) DEFAULT 'agent'
);

-- Table principale 
CREATE TABLE inscription (
    matricule SERIAL PRIMARY KEY,
    nom VARCHAR(100) NOT NULL,
    droit_inscription DECIMAL(10, 2) NOT NULL
);

-- ==========================================================
-- 3. TABLE D'AUDIT
-- ==========================================================

CREATE TABLE audit_inscription (
    id SERIAL PRIMARY KEY,
    type_action VARCHAR(20),      -- 'INSERT', 'UPDATE', 'DELETE'
    date_mise_a_jour TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    matricule INT,
    nom VARCHAR(100),
    droit_ancien DECIMAL(10, 2),
    droit_nouv DECIMAL(10, 2),
    utilisateur VARCHAR(50)       -- Nom de l'utilisateur de l'API
);

-- ==========================================================
-- 4. LOGIQUE DU TRIGGER (GESTION DES SESSIONS API)
-- ==========================================================

CREATE OR REPLACE FUNCTION process_audit_ins() RETURNS TRIGGER AS $$
DECLARE
    -- Récupération de la variable de session définie
    current_api_user VARCHAR;
BEGIN
    -- On tente de lire la variable de session. Si elle n'existe pas, on met 'system'
    current_api_user := current_setting('myapp.current_user_name', true);
    IF current_api_user IS NULL OR current_api_user = '' THEN
        current_api_user := 'system_anonymous';
    END IF;

    IF (TG_OP = 'INSERT') THEN
        INSERT INTO audit_inscription(type_action, matricule, nom, droit_nouv, utilisateur)
        VALUES ('INSERT', NEW.matricule, NEW.nom, NEW.droit_inscription, current_api_user);
    
    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO audit_inscription(type_action, matricule, nom, droit_ancien, droit_nouv, utilisateur)
        VALUES ('UPDATE', OLD.matricule, OLD.nom, OLD.droit_inscription, NEW.droit_inscription, current_api_user);
    
    ELSIF (TG_OP = 'DELETE') THEN
        INSERT INTO audit_inscription(type_action, matricule, nom, droit_ancien, utilisateur)
        VALUES ('DELETE', OLD.matricule, OLD.nom, OLD.droit_inscription, current_api_user);
    END IF;
    
    RETURN NULL; 
END;
$$ LANGUAGE plpgsql;

-- Liaison du trigger
CREATE TRIGGER trg_audit_ins
AFTER INSERT OR UPDATE OR DELETE ON inscription
FOR EACH ROW EXECUTE FUNCTION process_audit_ins();

-- ==========================================================
-- 5. DONNÉES INITIALES ET TESTS
-- ==========================================================

-- Création d'un utilisateur de test (password: 'admin123' par exemple)
INSERT INTO utilisateurs (username, password_hash, role) 
VALUES ('admin_user', '$2b$12$ExempleHashBCrypt...', 'admin');

-- Exemple d'utilisation manuelle pour tester le trigger :
-- SET myapp.current_user_name = 'test_script';
-- INSERT INTO inscription (nom, droit_inscription) VALUES ('Jean Dupont', 150.00);