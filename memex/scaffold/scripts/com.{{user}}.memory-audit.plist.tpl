<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<!--
  macOS launchd job — haftalık otomatik hafıza audit snapshot.

  KURULUM:
    cp /Users/sultan/Desktop/y/001/Nexus/scripts/com.sultan.memory-audit.plist \
       ~/Library/LaunchAgents/com.sultan.memory-audit.plist
    launchctl load -w ~/Library/LaunchAgents/com.sultan.memory-audit.plist

  DURDURMA:
    launchctl unload -w ~/Library/LaunchAgents/com.sultan.memory-audit.plist

  TEST (anında çalıştır):
    launchctl start com.sultan.memory-audit

  LOG:
    tail -f ~/Library/Logs/memory-audit.log

  Pazartesi 07:00 — KPI snapshot _audit_history.md'lere append edilir.
  Tamirat (frontmatter, dedup, link) için manuel /memory-audit fix.
-->
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.sultan.memory-audit</string>

    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/python3</string>
        <string>/Users/sultan/Desktop/y/001/Nexus/scripts/audit_snapshot.py</string>
    </array>

    <!-- Haftada bir Pazartesi 07:00 -->
    <key>StartCalendarInterval</key>
    <dict>
        <key>Weekday</key>
        <integer>1</integer>
        <key>Hour</key>
        <integer>7</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>

    <!-- Eğer Mac uykuda iken zamanı kaçırırsa, açılışta bir kez çalıştır -->
    <key>RunAtLoad</key>
    <false/>

    <key>StandardOutPath</key>
    <string>/Users/sultan/Library/Logs/memory-audit.log</string>

    <key>StandardErrorPath</key>
    <string>/Users/sultan/Library/Logs/memory-audit.err</string>

    <key>WorkingDirectory</key>
    <string>/Users/sultan/Desktop/y/001/Nexus</string>
</dict>
</plist>
