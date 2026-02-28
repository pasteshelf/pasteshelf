# Troubleshooting Guide

> **Last Updated**: 2026-02-04 | **Reading Time**: 20 minutes

Solutions for common PasteShelf issues.

---

## Table of Contents

- [Common Issues](#common-issues)
- [Accessibility & Permissions](#accessibility--permissions)
- [Keyboard Shortcuts & Hotkeys](#keyboard-shortcuts--hotkeys)
- [Launch at Login Issues](#launch-at-login-issues)
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

## Accessibility & Permissions

### Accessibility Permission Not Working

**Symptoms**:
- Panel won't open with hotkey
- Pasting into other apps fails
- Permission prompt doesn't appear

**Solutions**:

1. **Remove and re-add PasteShelf**:
   ```
   System Settings → Privacy & Security → Accessibility
   1. Select PasteShelf and click "-" to remove
   2. Click "+" and add PasteShelf from /Applications
   3. Enable the checkbox
   ```

2. **Reset accessibility database** (if above doesn't work):
   ```bash
   # Requires admin password
   sudo tccutil reset Accessibility
   ```
   Then re-grant permission.

3. **Verify permission is active**:
   ```bash
   # Should output "1" if granted
   sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db \
     "SELECT allowed FROM access WHERE service='kTCCServiceAccessibility' AND client='com.pasteshelf.PasteShelf'"
   ```

### Permission Keeps Getting Revoked

**Causes**:
- App was updated (code signature changed)
- App was moved to different location
- macOS security update

**Solution**: Remove and re-add the permission after each update.

### Automation Permission Issues

**Symptoms**: PasteShelf can't paste into certain apps

**Solution**:
```
System Settings → Privacy & Security → Automation
→ PasteShelf → Enable target apps
```

---

## Keyboard Shortcuts & Hotkeys

### Global Hotkey Doesn't Work

**Symptoms**: Pressing ⌘⇧V (or custom hotkey) does nothing

**Checklist**:
1. **Is PasteShelf running?** Check menu bar for the clipboard icon
2. **Is the hotkey registered?**
   - Open Preferences → Shortcuts
   - The hotkey should be displayed
   - Try re-recording it
3. **Is there a conflict?** Another app may be using the same shortcut

**Common conflicting apps**:
- Alfred (uses ⌘⌥C by default)
- Raycast (uses ⌥Space by default)
- PopClip (various shortcuts)
- Keyboard Maestro (custom shortcuts)
- Other clipboard managers

**Debug**:
```bash
# Check for hotkey conflicts
log stream --predicate 'subsystem == "com.pasteshelf.PasteShelf" AND category == "hotkey"' --level debug
```

### Hotkey Works But Panel Doesn't Appear

**Solutions**:
1. **Check display settings**: Panel appears on the screen with the mouse cursor
2. **Reset panel position**:
   ```bash
   defaults delete com.pasteshelf.PasteShelf panelPosition
   ```
3. **Check for overlapping windows**: The panel might be behind another window

### Can't Record Custom Hotkey

**Symptoms**: Hotkey recorder doesn't capture the key combination

**Solutions**:
1. Click the recorder field first to focus it
2. Press the modifier keys (⌘, ⌥, ⌃, ⇧) before the letter key
3. Avoid system-reserved shortcuts:
   - ⌘Q (Quit)
   - ⌘W (Close Window)
   - ⌘H (Hide)
   - ⌘M (Minimize)
   - ⌘Tab (App Switcher)

### Quick Paste Shortcuts (⌘1-9) Don't Work

**Solutions**:
1. Ensure Quick Paste is enabled in Preferences → Shortcuts
2. The floating panel must be open for these shortcuts to work
3. Some apps capture ⌘1-9 for their own tabs/features

---

## Launch at Login Issues

### PasteShelf Doesn't Start at Login

**Symptoms**: Have to manually launch PasteShelf after each restart

**Solutions**:

1. **Check the setting**:
   ```
   Preferences → General → Launch at Login ✓
   ```

2. **Verify Login Items** (macOS 13+):
   ```
   System Settings → General → Login Items
   → Look for PasteShelf under "Allow in the Background"
   ```

3. **Manually add to Login Items**:
   ```
   System Settings → General → Login Items
   → Click "+" under "Open at Login"
   → Select PasteShelf from /Applications
   ```

4. **Check LaunchAgent** (advanced):
   ```bash
   # Check if launch agent exists
   ls -la ~/Library/LaunchAgents/com.pasteshelf.PasteShelf.plist

   # If missing, PasteShelf will recreate it when you toggle the setting
   ```

### PasteShelf Launches Multiple Times

**Symptoms**: Multiple menu bar icons or multiple instances

**Solutions**:
1. Quit all instances:
   ```bash
   pkill -9 PasteShelf
   ```
2. Remove duplicate Login Items
3. Check for both old and new launch methods:
   ```bash
   # Remove old launch agent if present
   rm ~/Library/LaunchAgents/com.pasteshelf.PasteShelf.plist
   launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.pasteshelf.PasteShelf.plist 2>/dev/null
   ```

### "Open at Login" Setting Keeps Turning Off

**Causes**:
- Preferences file corruption
- Insufficient permissions

**Solutions**:
1. Reset preferences:
   ```bash
   defaults delete com.pasteshelf.PasteShelf
   ```
2. Check file permissions:
   ```bash
   ls -la ~/Library/Preferences/com.pasteshelf.PasteShelf.plist
   # Should be owned by your user
   ```

---

## Clipboard Issues

### Clipboard Not Being Captured

**Symptoms**: Copied content doesn't appear in PasteShelf

**Checklist**:
- [ ] Accessibility permission granted?
- [ ] PasteShelf running (check menu bar)?
- [ ] Source app not in exclusion list?
- [ ] Not private browsing mode?
- [ ] Monitoring not paused?

**Solutions**:

1. **Check if monitoring is paused**:
   - Look at menu bar icon (paused icon is different)
   - Click menu bar → Resume Monitoring

2. **Check excluded apps**:
   ```
   Preferences → Privacy → Excluded Apps
   ```
   Remove the source app if it's in the list.

3. **Check private browsing**:
   - Safari: Not in Private Browsing window
   - Chrome: Not in Incognito window
   - Firefox: Not in Private window

   If you want to capture private browsing:
   ```
   Preferences → Privacy → Exclude Private Browsing → Off
   ```

4. **Verify monitoring is active**:
   ```bash
   # Check monitoring logs
   log stream --predicate 'subsystem == "com.pasteshelf.PasteShelf" AND category == "clipboard"' --level debug
   ```

5. **Restart monitoring**:
   - Quit PasteShelf (Menu bar → Quit)
   - Relaunch from Applications

### Items from Password Managers Not Captured

**This is intentional.** By default, PasteShelf excludes content from:
- 1Password
- Bitwarden
- LastPass
- Dashlane
- KeePassXC
- Keychain Access

**To capture** (not recommended for security):
```
Preferences → Privacy → Excluded Apps → Remove password manager
```

### Sensitive Data Not Being Flagged

**Symptoms**: Credit cards, API keys, etc. not marked as sensitive

**Solutions**:
1. **Check sensitivity detection**:
   ```
   Preferences → Privacy → Detect Sensitive Data → On
   ```

2. **Report false negatives**: If a pattern should be detected, report it via GitHub Issues.

### Duplicate Items Appearing

**Symptoms**: Same content appears multiple times in history

**Solutions**:
1. **Check deduplication setting**:
   ```
   Preferences → General → Skip Duplicates → On
   ```

2. **Content might be slightly different**:
   - Different formatting (RTF vs plain text)
   - Trailing whitespace differences
   - Different source applications

### Wrong Content Type Detected

**Symptoms**: Text shows as image, URL shows as text, etc.

**Solutions**:
1. This usually happens when the source app provides multiple clipboard formats
2. PasteShelf prioritizes: URL > Image > Rich Text > Plain Text
3. Report the issue with:
   - Source application name and version
   - What content type was expected
   - What content type was shown
   - Sample content (redacted)

---

## Search Issues

### Search Returns No Results

**Symptoms**: Typing in search field shows "No matching items"

**Checklist**:
1. **Check active filters**: Click "All" to clear type filters
2. **Check search term**: Ensure you're not searching for very short terms (min 2 chars)
3. **Check clipboard history**: Are there any items in history?

**Solutions**:

1. **Clear all filters**:
   - Click the "All" filter chip
   - Clear the search field (press Escape)

2. **Verify items exist**:
   - Open the panel without searching
   - Scroll through the list to confirm items are present

3. **Rebuild search index**:
   ```
   Preferences → Advanced → Rebuild Index
   ```

4. **Check database integrity**:
   ```bash
   # Verify SQLite database
   sqlite3 ~/Library/Application\ Support/PasteShelf/ClipboardHistory.sqlite "PRAGMA integrity_check"
   ```

### Search Finds Wrong Items

**Symptoms**: Search results don't match what you typed

**Explanation**: PasteShelf uses fuzzy search by default, which finds approximate matches.

**Solutions**:
1. **Use exact match**: Wrap search term in quotes `"exact phrase"`
2. **Disable fuzzy search**: Preferences → Search → Disable Fuzzy Matching
3. **Use longer search terms**: More specific terms give better results

### Slow Search

**Symptoms**: Search takes several seconds to return results

**Causes**:
- Large clipboard history (>1000 items)
- Complex search queries
- Fuzzy search with low threshold

**Solutions**:
1. **Reduce history limit**: Preferences → General → History Limit
2. **Enable auto-cleanup**: Preferences → Privacy → Auto-delete after X days
3. **Optimize search settings**:
   - Increase fuzzy match threshold (stricter matching)
   - Disable fuzzy search for very large histories
4. **Clear old items**:
   ```bash
   # View database size
   ls -lh ~/Library/Application\ Support/PasteShelf/ClipboardHistory.sqlite
   ```

### Search Doesn't Find Image Content

**Note**: Standard search only works on text content.

**For image text search** (OCR): Enable OCR in Preferences > Search > Enable OCR.

**Alternative**: You can also search by:
- Source application name
- Date/time (use filters)
- Image type filter

---

## Sync Issues

### Sync Not Working

**Checklist**:
- [ ] Sync enabled in Preferences?
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

| Channel | Details |
|---------|---------|
| GitHub Issues | Bug reports and feature requests |
| GitHub Discussions | Community help and questions |
| Email | support@pasteshelf.app |

---

## Related Documentation

| Document | Description |
|----------|-------------|
| [FAQ](../user-guide/FAQ.md) | Common questions |
| [User Guide](../user-guide/USER_GUIDE.md) | Complete user guide |
| [Monitoring](MONITORING_LOGGING.md) | System monitoring |

---

*Last updated: 2026-02-04*
