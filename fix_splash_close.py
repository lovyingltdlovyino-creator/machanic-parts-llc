from pathlib import Path

path = Path(r"lib/main.dart")
text = path.read_text()
old = "            ).animate().fadeIn(delay: 600.ms, duration: 600.ms),\n          ],\n        ),\n      ],\n    ),\n  );"
new = "            ).animate().fadeIn(delay: 600.ms, duration: 600.ms),\n          ],\n        ),\n      ),\n    );"
if old not in text:
    raise SystemExit('Pattern not found')
text = text.replace(old, new, 1)
path.write_text(text)
