"""After 'flutter create --platforms=android .', ensure release Android can access HTTPS API."""
from pathlib import Path
file = Path('android/app/src/main/AndroidManifest.xml')
if not file.exists():
    raise SystemExit('Flutter Android scaffolding not created')
s = file.read_text()
permission = '<uses-permission android:name="android.permission.INTERNET" />'
if permission not in s:
    s = s.replace('<application', f'{permission}\n    <application', 1)
file.write_text(s)
print('Verified Android Internet permission')
