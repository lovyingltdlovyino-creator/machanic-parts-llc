from pathlib import Path

path = Path(r"lib/main.dart")
text = path.read_text()
old = "        ),\n      ),\n    ),\n  );\n}\n\nclass _UserTypeCard"
new = "        ),\n      ),\n    );\n  }\n}\n\nclass _UserTypeCard"
if old not in text:
    raise SystemExit('Pattern not found')
text = text.replace(old, new, 1)
path.write_text(text)
