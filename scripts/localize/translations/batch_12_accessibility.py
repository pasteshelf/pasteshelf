"""Batch 12: accessibility/VoiceOver label fragments.

Used by ClipboardItemRow.accessibilityLabel to build a VoiceOver description
for each clipboard row. Previously concatenated hardcoded English fragments.
"""

TRANSLATIONS = {
    "sensitive content": {
        "de": "vertraulicher Inhalt", "es": "contenido sensible", "fr": "contenu sensible",
        "ja": "機密コンテンツ", "ko": "민감한 콘텐츠", "pt": "conteúdo sensível",
        "ru": "конфиденциальное содержимое", "tr": "hassas içerik",
        "zh-Hans": "敏感内容", "zh-Hant": "敏感內容",
    },
    "favorite": {
        "de": "Favorit", "es": "favorito", "fr": "favori",
        "ja": "お気に入り", "ko": "즐겨찾기", "pt": "favorito",
        "ru": "избранное", "tr": "favori",
        "zh-Hans": "收藏", "zh-Hant": "最愛",
    },
    "unknown app": {
        "de": "unbekannte App", "es": "app desconocida", "fr": "app inconnue",
        "ja": "不明な App", "ko": "알 수 없는 앱", "pt": "app desconhecido",
        "ru": "неизвестное приложение", "tr": "bilinmeyen uygulama",
        "zh-Hans": "未知 App", "zh-Hant": "未知 App",
    },
    "from %@": {
        "de": "von %@", "es": "desde %@", "fr": "depuis %@",
        "ja": "%@ から", "ko": "%@에서", "pt": "de %@",
        "ru": "из %@", "tr": "%@ konumundan",
        "zh-Hans": "来自 %@", "zh-Hant": "來自 %@",
    },
}
