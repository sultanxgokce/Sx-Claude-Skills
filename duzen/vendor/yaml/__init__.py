"""PyYAML 6.0.3 (saf Python) — bu klasör YALNIZ başlatıcıdır; gerçek paket yanındaki yaml-saf.zip içindedir.

NEDEN: 236 KB'lık düz kaynak bağımsız göz istemini (100 KB tavan) aşıyordu ve üçüncü taraf kodunu satır satır incelemek anlamsızdı.
ekipc.sh `vendor/yaml/__init__.py` varlığına bakıp `vendor/`ı PYTHONPATH'e koyar; burada zip yola eklenir ve gerçek `yaml` paketi yüklenir.
Kaynak: PyPI PyYAML 6.0.3 lib/yaml içindeki .py dosyaları, DEĞİŞTİRİLMEDEN (yalnız saf Python, .so yok). Lisans: ../LICENSE-PyYAML.
"""
import os, sys
_zip = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "yaml-saf.zip")
if not os.path.isfile(_zip):
    raise ImportError("yaml-saf.zip bulunamadı: " + _zip)
sys.path.insert(0, _zip)
sys.modules.pop(__name__, None)
import importlib
_gercek = importlib.import_module("yaml")
sys.modules["yaml"] = _gercek
