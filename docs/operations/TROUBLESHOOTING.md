# Troubleshooting Guide

> **Last Updated**: 2026-02-03 | **Reading Time**: 15 minutes

Solutions for common PasteShelf issues.

---

## Table of Contents

- [Common Issues](#common-issues)
- [Clipboard Issues](#clipboard-issues)
- [Search Issues](#search-issues)
- [Sync Issues](#sync-issues)
- [Performance Issues](#performance-issues)
- [Getting Help](#getting-help)

---

## Common Issues

### PasteShelf Won't Launch

**Symptoms**: App crashes on launch or won't open

**Solutions**:
1. Check macOS version (requires 14.0+)
2. Remove corrupted preferences:
   ```bash
   defaults delete com.pasteshelf.PasteShelf
   ```
3. Check for conflicting apps
4. Reinstall the application

### "PasteShelf would like to control this computer"

**Solution**: Grant Accessibility permission
```
System Settings → Privacy & Security → Accessibility → PasteShelf ✓
```

---

## Clipboard Issues

### Clipboard Not Being Captured

**Checklist**:
- [ ] Accessibility permission granted?
- [ ] PasteShelf running (check menu bar)?
- [ ] Source app not in exclusion list?
- [ ] Not private browsing mode?

**Debug**:
```bash
# Check if monitoring is active
log stream --predicate 'subsystem == "com.pasteshelf.PasteShelf" AND category == "clipboard"'
```

### Wrong Content Type Detected

**Solution**: Report the issue with:
- Source application
- Content type
- Sample content (redacted)

---

## Search Issues

### Search Returns No Results

**Solutions**:
1. Check search syntax
2. Rebuild search index:
   ```
   PasteShelf → Preferences → Advanced → Rebuild Index
   ```
3. Check filter settings

### Slow Search

**Solutions**:
1. Reduce history limit
2. Clear old items
3. Disable fuzzy search for large histories

---

## Sync Issues ⭐

### Sync Not Working

**Checklist**:
- [ ] Pro license active?
- [ ] Signed into iCloud?
- [ ] iCloud Drive enabled?
- [ ] Internet connection?

**Reset sync**:
```bash
# Reset CloudKit sync state
defaults delete com.pasteshelf.PasteShelf cloudKitChangeToken

# Force re-sync
# Restart PasteShelf
```

### Sync Conflicts

**Solution**: Check sync preferences for conflict resolution strategy

---

## Performance Issues

### High CPU Usage

**Solutions**:
1. Reduce polling frequency (Advanced settings)
2. Clear large clipboard items
3. Reduce history limit

### High Memory Usage

**Solutions**:
1. Lower history limit
2. Disable image previews
3. Clear old items

**Debug**:
```bash
# Memory usage
top -pid $(pgrep -x PasteShelf) -l 1
```

### Slow Startup

**Solutions**:
1. Reduce history items
2. Disable launch at login temporarily
3. Check for corrupted database

---

## Getting Help

### Before Contacting Support

Collect:
1. macOS version
2. PasteShelf version
3. Error messages
4. Steps to reproduce

### Generate Diagnostic Report

```
PasteShelf → Help → Generate Diagnostic Report
```

### Support Channels

| Tier | Channel |
|------|---------|
| 🆓 Community | GitHub Issues, Discussions |
| ⭐ Pro | Priority email |
| 🏢 Enterprise | Dedicated support |

---

## Related Documentation

| Document | Description |
|----------|-------------|
| [FAQ](../reference/FAQ.md) | Common questions |
| [Monitoring](MONITORING_LOGGING.md) | System monitoring |

---

*Last updated: 2026-02-03*
