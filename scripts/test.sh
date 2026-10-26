#!/bin/zsh
set -eu
cd "${0:A:h:h}"
checks=$(mktemp -d /tmp/skinerd-checks.XXXXXX)
trap 'rm -rf "$checks"' EXIT
xcrun swiftc -O src/Localization.swift src/ResortSettings.swift src/test_settings.swift -o "$checks/settings"
"$checks/settings"
xcrun swiftc -O src/Forecast.swift src/test_forecast.swift -o "$checks/forecast"
"$checks/forecast"
for check in test_clock_layout test_settings_resume; do
  xcrun swiftc -O -framework AppKit -framework ScreenSaver -framework AVFoundation src/Localization.swift src/CamWall.swift src/Forecast.swift src/SnowStake.swift src/ResortSettings.swift "src/$check.swift" -o "$checks/$check"
  "$checks/$check"
done
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s src -p 'test_resolver_sources.py'
