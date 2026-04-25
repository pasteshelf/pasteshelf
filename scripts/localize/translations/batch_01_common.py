"""Batch 01: short common strings (buttons, verbs, states, counts, times).

Conventions:
- Preserve format specifiers (%@, %lld, %1$@, %2$lld) EXACTLY.
- Proper nouns ("PasteShelf", "Mac", "macOS", "iCloud", "GitHub", "OAuth", "SAML",
  "OIDC", "Google", "Notion", "Okta", "Azure AD", etc.) stay as-is.
- Abbreviations for regulations (GDPR, HIPAA, SOC 2, DLP, MDM, SSO, etc.) stay as-is.
- URLs, hostnames, placeholders like 'your-client-id' stay verbatim in every language.
"""

TRANSLATIONS = {
    # Format strings / counts (position-aware)
    "%lld action%@": {
        "de": "%1$lld Aktion%2$@", "es": "%1$lld acción%2$@", "fr": "%1$lld action%2$@",
        "ja": "%1$lld個のアクション%2$@", "ko": "%1$lld개 작업%2$@",
        "pt": "%1$lld ação%2$@", "ru": "%1$lld действий%2$@", "tr": "%1$lld eylem%2$@",
        "zh-Hans": "%1$lld 个操作%2$@", "zh-Hant": "%1$lld 個動作%2$@",
    },
    "%lld active": {
        "de": "%lld aktiv", "es": "%lld activo", "fr": "%lld actif",
        "ja": "%lld個が有効", "ko": "%lld개 활성",
        "pt": "%lld ativo", "ru": "%lld активных", "tr": "%lld etkin",
        "zh-Hans": "%lld 个活跃", "zh-Hant": "%lld 個作用中",
    },
    "%lld clipboard items": {
        "de": "%lld Zwischenablage-Einträge", "es": "%lld elementos del portapapeles",
        "fr": "%lld éléments du presse-papiers", "ja": "クリップボード項目 %lld 件",
        "ko": "클립보드 항목 %lld개", "pt": "%lld itens da área de transferência",
        "ru": "Элементов буфера: %lld", "tr": "%lld pano öğesi",
        "zh-Hans": "%lld 个剪贴板项目", "zh-Hant": "%lld 個剪貼簿項目",
    },
    "%lld disabled": {
        "de": "%lld deaktiviert", "es": "%lld desactivado", "fr": "%lld désactivé",
        "ja": "%lld個が無効", "ko": "%lld개 비활성",
        "pt": "%lld desativado", "ru": "%lld отключено", "tr": "%lld devre dışı",
        "zh-Hans": "%lld 个已禁用", "zh-Hant": "%lld 個已停用",
    },
    "%lld event%@ could not be decrypted": {
        "de": "%1$lld Ereignis%2$@ konnte nicht entschlüsselt werden",
        "es": "No se pudo descifrar %1$lld evento%2$@",
        "fr": "Impossible de déchiffrer %1$lld événement%2$@",
        "ja": "%1$lld件のイベント%2$@を復号化できませんでした",
        "ko": "%1$lld개의 이벤트%2$@를 복호화할 수 없습니다",
        "pt": "Não foi possível descriptografar %1$lld evento%2$@",
        "ru": "Не удалось расшифровать %1$lld событий%2$@",
        "tr": "%1$lld olay%2$@ şifresi çözülemedi",
        "zh-Hans": "%1$lld 个事件%2$@无法解密",
        "zh-Hant": "%1$lld 個事件%2$@無法解密",
    },
    "%lld images processed": {
        "de": "%lld Bilder verarbeitet", "es": "%lld imágenes procesadas",
        "fr": "%lld images traitées", "ja": "%lld枚の画像を処理しました",
        "ko": "이미지 %lld개 처리됨", "pt": "%lld imagens processadas",
        "ru": "Обработано изображений: %lld", "tr": "%lld görsel işlendi",
        "zh-Hans": "已处理 %lld 张图像", "zh-Hant": "已處理 %lld 張圖片",
    },
    "%lld items": {
        "de": "%lld Einträge", "es": "%lld elementos", "fr": "%lld éléments",
        "ja": "%lld件", "ko": "%lld개",
        "pt": "%lld itens", "ru": "Элементов: %lld", "tr": "%lld öğe",
        "zh-Hans": "%lld 个项目", "zh-Hant": "%lld 個項目",
    },
    "%lld items indexed": {
        "de": "%lld Einträge indexiert", "es": "%lld elementos indexados",
        "fr": "%lld éléments indexés", "ja": "%lld件をインデックス化",
        "ko": "%lld개 항목 색인됨", "pt": "%lld itens indexados",
        "ru": "Проиндексировано: %lld", "tr": "%lld öğe dizinlendi",
        "zh-Hans": "已索引 %lld 个项目", "zh-Hant": "已索引 %lld 個項目",
    },
    "%lld lines": {
        "de": "%lld Zeilen", "es": "%lld líneas", "fr": "%lld lignes",
        "ja": "%lld行", "ko": "%lld줄",
        "pt": "%lld linhas", "ru": "Строк: %lld", "tr": "%lld satır",
        "zh-Hans": "%lld 行", "zh-Hant": "%lld 行",
    },
    "%lld match%@ found": {
        "de": "%1$lld Übereinstimmung%2$@ gefunden",
        "es": "Se encontró %1$lld coincidencia%2$@",
        "fr": "%1$lld correspondance%2$@ trouvée",
        "ja": "%1$lld件の一致%2$@が見つかりました",
        "ko": "%1$lld개의 일치%2$@ 발견됨",
        "pt": "%1$lld correspondência%2$@ encontrada",
        "ru": "Найдено совпадений: %1$lld%2$@",
        "tr": "%1$lld eşleşme%2$@ bulundu",
        "zh-Hans": "找到 %1$lld 个匹配项%2$@",
        "zh-Hant": "找到 %1$lld 個相符項目%2$@",
    },
    "%lld of %lld active": {
        "de": "%1$lld von %2$lld aktiv", "es": "%1$lld de %2$lld activos",
        "fr": "%1$lld sur %2$lld actifs", "ja": "%2$lld件中 %1$lld件が有効",
        "ko": "%2$lld개 중 %1$lld개 활성",
        "pt": "%1$lld de %2$lld ativos", "ru": "%1$lld из %2$lld активны",
        "tr": "%2$lld / %1$lld etkin", "zh-Hans": "%2$lld 个中有 %1$lld 个活跃",
        "zh-Hant": "%2$lld 個中有 %1$lld 個作用中",
    },
    "%lld of %lld enabled": {
        "de": "%1$lld von %2$lld aktiviert", "es": "%1$lld de %2$lld activados",
        "fr": "%1$lld sur %2$lld activés", "ja": "%2$lld件中 %1$lld件が有効",
        "ko": "%2$lld개 중 %1$lld개 활성화됨",
        "pt": "%1$lld de %2$lld ativados", "ru": "%1$lld из %2$lld включены",
        "tr": "%2$lld / %1$lld etkin", "zh-Hans": "%2$lld 个中有 %1$lld 个已启用",
        "zh-Hant": "%2$lld 個中有 %1$lld 個已啟用",
    },
    "%lld results": {
        "de": "%lld Ergebnisse", "es": "%lld resultados", "fr": "%lld résultats",
        "ja": "%lld件の結果", "ko": "결과 %lld개",
        "pt": "%lld resultados", "ru": "Результатов: %lld", "tr": "%lld sonuç",
        "zh-Hans": "%lld 条结果", "zh-Hant": "%lld 個結果",
    },
    # Capacity labels
    "100 items": {
        "de": "100 Einträge", "es": "100 elementos", "fr": "100 éléments",
        "ja": "100件", "ko": "100개", "pt": "100 itens", "ru": "100 элементов",
        "tr": "100 öğe", "zh-Hans": "100 个项目", "zh-Hant": "100 個項目",
    },
    "500 items": {
        "de": "500 Einträge", "es": "500 elementos", "fr": "500 éléments",
        "ja": "500件", "ko": "500개", "pt": "500 itens", "ru": "500 элементов",
        "tr": "500 öğe", "zh-Hans": "500 个项目", "zh-Hant": "500 個項目",
    },
    "1,000 items": {
        "de": "1.000 Einträge", "es": "1000 elementos", "fr": "1 000 éléments",
        "ja": "1,000件", "ko": "1,000개", "pt": "1.000 itens", "ru": "1000 элементов",
        "tr": "1.000 öğe", "zh-Hans": "1,000 个项目", "zh-Hant": "1,000 個項目",
    },
    "Unlimited": {
        "de": "Unbegrenzt", "es": "Ilimitado", "fr": "Illimité", "ja": "無制限",
        "ko": "무제한", "pt": "Ilimitado", "ru": "Без ограничений", "tr": "Sınırsız",
        "zh-Hans": "无限制", "zh-Hant": "無限制",
    },
    # Time durations
    "5 minutes": {
        "de": "5 Minuten", "es": "5 minutos", "fr": "5 minutes", "ja": "5分",
        "ko": "5분", "pt": "5 minutos", "ru": "5 минут", "tr": "5 dakika",
        "zh-Hans": "5 分钟", "zh-Hant": "5 分鐘",
    },
    "10 minutes": {
        "de": "10 Minuten", "es": "10 minutos", "fr": "10 minutes", "ja": "10分",
        "ko": "10분", "pt": "10 minutos", "ru": "10 минут", "tr": "10 dakika",
        "zh-Hans": "10 分钟", "zh-Hant": "10 分鐘",
    },
    "15 minutes": {
        "de": "15 Minuten", "es": "15 minutos", "fr": "15 minutes", "ja": "15分",
        "ko": "15분", "pt": "15 minutos", "ru": "15 минут", "tr": "15 dakika",
        "zh-Hans": "15 分钟", "zh-Hant": "15 分鐘",
    },
    "30 minutes": {
        "de": "30 Minuten", "es": "30 minutos", "fr": "30 minutes", "ja": "30分",
        "ko": "30분", "pt": "30 minutos", "ru": "30 минут", "tr": "30 dakika",
        "zh-Hans": "30 分钟", "zh-Hant": "30 分鐘",
    },
    # Indent options
    "2 spaces": {
        "de": "2 Leerzeichen", "es": "2 espacios", "fr": "2 espaces", "ja": "スペース2つ",
        "ko": "공백 2개", "pt": "2 espaços", "ru": "2 пробела", "tr": "2 boşluk",
        "zh-Hans": "2 个空格", "zh-Hant": "2 個空格",
    },
    "4 spaces": {
        "de": "4 Leerzeichen", "es": "4 espacios", "fr": "4 espaces", "ja": "スペース4つ",
        "ko": "공백 4개", "pt": "4 espaços", "ru": "4 пробела", "tr": "4 boşluk",
        "zh-Hans": "4 个空格", "zh-Hant": "4 個空格",
    },
    "Tab": {
        "de": "Tab", "es": "Tabulación", "fr": "Tabulation", "ja": "タブ",
        "ko": "탭", "pt": "Tabulação", "ru": "Табуляция", "tr": "Sekme",
        "zh-Hans": "制表符", "zh-Hant": "定位點",
    },
    # Schedules
    "Hourly": {
        "de": "Stündlich", "es": "Cada hora", "fr": "Toutes les heures", "ja": "毎時",
        "ko": "매시간", "pt": "A cada hora", "ru": "Ежечасно", "tr": "Saatlik",
        "zh-Hans": "每小时", "zh-Hant": "每小時",
    },
    "Daily": {
        "de": "Täglich", "es": "Diariamente", "fr": "Quotidien", "ja": "毎日",
        "ko": "매일", "pt": "Diariamente", "ru": "Ежедневно", "tr": "Günlük",
        "zh-Hans": "每天", "zh-Hant": "每日",
    },
    "Weekly": {
        "de": "Wöchentlich", "es": "Semanalmente", "fr": "Hebdomadaire", "ja": "毎週",
        "ko": "매주", "pt": "Semanalmente", "ru": "Еженедельно", "tr": "Haftalık",
        "zh-Hans": "每周", "zh-Hant": "每週",
    },
    "Monthly": {
        "de": "Monatlich", "es": "Mensualmente", "fr": "Mensuel", "ja": "毎月",
        "ko": "매월", "pt": "Mensalmente", "ru": "Ежемесячно", "tr": "Aylık",
        "zh-Hans": "每月", "zh-Hant": "每月",
    },
    # Common buttons / verbs
    "Add": {"de": "Hinzufügen", "es": "Añadir", "fr": "Ajouter", "ja": "追加", "ko": "추가", "pt": "Adicionar", "ru": "Добавить", "tr": "Ekle", "zh-Hans": "添加", "zh-Hant": "新增"},
    "Cancel": {"de": "Abbrechen", "es": "Cancelar", "fr": "Annuler", "ja": "キャンセル", "ko": "취소", "pt": "Cancelar", "ru": "Отмена", "tr": "İptal", "zh-Hans": "取消", "zh-Hant": "取消"},
    "Clear": {"de": "Löschen", "es": "Limpiar", "fr": "Effacer", "ja": "クリア", "ko": "지우기", "pt": "Limpar", "ru": "Очистить", "tr": "Temizle", "zh-Hans": "清除", "zh-Hant": "清除"},
    "Copy to Clipboard": {"de": "In die Zwischenablage kopieren", "es": "Copiar al portapapeles", "fr": "Copier dans le presse-papiers", "ja": "クリップボードにコピー", "ko": "클립보드에 복사", "pt": "Copiar para a área de transferência", "ru": "Копировать в буфер", "tr": "Panoya Kopyala", "zh-Hans": "复制到剪贴板", "zh-Hant": "複製到剪貼簿"},
    "Create": {"de": "Erstellen", "es": "Crear", "fr": "Créer", "ja": "作成", "ko": "생성", "pt": "Criar", "ru": "Создать", "tr": "Oluştur", "zh-Hans": "创建", "zh-Hant": "建立"},
    "Delete": {"de": "Löschen", "es": "Eliminar", "fr": "Supprimer", "ja": "削除", "ko": "삭제", "pt": "Excluir", "ru": "Удалить", "tr": "Sil", "zh-Hans": "删除", "zh-Hant": "刪除"},
    "Delete All": {"de": "Alle löschen", "es": "Eliminar todo", "fr": "Tout supprimer", "ja": "すべて削除", "ko": "모두 삭제", "pt": "Excluir tudo", "ru": "Удалить все", "tr": "Tümünü Sil", "zh-Hans": "全部删除", "zh-Hant": "全部刪除"},
    "Details": {"de": "Details", "es": "Detalles", "fr": "Détails", "ja": "詳細", "ko": "세부 사항", "pt": "Detalhes", "ru": "Подробности", "tr": "Ayrıntılar", "zh-Hans": "详情", "zh-Hant": "詳細資料"},
    "Disable": {"de": "Deaktivieren", "es": "Desactivar", "fr": "Désactiver", "ja": "無効にする", "ko": "비활성화", "pt": "Desativar", "ru": "Отключить", "tr": "Devre Dışı Bırak", "zh-Hans": "禁用", "zh-Hant": "停用"},
    "Disabled": {"de": "Deaktiviert", "es": "Desactivado", "fr": "Désactivé", "ja": "無効", "ko": "비활성화됨", "pt": "Desativado", "ru": "Отключено", "tr": "Devre Dışı", "zh-Hans": "已禁用", "zh-Hant": "已停用"},
    "Done": {"de": "Fertig", "es": "Hecho", "fr": "Terminé", "ja": "完了", "ko": "완료", "pt": "Concluído", "ru": "Готово", "tr": "Tamam", "zh-Hans": "完成", "zh-Hant": "完成"},
    "Duplicate": {"de": "Duplizieren", "es": "Duplicar", "fr": "Dupliquer", "ja": "複製", "ko": "복제", "pt": "Duplicar", "ru": "Дублировать", "tr": "Çoğalt", "zh-Hans": "复制", "zh-Hant": "複製"},
    "Edit": {"de": "Bearbeiten", "es": "Editar", "fr": "Modifier", "ja": "編集", "ko": "편집", "pt": "Editar", "ru": "Изменить", "tr": "Düzenle", "zh-Hans": "编辑", "zh-Hant": "編輯"},
    "Enable": {"de": "Aktivieren", "es": "Activar", "fr": "Activer", "ja": "有効にする", "ko": "활성화", "pt": "Ativar", "ru": "Включить", "tr": "Etkinleştir", "zh-Hans": "启用", "zh-Hant": "啟用"},
    "Enabled": {"de": "Aktiviert", "es": "Activado", "fr": "Activé", "ja": "有効", "ko": "활성화됨", "pt": "Ativado", "ru": "Включено", "tr": "Etkin", "zh-Hans": "已启用", "zh-Hant": "已啟用"},
    "Export": {"de": "Exportieren", "es": "Exportar", "fr": "Exporter", "ja": "エクスポート", "ko": "내보내기", "pt": "Exportar", "ru": "Экспорт", "tr": "Dışa Aktar", "zh-Hans": "导出", "zh-Hant": "匯出"},
    "Fetch": {"de": "Abrufen", "es": "Obtener", "fr": "Récupérer", "ja": "取得", "ko": "가져오기", "pt": "Buscar", "ru": "Получить", "tr": "Getir", "zh-Hans": "获取", "zh-Hant": "擷取"},
    "None": {"de": "Keine", "es": "Ninguno", "fr": "Aucun", "ja": "なし", "ko": "없음", "pt": "Nenhum", "ru": "Нет", "tr": "Yok", "zh-Hans": "无", "zh-Hant": "無"},
    "OK": {"de": "OK", "es": "Aceptar", "fr": "OK", "ja": "OK", "ko": "확인", "pt": "OK", "ru": "ОК", "tr": "Tamam", "zh-Hans": "好", "zh-Hant": "好"},
    "Paste": {"de": "Einfügen", "es": "Pegar", "fr": "Coller", "ja": "ペースト", "ko": "붙여넣기", "pt": "Colar", "ru": "Вставить", "tr": "Yapıştır", "zh-Hans": "粘贴", "zh-Hant": "貼上"},
    "Reset": {"de": "Zurücksetzen", "es": "Restablecer", "fr": "Réinitialiser", "ja": "リセット", "ko": "재설정", "pt": "Redefinir", "ru": "Сбросить", "tr": "Sıfırla", "zh-Hans": "重置", "zh-Hant": "重設"},
    "Reveal": {"de": "Anzeigen", "es": "Mostrar", "fr": "Révéler", "ja": "表示", "ko": "드러내기", "pt": "Revelar", "ru": "Показать", "tr": "Göster", "zh-Hans": "显示", "zh-Hant": "顯示"},
    "Save": {"de": "Speichern", "es": "Guardar", "fr": "Enregistrer", "ja": "保存", "ko": "저장", "pt": "Salvar", "ru": "Сохранить", "tr": "Kaydet", "zh-Hans": "保存", "zh-Hant": "儲存"},
    "Yes": {"de": "Ja", "es": "Sí", "fr": "Oui", "ja": "はい", "ko": "예", "pt": "Sim", "ru": "Да", "tr": "Evet", "zh-Hans": "是", "zh-Hant": "是"},
    "No": {"de": "Nein", "es": "No", "fr": "Non", "ja": "いいえ", "ko": "아니요", "pt": "Não", "ru": "Нет", "tr": "Hayır", "zh-Hans": "否", "zh-Hant": "否"},
    # Status words
    "Active": {"de": "Aktiv", "es": "Activo", "fr": "Actif", "ja": "有効", "ko": "활성", "pt": "Ativo", "ru": "Активен", "tr": "Etkin", "zh-Hans": "活跃", "zh-Hant": "作用中"},
    "Inactive": {"de": "Inaktiv", "es": "Inactivo", "fr": "Inactif", "ja": "非アクティブ", "ko": "비활성", "pt": "Inativo", "ru": "Неактивен", "tr": "Etkin Değil", "zh-Hans": "非活跃", "zh-Hant": "未使用"},
    "Granted": {"de": "Erteilt", "es": "Concedido", "fr": "Accordé", "ja": "許可済み", "ko": "부여됨", "pt": "Concedido", "ru": "Предоставлено", "tr": "Verildi", "zh-Hans": "已授权", "zh-Hant": "已授權"},
    "Not Granted": {"de": "Nicht erteilt", "es": "No concedido", "fr": "Non accordé", "ja": "未許可", "ko": "부여되지 않음", "pt": "Não concedido", "ru": "Не предоставлено", "tr": "Verilmedi", "zh-Hans": "未授权", "zh-Hant": "未授權"},
    "Connected": {"de": "Verbunden", "es": "Conectado", "fr": "Connecté", "ja": "接続済み", "ko": "연결됨", "pt": "Conectado", "ru": "Подключено", "tr": "Bağlandı", "zh-Hans": "已连接", "zh-Hant": "已連線"},
    "Disconnected": {"de": "Getrennt", "es": "Desconectado", "fr": "Déconnecté", "ja": "切断", "ko": "연결 끊김", "pt": "Desconectado", "ru": "Отключено", "tr": "Bağlantı Kesildi", "zh-Hans": "已断开", "zh-Hant": "已中斷"},
    "Error": {"de": "Fehler", "es": "Error", "fr": "Erreur", "ja": "エラー", "ko": "오류", "pt": "Erro", "ru": "Ошибка", "tr": "Hata", "zh-Hans": "错误", "zh-Hant": "錯誤"},
    "Critical": {"de": "Kritisch", "es": "Crítico", "fr": "Critique", "ja": "重要", "ko": "심각", "pt": "Crítico", "ru": "Критично", "tr": "Kritik", "zh-Hans": "严重", "zh-Hant": "嚴重"},
    "Low": {"de": "Niedrig", "es": "Baja", "fr": "Faible", "ja": "低", "ko": "낮음", "pt": "Baixo", "ru": "Низкий", "tr": "Düşük", "zh-Hans": "低", "zh-Hant": "低"},
    "Medium": {"de": "Mittel", "es": "Medio", "fr": "Moyen", "ja": "中", "ko": "보통", "pt": "Médio", "ru": "Средний", "tr": "Orta", "zh-Hans": "中", "zh-Hant": "中"},
    "High": {"de": "Hoch", "es": "Alta", "fr": "Élevé", "ja": "高", "ko": "높음", "pt": "Alto", "ru": "Высокий", "tr": "Yüksek", "zh-Hans": "高", "zh-Hant": "高"},
    "Low Risk": {"de": "Geringes Risiko", "es": "Riesgo bajo", "fr": "Risque faible", "ja": "低リスク", "ko": "낮은 위험", "pt": "Risco baixo", "ru": "Низкий риск", "tr": "Düşük Risk", "zh-Hans": "低风险", "zh-Hant": "低風險"},
    "Medium Risk": {"de": "Mittleres Risiko", "es": "Riesgo medio", "fr": "Risque moyen", "ja": "中リスク", "ko": "중간 위험", "pt": "Risco médio", "ru": "Средний риск", "tr": "Orta Risk", "zh-Hans": "中风险", "zh-Hant": "中度風險"},
    "High Risk": {"de": "Hohes Risiko", "es": "Riesgo alto", "fr": "Risque élevé", "ja": "高リスク", "ko": "높은 위험", "pt": "Risco alto", "ru": "Высокий риск", "tr": "Yüksek Risk", "zh-Hans": "高风险", "zh-Hant": "高風險"},
    # Theme / sizes
    "System": {"de": "System", "es": "Sistema", "fr": "Système", "ja": "システム", "ko": "시스템", "pt": "Sistema", "ru": "Системная", "tr": "Sistem", "zh-Hans": "系统", "zh-Hant": "系統"},
    "Light": {"de": "Hell", "es": "Claro", "fr": "Clair", "ja": "ライト", "ko": "라이트", "pt": "Claro", "ru": "Светлая", "tr": "Açık", "zh-Hans": "浅色", "zh-Hant": "淺色"},
    "Dark": {"de": "Dunkel", "es": "Oscuro", "fr": "Sombre", "ja": "ダーク", "ko": "다크", "pt": "Escuro", "ru": "Тёмная", "tr": "Koyu", "zh-Hans": "深色", "zh-Hant": "深色"},
    "Narrow": {"de": "Schmal", "es": "Estrecho", "fr": "Étroit", "ja": "狭い", "ko": "좁게", "pt": "Estreito", "ru": "Узкий", "tr": "Dar", "zh-Hans": "窄", "zh-Hant": "窄"},
    "Normal": {"de": "Normal", "es": "Normal", "fr": "Normal", "ja": "標準", "ko": "표준", "pt": "Normal", "ru": "Обычный", "tr": "Normal", "zh-Hans": "标准", "zh-Hant": "標準"},
    "Wide": {"de": "Breit", "es": "Ancho", "fr": "Large", "ja": "広い", "ko": "넓게", "pt": "Largo", "ru": "Широкий", "tr": "Geniş", "zh-Hans": "宽", "zh-Hant": "寬"},
}
