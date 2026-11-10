from pathlib import Path
import hashlib
import zipfile
root=Path(__file__).resolve().parents[1]
files=['Scripts/main.lua','Scripts/durability.lua','Scripts/equipment_layout.lua','Scripts/unarmed.lua','enabled.txt','INSTALL.txt','LICENSE.txt']
out=root/'build/Palished-1.2.0-alpha.zip'
out.parent.mkdir(exist_ok=True)
with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED) as z:
    for name in files:
        info=zipfile.ZipInfo('Palished/'+name,(2026,11,8,0,0,0))
        info.compress_type=zipfile.ZIP_DEFLATED
        info.external_attr=0o100644<<16
        z.writestr(info,(root/name).read_bytes())
with zipfile.ZipFile(out) as z:
    assert z.testzip() is None
    assert sorted(z.namelist())==sorted('Palished/'+n for n in files)
sha=hashlib.sha256(out.read_bytes()).hexdigest()
out.with_suffix('.zip.sha256').write_text(sha+'  '+out.name+'\n')
print(out.name,sha)
