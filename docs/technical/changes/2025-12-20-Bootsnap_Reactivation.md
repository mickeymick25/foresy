# ⚡ Réactivation de Bootsnap - 20 Décembre 2025
Historique / état au 2025-12-20


**Date :** 20 décembre 2025  
**Projet :** Foresy API  
**Type :** Optimisation - Performance de démarrage  
**Status :** ✅ **COMPLÉTÉ**

---

## 🎯 Problème Identifié

### Analyse CI - Point 7

> Commenter bootsnap dans config/boot.rb
>
> bootsnap est commenté — diminue les perf de boot mais évite FrozenError précédemment rencontré. Si vous voulez le remettre, validez qu'il ne casse pas la CI.

### État Avant

```ruby
# config/boot.rb
require 'bundler/setup'
# require 'bootsnap/setup' # Speed up boot time by caching expensive operations.
```

Bootsnap était désactivé pour contourner un FrozenError rencontré précédemment.

---

## ✅ Solution Appliquée

Réactivation de bootsnap après validation que le FrozenError a été résolu (probablement par les mises à jour de gems récentes).

### Fichier Modifié

**`config/boot.rb`** :

```ruby
# frozen_string_literal: true

ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)

require 'bundler/setup' # Set up gems listed in the Gemfile.
require 'bootsnap/setup' # Speed up boot time by caching expensive operations.
```

---

## 📊 Bénéfices de Bootsnap

Bootsnap accélère le temps de démarrage de Rails en :

1. **Caching des fichiers Ruby** - Évite le re-parsing des fichiers
2. **Caching des chemins de chargement** - Accélère les `require`
3. **Caching de YAML** - Accélère le chargement des configurations

### Performance Typique

| Métrique | Sans Bootsnap | Avec Bootsnap |
|----------|---------------|---------------|
| Boot time (1er) | ~5s | ~5s |
| Boot time (suivants) | ~5s | ~2-3s |

---

## 🧪 Validation

### Tests RSpec

```
97 examples, 0 failures
```

### Rubocop

```
70 files inspected, no offenses detected
```

### Pas de FrozenError

Aucune erreur FrozenError observée lors des tests.

---

## ⚠️ Note

Si le FrozenError réapparaît dans le futur, les causes possibles sont :

1. Modification d'une chaîne frozen (utiliser `.dup` ou `.freeze`)
2. Conflit avec une gem qui modifie des constantes
3. Problème de cache bootsnap (solution: `rm -rf tmp/cache/bootsnap*`)

Pour désactiver bootsnap en cas de problème :

```ruby
# config/boot.rb
# require 'bootsnap/setup'
```

---

## 🏷️ Tags

- **⚡ PERFORMANCE** : Optimisation temps de boot
- **⚙️ CONFIG** : Configuration boot.rb
- **MINEUR** : Amélioration non fonctionnelle

---

**Document créé le :** 20 décembre 2025  
**Responsable technique :** Équipe Foresy