"""
pCloud Upload Servisi — Feedback Widget Skill v1.0
Hedef klasör: Public Folder / Sx-Claude-Skills / AiSkills
Public URL : https://filedn.eu/lNbvMu0swIW8D7ExzploSu8/Sx-Claude-Skills/AiSkills/{dosya}

Ortam değişkenleri:
    PCLOUD_USERNAME     — pCloud hesap e-postası
    PCLOUD_PASSWORD     — pCloud şifresi
    PCLOUD_FOLDER_ID    — 23473046120 (AiSkills klasörü) veya projeye özgü alt klasör ID'si
    PCLOUD_REGION       — "eapi" (Avrupa) veya "api" (ABD), varsayılan: "eapi"
"""

import os
import requests
import logging
from datetime import datetime
from urllib.parse import quote
from zoneinfo import ZoneInfo

logger = logging.getLogger(__name__)

# ── Sabitler ────────────────────────────────────────────────────────────────
PCLOUD_PUBLIC_BASE = "https://filedn.eu/lNbvMu0swIW8D7ExzploSu8/Sx-Claude-Skills/AiSkills"
DEFAULT_FOLDER_ID  = 23473046120   # pCloud: Public Folder / Sx-Claude-Skills / AiSkills
# ────────────────────────────────────────────────────────────────────────────


class FeedbackPCloudService:
    """Feedback screenshot'larını pCloud'a yükler ve public link döndürür."""

    def __init__(self):
        self.username  = os.getenv("PCLOUD_USERNAME", "")
        self.password  = os.getenv("PCLOUD_PASSWORD", "")
        self.folder_id = int(os.getenv("PCLOUD_FOLDER_ID", str(DEFAULT_FOLDER_ID)))
        self.region    = os.getenv("PCLOUD_REGION", "eapi")
        self.base_url  = f"https://{self.region}.pcloud.com"
        self.auth_token: str | None = None
        self._authenticate()

    # ── Auth ────────────────────────────────────────────────────────────────

    def _authenticate(self) -> None:
        """EU öncelikli, US fallback ile login."""
        regions = [self.region, "api" if self.region == "eapi" else "eapi"]
        for reg in regions:
            try:
                resp = requests.get(
                    f"https://{reg}.pcloud.com/userinfo",
                    params={"getauth": 1, "logout": 1,
                            "username": self.username, "password": self.password},
                    timeout=10,
                ).json()
                if resp.get("result") == 0:
                    self.auth_token = resp["auth"]
                    self.base_url   = f"https://{reg}.pcloud.com"
                    logger.info("pCloud auth OK (region=%s)", reg)
                    return
            except Exception as exc:
                logger.warning("pCloud auth failed (region=%s): %s", reg, exc)
        logger.error("pCloud authentication failed — tüm region'lar denendi")

    # ── Upload ──────────────────────────────────────────────────────────────

    def upload_feedback_screenshot(
        self, content: bytes, filename: str
    ) -> tuple[str | None, str | None]:
        """
        Görsel içeriğini pCloud'a yükler.

        Returns:
            (public_link, file_id) — hata durumunda (None, None)
        """
        if not self.auth_token:
            self._authenticate()
        if not self.auth_token:
            logger.error("pCloud token yok — upload iptal")
            return None, None

        unique_name = self._unique_filename(filename)

        try:
            resp = requests.post(
                f"{self.base_url}/uploadfile",
                params={
                    "auth":           self.auth_token,
                    "folderid":       self.folder_id,
                    "nopartial":      1,
                    "renameifexists": 1,
                },
                files={"file": (unique_name, content)},
                timeout=60,
            ).json()

            if resp.get("result") == 0:
                meta       = resp.get("metadata", [{}])
                meta       = meta[0] if isinstance(meta, list) else meta
                file_id    = meta.get("fileid")
                saved_name = meta.get("name", unique_name)
                pub_link   = f"{PCLOUD_PUBLIC_BASE}/{quote(saved_name)}"
                logger.info("pCloud upload OK: %s → %s", filename, pub_link)
                return pub_link, str(file_id) if file_id else None
            else:
                logger.error("pCloud upload hatası: %s", resp)
                return None, None

        except Exception as exc:
            logger.error("pCloud upload exception: %s", exc)
            return None, None

    # ── Yardımcı ────────────────────────────────────────────────────────────

    @staticmethod
    def _unique_filename(filename: str) -> str:
        """screenshot.png → screenshot_20260414_155230.png"""
        name, ext = os.path.splitext(filename)
        ts = datetime.now(ZoneInfo("Europe/Istanbul")).strftime("%Y%m%d_%H%M%S")
        return f"{name}_{ts}{ext}"
