"""Batch 14: automation action descriptions + two TransformPreset names.

Covers:
  - AutomationAction.description (14 cases; some interpolated formats)
  - RuleEditorView.actionDescription overrides (Notify:%@, Webhook:%@)
  - TransformPreset.displayName (2 missing: 'Remove All Whitespace', 'Shuffle Lines')
"""

TRANSLATIONS = {
    "Transform: %@": {
        "de": "Transformieren: %@", "es": "Transformar: %@", "fr": "Transformer : %@",
        "ja": "変換: %@", "ko": "변환: %@", "pt": "Transformar: %@",
        "ru": "Преобразовать: %@", "tr": "Dönüştür: %@",
        "zh-Hans": "转换: %@", "zh-Hant": "轉換: %@",
    },
    "Add tag: %@": {
        "de": "Tag hinzufügen: %@", "es": "Agregar etiqueta: %@", "fr": "Ajouter le tag : %@",
        "ja": "タグを追加: %@", "ko": "태그 추가: %@", "pt": "Adicionar tag: %@",
        "ru": "Добавить тег: %@", "tr": "Etiket ekle: %@",
        "zh-Hans": "添加标签: %@", "zh-Hant": "加入標籤: %@",
    },
    "Remove tag: %@": {
        "de": "Tag entfernen: %@", "es": "Quitar etiqueta: %@", "fr": "Retirer le tag : %@",
        "ja": "タグを削除: %@", "ko": "태그 제거: %@", "pt": "Remover tag: %@",
        "ru": "Удалить тег: %@", "tr": "Etiketi kaldır: %@",
        "zh-Hans": "移除标签: %@", "zh-Hant": "移除標籤: %@",
    },
    "Mark as favorite": {
        "de": "Als Favorit markieren", "es": "Marcar como favorito", "fr": "Marquer comme favori",
        "ja": "お気に入りにする", "ko": "즐겨찾기로 표시", "pt": "Marcar como favorito",
        "ru": "Отметить как избранное", "tr": "Favori olarak işaretle",
        "zh-Hans": "标为收藏", "zh-Hant": "標記為最愛",
    },
    "Remove from favorites": {
        "de": "Aus Favoriten entfernen", "es": "Quitar de favoritos", "fr": "Retirer des favoris",
        "ja": "お気に入りから削除", "ko": "즐겨찾기에서 제거", "pt": "Remover dos favoritos",
        "ru": "Убрать из избранного", "tr": "Favorilerden kaldır",
        "zh-Hans": "从收藏移除", "zh-Hant": "從最愛移除",
    },
    "Move to folder: %@": {
        "de": "In Ordner verschieben: %@", "es": "Mover a la carpeta: %@",
        "fr": "Déplacer vers le dossier : %@", "ja": "フォルダへ移動: %@",
        "ko": "폴더로 이동: %@", "pt": "Mover para a pasta: %@",
        "ru": "Переместить в папку: %@", "tr": "Klasöre taşı: %@",
        "zh-Hans": "移至文件夹: %@", "zh-Hant": "移至檔案夾: %@",
    },
    "Copy to clipboard": {
        "de": "In Zwischenablage kopieren", "es": "Copiar al portapapeles",
        "fr": "Copier dans le presse-papiers", "ja": "クリップボードにコピー",
        "ko": "클립보드에 복사", "pt": "Copiar para a área de transferência",
        "ru": "Скопировать в буфер обмена", "tr": "Panoya kopyala",
        "zh-Hans": "复制到剪贴板", "zh-Hant": "複製到剪貼板",
    },
    "Show notification: %@": {
        "de": "Mitteilung zeigen: %@", "es": "Mostrar notificación: %@",
        "fr": "Afficher la notification : %@", "ja": "通知を表示: %@",
        "ko": "알림 표시: %@", "pt": "Mostrar notificação: %@",
        "ru": "Показать уведомление: %@", "tr": "Bildirim göster: %@",
        "zh-Hans": "显示通知: %@", "zh-Hant": "顯示通知: %@",
    },
    "Open URL: %@": {
        "de": "URL öffnen: %@", "es": "Abrir URL: %@", "fr": "Ouvrir l’URL : %@",
        "ja": "URL を開く: %@", "ko": "URL 열기: %@", "pt": "Abrir URL: %@",
        "ru": "Открыть URL: %@", "tr": "URL’yi aç: %@",
        "zh-Hans": "打开 URL: %@", "zh-Hant": "開啟 URL: %@",
    },
    "Run script: %@": {
        "de": "Skript ausführen: %@", "es": "Ejecutar script: %@",
        "fr": "Exécuter le script : %@", "ja": "スクリプトを実行: %@",
        "ko": "스크립트 실행: %@", "pt": "Executar script: %@",
        "ru": "Запустить скрипт: %@", "tr": "Betik çalıştır: %@",
        "zh-Hans": "运行脚本: %@", "zh-Hant": "執行指令稿: %@",
    },
    "Send webhook": {
        "de": "Webhook senden", "es": "Enviar webhook", "fr": "Envoyer un webhook",
        "ja": "Webhook を送信", "ko": "웹훅 전송", "pt": "Enviar webhook",
        "ru": "Отправить вебхук", "tr": "Webhook gönder",
        "zh-Hans": "发送 Webhook", "zh-Hant": "傳送 Webhook",
    },
    "Mark as sensitive": {
        "de": "Als vertraulich markieren", "es": "Marcar como sensible",
        "fr": "Marquer comme sensible", "ja": "機密に設定",
        "ko": "민감으로 표시", "pt": "Marcar como sensível",
        "ru": "Отметить как конфиденциальное", "tr": "Hassas olarak işaretle",
        "zh-Hans": "标为敏感", "zh-Hant": "標記為敏感",
    },
    "Mark as not sensitive": {
        "de": "Als nicht vertraulich markieren", "es": "Marcar como no sensible",
        "fr": "Marquer comme non sensible", "ja": "機密解除",
        "ko": "민감하지 않음으로 표시", "pt": "Marcar como não sensível",
        "ru": "Снять отметку конфиденциальности", "tr": "Hassas değil olarak işaretle",
        "zh-Hans": "取消敏感标记", "zh-Hant": "取消敏感標記",
    },
    "Delete item": {
        "de": "Objekt löschen", "es": "Eliminar elemento",
        "fr": "Supprimer l’élément", "ja": "項目を削除",
        "ko": "항목 삭제", "pt": "Excluir item",
        "ru": "Удалить элемент", "tr": "Öğeyi sil",
        "zh-Hans": "删除项", "zh-Hant": "刪除項目",
    },
    "Notify: %@": {
        "de": "Benachrichtigen: %@", "es": "Notificar: %@", "fr": "Notifier : %@",
        "ja": "通知: %@", "ko": "알림: %@", "pt": "Notificar: %@",
        "ru": "Уведомить: %@", "tr": "Bildir: %@",
        "zh-Hans": "通知: %@", "zh-Hant": "通知: %@",
    },
    "Webhook: %@": {
        "de": "Webhook: %@", "es": "Webhook: %@", "fr": "Webhook : %@",
        "ja": "Webhook: %@", "ko": "웹훅: %@", "pt": "Webhook: %@",
        "ru": "Вебхук: %@", "tr": "Webhook: %@",
        "zh-Hans": "Webhook: %@", "zh-Hant": "Webhook: %@",
    },
    # TransformPreset missing
    "Remove All Whitespace": {
        "de": "Alle Leerzeichen entfernen", "es": "Quitar todo el espacio en blanco",
        "fr": "Supprimer tous les espaces", "ja": "すべての空白を削除",
        "ko": "모든 공백 제거", "pt": "Remover todos os espaços em branco",
        "ru": "Удалить все пробелы", "tr": "Tüm boşlukları kaldır",
        "zh-Hans": "移除所有空白", "zh-Hant": "移除所有空白",
    },
    "Shuffle Lines": {
        "de": "Zeilen mischen", "es": "Mezclar líneas",
        "fr": "Mélanger les lignes", "ja": "行をシャッフル",
        "ko": "줄 섞기", "pt": "Embaralhar linhas",
        "ru": "Перемешать строки", "tr": "Satırları karıştır",
        "zh-Hans": "打乱行", "zh-Hant": "打亂行",
    },
}
