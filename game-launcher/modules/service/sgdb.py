#!/usr/bin/env python3
"""Client SteamGridDB — récupération des covers et logos de jeux."""
import json
import re
import urllib.request
import urllib.error
import urllib.parse
from typing import Optional, List


# Constantes de scoring des images
_LIKES_WEIGHT  = 1000   # poids d'un j'aime par rapport aux dimensions
_PNG_BONUS     = 500    # bonus pour les images PNG
_MIN_IMG_WIDTH = 300    # largeur minimale acceptée (pixels)


class SGDBClient:
    """Récupère covers et logos depuis SteamGridDB."""
    _UA = "QuickShell-GameLauncher/2.0"

    def __init__(self, config: dict, image_cache):
        self.config = config
        self.image_cache = image_cache

    # ── Config ────────────────────────────────────────────────────────────

    @property
    def _cfg(self) -> dict:
        return self.config.get("steamgriddb", {})

    @property
    def _api_key(self) -> str:
        return self._cfg.get("api_key", "")

    @property
    def _timeout(self) -> int:
        return self._cfg.get("request_timeout", 3)

    @property
    def enabled(self) -> bool:
        return self._cfg.get("enabled", False) and bool(self._api_key)

    # ── Helpers image ─────────────────────────────────────────────────────

    @staticmethod
    def _normalize(val) -> List[str]:
        """Convertit dimensions/styles en liste propre (str ou liste)."""
        if not val:
            return []
        if isinstance(val, str):
            return [v.strip() for v in val.split(",") if v.strip()]
        return [str(v).strip() for v in val if str(v).strip()]

    def _score(self, img: dict) -> int:
        likes = img.get("likes") or 0
        if self._cfg.get("sort_by_likes", False):
            return likes
        score = likes * _LIKES_WEIGHT
        if img.get("width") and img.get("height"):
            score += img["width"] * img["height"] // 100
        if img.get("mime") == "image/png":
            score += _PNG_BONUS
        return score

    def _filter(self, images: List[dict]) -> List[dict]:
        images = [img for img in images if img.get("width", 0) >= _MIN_IMG_WIDTH]
        min_likes = self._cfg.get("min_likes", 0)
        if min_likes > 0:
            filtered = [img for img in images if (img.get("likes") or 0) >= min_likes]
            if filtered:
                images = filtered
        return images

    def _pick_best(self, images: List[dict]) -> Optional[str]:
        imgs = self._filter(images)
        if not imgs:
            return None
        top = sorted(imgs, key=self._score, reverse=True)[0]
        return top.get("url", top.get("thumb"))

    # ── HTTP ──────────────────────────────────────────────────────────────

    def _request(self, url: str, cache_key: str = "") -> Optional[List[dict]]:
        try:
            req = urllib.request.Request(url)
            req.add_header("Authorization", f"Bearer {self._api_key}")
            req.add_header("User-Agent", self._UA)
            req.add_header("Accept", "application/json")
            with urllib.request.urlopen(req, timeout=self._timeout) as resp:
                data = json.loads(resp.read().decode())
                if data.get("success") and data.get("data"):
                    return data["data"]
        except urllib.error.HTTPError as e:
            if e.code == 404 and cache_key:
                self.image_cache.set(cache_key, "")
        except Exception:
            pass  # erreur réseau/IO : échec silencieux
        return None

    def _build_url(self, base: str, type_val: str, with_dims: bool = True, mime: str = None) -> str:
        cfg = self._cfg
        params = [f"types={type_val}"]
        if mime:
            params.append(f"mimes={mime}")
        dims = self._normalize(cfg.get("dimensions"))
        if with_dims and dims:
            params.append(f"dimensions={','.join(dims)}")
        styles = self._normalize(cfg.get("styles"))
        if styles:
            params.append(f"styles={','.join(styles)}")
        params.append(f"nsfw={str(cfg.get('nsfw', False)).lower()}")
        params.append(f"humor={str(cfg.get('humor', False)).lower()}")
        params.append(f"epilepsy={str(cfg.get('epilepsy', False)).lower()}")
        return base + "?" + "&".join(params)

    def _fetch_best(self, base: str, prefer_animated: bool, cache_key: str) -> Optional[str]:
        """Tente animé puis PNG statique depuis base URL ; met en cache si trouvé."""
        dims = self._normalize(self._cfg.get("dimensions"))
        if prefer_animated:
            data = self._request(self._build_url(base, "animated"), cache_key)
            if data is None and dims:
                data = self._request(self._build_url(base, "animated", with_dims=False), cache_key)
            url = self._pick_best(data or [])
            if url:
                self.image_cache.set(cache_key, url)
                return url
        data = self._request(self._build_url(base, "static", mime="image/png"), cache_key)
        if data is None and dims:
            data = self._request(self._build_url(base, "static", with_dims=False, mime="image/png"), cache_key)
        url = self._pick_best(data or [])
        if url:
            self.image_cache.set(cache_key, url)
        return url

    # ── API publique ──────────────────────────────────────────────────────

    def get_platform(self, source: str, category: str = "") -> str:
        platform_map = {
            "steam": "steam", "epic": "egs", "gog": "gog",
            "amazon": "amazon", "uplay": "uplay", "origin": "origin",
            "battlenet": "bnet", "sideload": "steam",
        }
        return platform_map.get(source.lower()) or platform_map.get(category.lower()) or "steam"

    def search_by_name(self, game_name: str) -> Optional[int]:
        """Cherche un jeu par nom ; retourne l'ID SGDB si le nom correspond."""
        def word_set(name: str):
            cleaned = re.sub(r'[™®©]', '', name)
            return set(re.sub(r'[_\-:]+', ' ', cleaned).lower().split())

        game_words = word_set(game_name)
        if not game_words:
            return None
        encoded = urllib.parse.quote(game_name)
        url = f"https://www.steamgriddb.com/api/v2/search/autocomplete/{encoded}"
        try:
            req = urllib.request.Request(url)
            req.add_header("Authorization", f"Bearer {self._api_key}")
            req.add_header("User-Agent", self._UA)
            req.add_header("Accept", "application/json")
            with urllib.request.urlopen(req, timeout=self._timeout) as resp:
                data = json.loads(resp.read().decode())
                if data.get("success") and data.get("data"):
                    for result in data["data"]:
                        if game_words.issubset(word_set(result.get("name", ""))):
                            return result["id"]
        except Exception:
            pass  # erreur réseau/IO : retourne None
        return None

    def get_cover_url(self, app_id: str, platform: str = "steam", game_name: str = "") -> Optional[str]:
        if not self.enabled:
            return None
        cfg = self._cfg
        prefer_animated = cfg.get("prefer_animated", False)
        endpoint_map = {"grid": "grids", "hero": "heroes", "logo": "logos", "icon": "icons"}
        endpoint = endpoint_map.get(cfg.get("image_type", "grid"), "grids")
        anim_suffix = "animated" if prefer_animated else "static"
        cache_key = f"{platform}:{app_id}:{cfg.get('image_type', 'grid')}:{anim_suffix}"

        cached = self.image_cache.get(cache_key)
        if cached is not None:
            return cached or None

        base = f"https://www.steamgriddb.com/api/v2/{endpoint}/{platform}/{app_id}"
        url = self._fetch_best(base, prefer_animated, cache_key)
        if url:
            return url

        if game_name:
            sgdb_id = self.search_by_name(game_name)
            if sgdb_id:
                name_base = f"https://www.steamgriddb.com/api/v2/{endpoint}/game/{sgdb_id}"
                url = self._fetch_best(name_base, prefer_animated, cache_key)
        return url

    def get_logo_url(self, app_id: str, platform: str = "steam", game_name: str = "") -> Optional[str]:
        if not self.enabled:
            return None
        cache_key = f"{platform}:{app_id}:logo"
        cached = self.image_cache.get(cache_key)
        if cached is not None:
            return cached or None

        url = f"https://www.steamgriddb.com/api/v2/logos/{platform}/{app_id}?types=static&mimes=image/png"
        data = self._request(url, cache_key)
        if data:
            logo_url = data[0].get("url", data[0].get("thumb"))
            self.image_cache.set(cache_key, logo_url)
            return logo_url

        if game_name:
            sgdb_id = self.search_by_name(game_name)
            if sgdb_id:
                name_url = f"https://www.steamgriddb.com/api/v2/logos/game/{sgdb_id}?types=static&mimes=image/png"
                data = self._request(name_url)
                if data:
                    logo_url = data[0].get("url", data[0].get("thumb"))
                    self.image_cache.set(cache_key, logo_url)
                    return logo_url
        return None
