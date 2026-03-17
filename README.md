# Quickshell Launchers

Des launchers Quickshell pour Hyprland, avec intégration pywal/wallust.



![Preview](asset/image.png)



---

## Game Launcher



![Game Launcher Preview](asset/image_2.png)



Un launcher de jeux fait pour Hyprland. Il récupère automatiquement tes jeux Steam, Heroic (Epic/GOG/Amazon) et les entrées manuelles, et les affiche dans un carousel horizontal avec la cover art.

Ce qui fonctionne :
- Détection des jeux non-Steam ajoutés via Steam (parsing du shortcuts.vdf)
- Récupération automatique des covers depuis Steam et SteamGridDB
- Badges par plateforme, système de favoris, indicateurs NEW/RECENT
- Thème automatique via pywal/wallust
- Navigation clavier et molette

**Contrôles :** `←` `→` pour naviguer, `Enter` ou double-clic pour lancer, `Esc` pour fermer.

---

## Installation

### Via AUR (le plus simple)

```bash
yay -S quickshell-games-launchers-git
Au premier lancement de quickshell-game, la config se copie automatiquement dans ~/.config/quickshell/game-launcher/.
Avec makepkg
git clone https://aur.archlinux.org/quickshell-games-launchers-git.git
cd quickshell-games-launchers-git
makepkg -si
Depuis les sources
git clone https://github.com/Eaquo/quickshell-games-launchers.git
cp -r quickshell-games-launchers/game-launcher ~/.config/quickshell/game-launcher
Dépendances

# Arch
sudo pacman -S python qt6-declarative

# Pour le parsing Steam (non-Steam games)
pip install vdf

# Quickshell
yay -S quickshell-git

# Icônes
yay -S ttf-font-awesome-7

Configuration
Le fichier principal est game-launcher/config.toml.
Steam :
[steam]
enabled = true
library_paths = [
  "~/.local/share/Steam/steamapps",
  "/mnt/games/Steam/steamapps",
]
api_key = ""  # SteamGridDB (optionnel mais recommandé pour les covers)
Heroic :
[heroic]
enabled = true
config_paths = [
  "~/.config/heroic",
  "~/.var/app/com.heroicgameslauncher.hgl/config/heroic",
]
scan_epic = true
scan_gog = true
scan_amazon = true
scan_sideload = true
Jeux manuels (games.toml) :
[[entries]]
title = "📚 Game Library"
launch_command = "kitty -e python3 ~/.config/quickshell/game-launcher/module/service/list_games.py"
path_box_art = "library.png"
Crée aussi le dossier pour tes covers manuelles :
mkdir -p ~/.config/quickshell/game-launcher/box-art
Utilisation
# Lancer le launcher
quickshell game-launcher/GameLauncher.qml

# Voir la liste complète de la bibliothèque
python3 game-launcher/list_games.py
Structure
quickshell/
├── game-launcher/
│   ├── box-art/          # Covers manuelles
│   ├── modules/
│   │   ├── GameCard.qml
│   │   ├── GameLauncher.qml
│   │   └── service/
│   │       ├── backend.py       # Scanner Steam/Heroic/manuel
│   │       └── list_games.py    # Affichage bibliothèque
│   ├── config.toml
│   └── shell.qml
└── toggle.sh
Stack technique
QML/Qt6 avec MultiEffect pour l'interface
Python 3.11+ avec tomllib pour le backend
Parsing ACF et VDF binaire pour Steam
Conversion AppID pour les lancements corrects
Support JSON pour Heroic
Contribuer
Issues, PRs, retours d'expérience — tout est bienvenu. Notamment si tu rencontres des cas particuliers avec Heroic ou des bibliothèques Steam non-standard.
Licence
MIT
Support
[
�
Charger l'image
](https://ko-fi.com/waxdred)
Merci à Quickshell, pywal/wallust, Font Awesome, et évidemment Steam et Heroic.
Florian — v1.0.1 — 2026