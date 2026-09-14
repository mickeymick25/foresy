# 🔒 Mise à jour de sécurité des gems - 20 Décembre 2025
Historique / état au 2025-12-20


**Date :** 20 décembre 2025  
**Projet :** Foresy API  
**Type :** Correction sécurité - Mise à jour dépendances  
**Status :** ✅ **RÉSOLU**

---

## 🎯 Problème Identifié

### Erreur CI

```
bundle exec bundle audit check --update
Could not find command "audit".
Error: Process completed with exit code 15.
```

### Analyse

1. La gem `bundler-audit` n'était pas présente dans le Gemfile
2. Une fois ajoutée, `bundle audit` a révélé **20+ vulnérabilités** dans les dépendances

---

## 🔍 Vulnérabilités Détectées

### Critiques (High)

| Gem | Version | CVE | Problème |
|-----|---------|-----|----------|
| rack | 3.1.13 | CVE-2025-46727 | Unbounded-Parameter DoS |
| rack | 3.1.13 | CVE-2025-61770 | Unbounded multipart preamble DoS |
| rack | 3.1.13 | CVE-2025-61771 | Memory exhaustion DoS |
| rack | 3.1.13 | CVE-2025-61772 | Unbounded per-part headers DoS |
| rack | 3.1.13 | CVE-2025-61919 | URL-encoded body parsing DoS |

### Moyennes (Medium)

| Gem | Version | CVE | Problème |
|-----|---------|-----|----------|
| rack | 3.1.13 | CVE-2025-61780 | Information Disclosure |
| rack-session | 2.1.0 | CVE-2025-46336 | Session restored after deletion |

### Autres

| Gem | Version | CVE/GHSA | Problème |
|-----|---------|----------|----------|
| activerecord | 7.1.5.1 | CVE-2025-55193 | ANSI escape injection in logging |
| activestorage | 7.1.5.1 | CVE-2025-24293 | Unsafe transformation methods |
| nokogiri | 1.18.8 | GHSA-353f-x4gh-cqq8 | libxml2 CVEs |
| rexml | 3.4.1 | CVE-2025-58767 | DoS on malformed XML |
| thor | 1.3.2 | CVE-2025-54314 | Unsafe shell command |
| uri | 1.0.3 | CVE-2025-61594 | Credential leakage |

---

## ✅ Solution Appliquée

### 1. Ajout de bundler-audit

```ruby
# Gemfile
group :development, :test do
  gem 'bundler-audit'
  # ...
end
```

### 2. Mise à jour des gems vulnérables

```bash
docker-compose run --rm web bundle update rack rack-session nokogiri rexml thor uri activerecord activestorage
```

### 3. Versions après mise à jour

| Gem | Avant | Après |
|-----|-------|-------|
| rails | 7.1.5.1 | 7.1.6 |
| rack | 3.1.13 | 3.2.4 |
| rack-session | 2.1.0 | 2.1.1 |
| nokogiri | 1.18.8 | 1.18.10 |
| rexml | 3.4.1 | 3.4.4 |
| thor | 1.3.2 | 1.4.0 |
| uri | 1.0.3 | 1.1.1 |
| activesupport | 7.1.5.1 | 7.1.6 |
| activerecord | 7.1.5.1 | 7.1.6 |
| activestorage | 7.1.5.1 | 7.1.6 |
| actionpack | 7.1.5.1 | 7.1.6 |

---

## 🧪 Validation

### Bundle Audit

```bash
$ docker-compose run --rm web bundle exec bundle audit check --update

ruby-advisory-db:
  advisories: 1035 advisories
  last updated: 2025-12-16 11:19:05 -0800

No vulnerabilities found
```

### Tests RSpec

```
97 examples, 0 failures
```

### Rubocop

```
70 files inspected, no offenses detected
```

### Brakeman

```
Security Warnings: 0
Ignored Warnings: 1
```

---

## ⚠️ Note

Un warning de dépréciation apparaît dans les tests :

```
Status code :unprocessable_entity is deprecated and will be removed in a future version of Rack.
Please use :unprocessable_content instead.
```

Ce warning est cosmétique et n'affecte pas le fonctionnement. Il sera corrigé automatiquement lors de la migration vers Rails 8.x.

---

## 📋 Fichiers Modifiés

1. `Gemfile` - Ajout de bundler-audit
2. `Gemfile.lock` - Mise à jour des versions

---

## 🏷️ Tags

- **🔒 SECURITY** : Correction vulnérabilités
- **CRITIQUE** : 5+ vulnérabilités High corrigées
- **⚙️ CONFIG** : Mise à jour dépendances

---

## 📚 Références

- [Rack Security Advisories](https://github.com/rack/rack/security/advisories)
- [Rails Security Advisories](https://github.com/rails/rails/security/advisories)
- [Nokogiri Security Advisories](https://github.com/sparklemotion/nokogiri/security/advisories)
- [Ruby Advisory Database](https://github.com/rubysec/ruby-advisory-db)

---

**Document créé le :** 20 décembre 2025  
**Responsable technique :** Équipe Foresy