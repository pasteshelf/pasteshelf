"""Batch 13: remaining enum display names — DateGroup, DLPPatternCategory, SSO types.

Covers:
  - DateGroup.swift: "Last Week", "This Month" (other DateGroup keys already in catalog)
  - DLPPatternCategory.swift: 6 categories
  - IdentityProvider.swift: IdentityProviderType (2) + SAMLBinding (2)

Technical protocol names (SAML 2.0, OpenID Connect, HTTP POST, HTTP Redirect)
are kept in their canonical English form across locales — this is industry
convention in admin UIs.
"""

TRANSLATIONS = {
    # DateGroup
    "Last Week": {
        "de": "Letzte Woche", "es": "Semana pasada", "fr": "Semaine dernière",
        "ja": "先週", "ko": "지난주", "pt": "Semana passada",
        "ru": "Прошлая неделя", "tr": "Geçen Hafta",
        "zh-Hans": "上周", "zh-Hant": "上週",
    },
    "This Month": {
        "de": "Diesen Monat", "es": "Este mes", "fr": "Ce mois-ci",
        "ja": "今月", "ko": "이번 달", "pt": "Este mês",
        "ru": "Этот месяц", "tr": "Bu Ay",
        "zh-Hans": "本月", "zh-Hant": "本月",
    },
    # DLPPatternCategory
    "Credit Card": {
        "de": "Kreditkarte", "es": "Tarjeta de crédito", "fr": "Carte de crédit",
        "ja": "クレジットカード", "ko": "신용카드", "pt": "Cartão de crédito",
        "ru": "Кредитная карта", "tr": "Kredi Kartı",
        "zh-Hans": "信用卡", "zh-Hant": "信用卡",
    },
    "Social Security Number": {
        "de": "Sozialversicherungsnummer", "es": "Número de Seguro Social",
        "fr": "Numéro de sécurité sociale", "ja": "社会保障番号",
        "ko": "사회보장번호", "pt": "Número de Seguro Social",
        "ru": "Номер социального страхования", "tr": "Sosyal Güvenlik Numarası",
        "zh-Hans": "社会安全号码", "zh-Hant": "社會安全號碼",
    },
    "API Key / Credential": {
        "de": "API-Schlüssel / Zugangsdaten", "es": "Clave API / Credencial",
        "fr": "Clé API / Identifiant", "ja": "API キー / 認証情報",
        "ko": "API 키 / 자격 증명", "pt": "Chave de API / Credencial",
        "ru": "API-ключ / учётные данные", "tr": "API Anahtarı / Kimlik Bilgisi",
        "zh-Hans": "API 密钥 / 凭据", "zh-Hant": "API 金鑰 / 憑證",
    },
    "Personally Identifiable Information": {
        "de": "Personenbezogene Daten", "es": "Información de identificación personal",
        "fr": "Informations personnelles identifiables", "ja": "個人を特定できる情報",
        "ko": "개인 식별 정보", "pt": "Informações de identificação pessoal",
        "ru": "Персональные данные", "tr": "Kişisel Olarak Tanımlanabilir Bilgi",
        "zh-Hans": "个人身份信息", "zh-Hant": "個人識別資訊",
    },
    "Health Data": {
        "de": "Gesundheitsdaten", "es": "Datos de salud", "fr": "Données de santé",
        "ja": "健康データ", "ko": "건강 데이터", "pt": "Dados de saúde",
        "ru": "Медицинские данные", "tr": "Sağlık Verileri",
        "zh-Hans": "健康数据", "zh-Hant": "健康資料",
    },
    "Custom": {
        "de": "Benutzerdefiniert", "es": "Personalizado", "fr": "Personnalisé",
        "ja": "カスタム", "ko": "사용자 정의", "pt": "Personalizado",
        "ru": "Пользовательский", "tr": "Özel",
        "zh-Hans": "自定义", "zh-Hant": "自訂",
    },
    # IdentityProviderType — protocol names kept canonical
    "SAML 2.0": {
        "de": "SAML 2.0", "es": "SAML 2.0", "fr": "SAML 2.0",
        "ja": "SAML 2.0", "ko": "SAML 2.0", "pt": "SAML 2.0",
        "ru": "SAML 2.0", "tr": "SAML 2.0",
        "zh-Hans": "SAML 2.0", "zh-Hant": "SAML 2.0",
    },
    "OpenID Connect": {
        "de": "OpenID Connect", "es": "OpenID Connect", "fr": "OpenID Connect",
        "ja": "OpenID Connect", "ko": "OpenID Connect", "pt": "OpenID Connect",
        "ru": "OpenID Connect", "tr": "OpenID Connect",
        "zh-Hans": "OpenID Connect", "zh-Hant": "OpenID Connect",
    },
    # SAMLBinding — HTTP method names kept canonical
    "HTTP POST": {
        "de": "HTTP POST", "es": "HTTP POST", "fr": "HTTP POST",
        "ja": "HTTP POST", "ko": "HTTP POST", "pt": "HTTP POST",
        "ru": "HTTP POST", "tr": "HTTP POST",
        "zh-Hans": "HTTP POST", "zh-Hant": "HTTP POST",
    },
    "HTTP Redirect": {
        "de": "HTTP Redirect", "es": "HTTP Redirect", "fr": "HTTP Redirect",
        "ja": "HTTP リダイレクト", "ko": "HTTP 리디렉션", "pt": "HTTP Redirect",
        "ru": "HTTP Redirect", "tr": "HTTP Yönlendirme",
        "zh-Hans": "HTTP 重定向", "zh-Hant": "HTTP 重新導向",
    },
}
