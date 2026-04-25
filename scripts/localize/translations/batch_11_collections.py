"""Batch 11: Smart Collections rule builder + ContentType.displayName.

Fills in enum display names that are used in SwiftUI Text(...)/Label(...) via the
String overload (which bypasses the catalog). See:
  - CollectionRule.swift: RuleField, RuleOperator, ContentTypeValue, DateRangeValue
  - ContentType.swift: ContentType.displayName
"""

TRANSLATIONS = {
    # RuleField.displayName
    "Content Type": {
        "de": "Inhaltstyp", "es": "Tipo de contenido", "fr": "Type de contenu",
        "ja": "コンテンツタイプ", "ko": "콘텐츠 유형", "pt": "Tipo de conteúdo",
        "ru": "Тип содержимого", "tr": "İçerik Türü", "zh-Hans": "内容类型", "zh-Hant": "內容類型",
    },
    "Source App": {
        "de": "Quellapp", "es": "App de origen", "fr": "App source",
        "ja": "ソース App", "ko": "소스 앱", "pt": "App de origem",
        "ru": "Исходное приложение", "tr": "Kaynak Uygulama", "zh-Hans": "来源 App", "zh-Hant": "來源 App",
    },
    "Text Content": {
        "de": "Textinhalt", "es": "Contenido de texto", "fr": "Contenu texte",
        "ja": "テキストコンテンツ", "ko": "텍스트 콘텐츠", "pt": "Conteúdo de texto",
        "ru": "Текстовое содержимое", "tr": "Metin İçeriği", "zh-Hans": "文本内容", "zh-Hant": "文字內容",
    },
    "Date Created": {
        "de": "Erstellungsdatum", "es": "Fecha de creación", "fr": "Date de création",
        "ja": "作成日", "ko": "생성 날짜", "pt": "Data de criação",
        "ru": "Дата создания", "tr": "Oluşturma Tarihi", "zh-Hans": "创建日期", "zh-Hant": "建立日期",
    },
    "Is Favorite": {
        "de": "Ist Favorit", "es": "Es favorito", "fr": "Est un favori",
        "ja": "お気に入りである", "ko": "즐겨찾기 여부", "pt": "É favorito",
        "ru": "Избранное", "tr": "Favori", "zh-Hans": "是收藏", "zh-Hant": "是最愛",
    },
    "Is Sensitive": {
        "de": "Ist sensibel", "es": "Es sensible", "fr": "Est sensible",
        "ja": "機密情報である", "ko": "민감 정보 여부", "pt": "É sensível",
        "ru": "Конфиденциально", "tr": "Hassas", "zh-Hans": "是敏感", "zh-Hant": "是敏感",
    },
    # RuleOperator.displayName
    "is": {
        "de": "ist", "es": "es", "fr": "est",
        "ja": "次と一致", "ko": "같음", "pt": "é",
        "ru": "равно", "tr": "eşittir", "zh-Hans": "等于", "zh-Hant": "等於",
    },
    "is not": {
        "de": "ist nicht", "es": "no es", "fr": "n’est pas",
        "ja": "次と一致しない", "ko": "같지 않음", "pt": "não é",
        "ru": "не равно", "tr": "eşit değildir", "zh-Hans": "不等于", "zh-Hant": "不等於",
    },
    "contains": {
        "de": "enthält", "es": "contiene", "fr": "contient",
        "ja": "次を含む", "ko": "포함", "pt": "contém",
        "ru": "содержит", "tr": "içerir", "zh-Hans": "包含", "zh-Hant": "包含",
    },
    "does not contain": {
        "de": "enthält nicht", "es": "no contiene", "fr": "ne contient pas",
        "ja": "次を含まない", "ko": "포함하지 않음", "pt": "não contém",
        "ru": "не содержит", "tr": "içermez", "zh-Hans": "不包含", "zh-Hant": "不包含",
    },
    "matches pattern": {
        "de": "entspricht Muster", "es": "coincide con el patrón", "fr": "correspond au motif",
        "ja": "パターンに一致", "ko": "패턴 일치", "pt": "corresponde ao padrão",
        "ru": "соответствует шаблону", "tr": "kalıpla eşleşir", "zh-Hans": "匹配模式", "zh-Hant": "符合樣式",
    },
    "is before": {
        "de": "liegt vor", "es": "es anterior a", "fr": "est avant",
        "ja": "次より前", "ko": "이전", "pt": "é antes de",
        "ru": "раньше чем", "tr": "önce", "zh-Hans": "早于", "zh-Hant": "早於",
    },
    "is after": {
        "de": "liegt nach", "es": "es posterior a", "fr": "est après",
        "ja": "次より後", "ko": "이후", "pt": "é depois de",
        "ru": "позже чем", "tr": "sonra", "zh-Hans": "晚于", "zh-Hant": "晚於",
    },
    "is within last": {
        "de": "innerhalb der letzten", "es": "es dentro de los últimos", "fr": "est dans les derniers",
        "ja": "過去", "ko": "최근 범위 내", "pt": "está nos últimos",
        "ru": "в течение последних", "tr": "son", "zh-Hans": "在最近", "zh-Hant": "在最近",
    },
    # ContentTypeValue.displayName (missing 3)
    "Rich Text": {
        "de": "Rich Text", "es": "Texto enriquecido", "fr": "Texte enrichi",
        "ja": "リッチテキスト", "ko": "서식 있는 텍스트", "pt": "Texto formatado",
        "ru": "Форматированный текст", "tr": "Zengin Metin", "zh-Hans": "富文本", "zh-Hant": "格式文字",
    },
    "HTML": {
        "de": "HTML", "es": "HTML", "fr": "HTML",
        "ja": "HTML", "ko": "HTML", "pt": "HTML",
        "ru": "HTML", "tr": "HTML", "zh-Hans": "HTML", "zh-Hant": "HTML",
    },
    "PDF": {
        "de": "PDF", "es": "PDF", "fr": "PDF",
        "ja": "PDF", "ko": "PDF", "pt": "PDF",
        "ru": "PDF", "tr": "PDF", "zh-Hans": "PDF", "zh-Hant": "PDF",
    },
    # DateRangeValue.displayName
    "Last Hour": {
        "de": "Letzte Stunde", "es": "Última hora", "fr": "Dernière heure",
        "ja": "過去 1 時間", "ko": "지난 1시간", "pt": "Última hora",
        "ru": "Последний час", "tr": "Son Saat", "zh-Hans": "最近一小时", "zh-Hant": "最近一小時",
    },
    "Last 24 Hours": {
        "de": "Letzte 24 Stunden", "es": "Últimas 24 horas", "fr": "Dernières 24 heures",
        "ja": "過去 24 時間", "ko": "지난 24시간", "pt": "Últimas 24 horas",
        "ru": "Последние 24 часа", "tr": "Son 24 Saat", "zh-Hans": "最近 24 小时", "zh-Hant": "最近 24 小時",
    },
    "Last 7 Days": {
        "de": "Letzte 7 Tage", "es": "Últimos 7 días", "fr": "7 derniers jours",
        "ja": "過去 7 日間", "ko": "지난 7일", "pt": "Últimos 7 dias",
        "ru": "Последние 7 дней", "tr": "Son 7 Gün", "zh-Hans": "最近 7 天", "zh-Hant": "最近 7 天",
    },
    "Last 30 Days": {
        "de": "Letzte 30 Tage", "es": "Últimos 30 días", "fr": "30 derniers jours",
        "ja": "過去 30 日間", "ko": "지난 30일", "pt": "Últimos 30 dias",
        "ru": "Последние 30 дней", "tr": "Son 30 Gün", "zh-Hans": "最近 30 天", "zh-Hant": "最近 30 天",
    },
    "Last 90 Days": {
        "de": "Letzte 90 Tage", "es": "Últimos 90 días", "fr": "90 derniers jours",
        "ja": "過去 90 日間", "ko": "지난 90일", "pt": "Últimos 90 dias",
        "ru": "Последние 90 дней", "tr": "Son 90 Gün", "zh-Hans": "最近 90 天", "zh-Hant": "最近 90 天",
    },
    # ContentType.displayName
    "Plain Text": {
        "de": "Reiner Text", "es": "Texto sin formato", "fr": "Texte brut",
        "ja": "プレーンテキスト", "ko": "일반 텍스트", "pt": "Texto simples",
        "ru": "Обычный текст", "tr": "Düz Metin", "zh-Hans": "纯文本", "zh-Hant": "純文字",
    },
    "PNG Image": {
        "de": "PNG-Bild", "es": "Imagen PNG", "fr": "Image PNG",
        "ja": "PNG 画像", "ko": "PNG 이미지", "pt": "Imagem PNG",
        "ru": "PNG-изображение", "tr": "PNG Görüntüsü", "zh-Hans": "PNG 图片", "zh-Hant": "PNG 圖片",
    },
    "JPEG Image": {
        "de": "JPEG-Bild", "es": "Imagen JPEG", "fr": "Image JPEG",
        "ja": "JPEG 画像", "ko": "JPEG 이미지", "pt": "Imagem JPEG",
        "ru": "JPEG-изображение", "tr": "JPEG Görüntüsü", "zh-Hans": "JPEG 图片", "zh-Hant": "JPEG 圖片",
    },
    "TIFF Image": {
        "de": "TIFF-Bild", "es": "Imagen TIFF", "fr": "Image TIFF",
        "ja": "TIFF 画像", "ko": "TIFF 이미지", "pt": "Imagem TIFF",
        "ru": "TIFF-изображение", "tr": "TIFF Görüntüsü", "zh-Hans": "TIFF 图片", "zh-Hant": "TIFF 圖片",
    },
    "PDF Document": {
        "de": "PDF-Dokument", "es": "Documento PDF", "fr": "Document PDF",
        "ja": "PDF 書類", "ko": "PDF 문서", "pt": "Documento PDF",
        "ru": "PDF-документ", "tr": "PDF Belgesi", "zh-Hans": "PDF 文稿", "zh-Hant": "PDF 文件",
    },
    "File": {
        "de": "Datei", "es": "Archivo", "fr": "Fichier",
        "ja": "ファイル", "ko": "파일", "pt": "Arquivo",
        "ru": "Файл", "tr": "Dosya", "zh-Hans": "文件", "zh-Hant": "檔案",
    },
    "URL": {
        "de": "URL", "es": "URL", "fr": "URL",
        "ja": "URL", "ko": "URL", "pt": "URL",
        "ru": "URL", "tr": "URL", "zh-Hans": "URL", "zh-Hant": "URL",
    },
}
