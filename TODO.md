# TODO — Quickshell Games Launchers

Liste des correctifs et améliorations à reprendre, par ordre de priorité.

---

## 🟢 Refactoring (priorité basse)

### 6. Éclater les gros fichiers QML

**Problème** : 3 fichiers à plus de 900 lignes deviennent durs à maintenir.

| Fichier | Lignes | Suggestion de découpage |
|---------|--------|-------------------------|
| `GameLauncher.qml` | 1075 | `GameLauncher` + `GameGrid.qml` + `SearchBar.qml` + `Sidebar.qml` |
| `ConfigPanel.qml` | 1177 | `ConfigPanel` + `ConfigSection.qml` + `ConfigTab.qml` |
| `BigPictureView.qml` | 936 | `BigPictureView` + `HeroBanner.qml` + `StatsPanel.qml` + `GameStrip.qml` |

**Méthode** : À faire petit à petit, un composant à la fois. Pour chaque extraction :
1. Identifier un bloc cohérent (ex: tout ce qui concerne la sidebar)
2. Créer le nouveau fichier `.qml`
3. Couper-coller le code, remplacer par une instance du composant
4. Passer les propriétés et signaux nécessaires
5. Tester que rien ne casse
6. Commit avec un message clair (ex: `refactor: extract Sidebar component`)

**Effort** : 2-3 heures total, idéalement étalé sur plusieurs sessions

---

## 🌍 Visibilité (à faire quand prêt)

### 9. Poster sur r/unixporn et r/hyprland

**Quand** : ✅ v2.0.0 tagguée, CHANGELOG en place — **prêt à poster**

**Quoi poster** :
- Titre accrocheur : "Quickshell game launcher with Matugen + Big Picture mode [OC]"
- La vidéo demo (déjà dans le repo)
- Lien GitHub
- Mention rapide des features clés (Steam + Heroic + Big Picture + Matugen)

**Subs** :
- r/unixporn — focus visuel
- r/hyprland — focus technique
- r/linux_gaming — focus gaming

---

### 10. Soumettre à awesome-hyprland

**Repo** : https://github.com/hyprland-community/awesome-hyprland

**Action** : Faire un PR pour ajouter le projet dans la section appropriée (launchers / shells / utilities).

**Effort** : 15 minutes

---

## ✅ Tout ce qui est fait

### Bugs corrigés
- ✅ **MouseArea cassé** (`shell.qml`) — cliquer hors du launcher le ferme maintenant correctement (`commit 3b8cdd0`)
- ✅ **Flash config au démarrage** — `configLoaded` gate, launcher invisible jusqu'à réception de la vraie config (`commit 63c926b`)
- ✅ **CfgText ne commitait pas au clic Save** — commit ajouté sur `onActiveFocusChanged` (`commit e24d48f`)
- ✅ **CfgSlider / CfgSpin / CfgText valeurs au démarrage** — binding QML préservé via `signal changed(T v)`)
- ✅ **CfgArea (library_paths) ne sauvegardait pas** — passage à `onTextChanged`
- ✅ **Erreur tomlkit manquant silencieuse** — message d'erreur rouge affiché dans le footer du ConfigPanel (`commit 6d0c7c2`)

### Features ajoutées (v2.0.0)
- ✅ **ConfigPanel graphique** — 9 sections, éditeur live sans restart
- ✅ **Support Matugen** (Material You) — toggle exclusif avec Wallust, template JSON, intégration backend
- ✅ **i18n ConfigPanel** — tous les labels/descriptions traduits (fr/en/es/ru/ja)
- ✅ **Prévisualisation palette** — 18 swatches de couleur dans la section Apparence
- ✅ **Lutris** — scanner bibliothèque via pga.db
- ✅ **start_in_bigpicture** — option config + toggle ConfigPanel
- ✅ **Bouton config en Big Picture** — accès ConfigPanel depuis le mode plein écran
- ✅ **F5 refresh** — rechargement de la liste de jeux
- ✅ **Lazy loading + loading dots**

### Release & docs
- ✅ **Tag v2.0.0** pushé sur GitHub
- ✅ **CHANGELOG.md** créé (`commit 63c926b`)
- ✅ **README v2.0.0** — section Matugen, config corrigée, badges, structure mise à jour
- ✅ **requirements.txt** — `tomlkit` ajouté

### Refactoring
- ✅ **`fonction/` → `helpers/`** — renommé, imports mis à jour, testé (`commit 6d0c7c2`)
- ✅ **CI GitHub Actions** — `.github/workflows/ci.yml` syntax check + import check (`commit 6d0c7c2`)
- ✅ **Logging** des `except: pass` silencieux remplacé par stderr
- ✅ **subprocess** gardé (ThreadPoolExecutor testé, causait des problèmes de re-render)

---

## 📋 Notes diverses

### Sur la décision subprocess vs threading
On avait tenté un refactor du `_spawn_image_downloader` en `ThreadPoolExecutor` mais l'UI ne se rafraîchissait pas pendant les downloads (Quickshell ne re-rendait pas les nouvelles images du cache). Le subprocess actuel marche, on garde.

**Si on veut y revenir un jour** : il faudrait un `FileSystemWatcher` QML ou un Timer qui re-check le cache toutes les X secondes, ou un signal envoyé par le backend quand le download finit.

### Sur les commits
Style préféré pour les messages :
- `feat:` pour les nouvelles features
- `fix:` pour les bugs
- `refactor:` pour les changements internes sans nouvelle feature
- `docs:` pour la doc
- `chore:` pour la maintenance (deps, gitignore, etc.)
