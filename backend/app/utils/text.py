import re
import unicodedata

_WS_RE = re.compile(r"\s+")


def normalize_name(name: str) -> str:
    """规范化食材/菜品名用于去重比较。
    - NFC 归一
    - 去首尾空白、压缩内部空白
    - 小写（仅对 ASCII 起作用，中文不受影响）
    繁简归一暂未引入（需 OpenCC），见 PRD §7.2。
    """
    if not name:
        return ""
    s = unicodedata.normalize("NFC", name)
    s = s.strip()
    s = _WS_RE.sub(" ", s)
    return s.lower()
