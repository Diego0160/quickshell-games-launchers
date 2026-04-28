#!/usr/bin/env python3
import re
from backend import GameLauncher

_LINE_WIDTH   = 80
_TITLE_INDENT = 25


def _find_steam_install_path(launcher: GameLauncher, app_id: str) -> str:
    """Retourne le chemin d'installation Steam d'un jeu, ou chaîne vide."""
    for lib_path_str in launcher.config.get("steam", {}).get("library_paths", []):
        lib_path = launcher.expand_path(lib_path_str)
        if not lib_path.exists():
            continue
        for acf_file in lib_path.glob("appmanifest_*.acf"):
            try:
                content = acf_file.read_text(encoding="utf-8", errors="ignore")
                if not re.search(r'"appid"\s+"' + app_id + r'"', content):
                    continue
                install_match = re.search(r'"installdir"\s+"([^"]+)"', content)
                if install_match:
                    return str(lib_path.parent / "common" / install_match.group(1))
            except Exception:
                pass  # fichier ACF illisible : ignoré
    return ""


def main():
    """Generate a formatted list of all games with their paths"""
    launcher = GameLauncher()
    data = launcher.get_all_games()
    games = data.get("games", [])

    # Sort games by source then name
    games.sort(key=lambda g: (g.get("source", ""), g.get("name", "").lower()))

    print("=" * _LINE_WIDTH)
    print(" " * _TITLE_INDENT + "GAME LIBRARY")
    print("=" * _LINE_WIDTH)
    print(f"\nTotal games found: {len(games)}\n")

    current_source = None
    for game in games:
        source = game.get("source", "unknown")
        name = game.get("name", "Unknown")
        exec_cmd = game.get("exec", "N/A")
        category = game.get("category", "")

        # Print source header
        if source != current_source:
            current_source = source
            source_names = {
                "steam": "STEAM GAMES",
                "epic": "EPIC GAMES STORE",
                "gog": "GOG GAMES",
                "amazon": "AMAZON GAMES",
                "heroic": "HEROIC SIDELOAD",
                "lutris": "LUTRIS GAMES",
                "config": "CUSTOM LAUNCHERS",
                "manual": "MANUAL ENTRIES"
            }
            print("\n" + "-" * _LINE_WIDTH)
            print(f"  {source_names.get(source, source.upper())}")
            print("-" * _LINE_WIDTH + "\n")

        # Print game info
        print(f"📦 {name}")
        if category:
            print(f"   Category: {category}")
        print(f"   Command:  {exec_cmd}")

        # Extract and print install path if available
        if "steam://rungameid/" in exec_cmd:
            app_id = exec_cmd.split("steam://rungameid/")[1].split()[0]
            print(f"   App ID:   {app_id}")
            install_path = _find_steam_install_path(launcher, app_id)
            if install_path:
                print(f"   Path:     {install_path}")

        elif source == "heroic" and "heroic://launch/" in exec_cmd:
            parts = exec_cmd.replace("heroic://launch/", "").split("/")
            if len(parts) >= 2:
                runner = parts[0]
                app_id = parts[1]
                print(f"   Runner:   {runner}")
                print(f"   App ID:   {app_id}")

        elif exec_cmd and not exec_cmd.startswith("steam") and not exec_cmd.startswith("heroic"):
            # For manual/config entries, the exec might contain the path
            print(f"   Path:     {exec_cmd.split()[0]}")

        print()

    print("=" * _LINE_WIDTH)
    print("\nPress ENTER to close...")
    input()


if __name__ == "__main__":
    main()
