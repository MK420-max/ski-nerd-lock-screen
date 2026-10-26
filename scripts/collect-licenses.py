from pathlib import Path
import sys, subprocess, shutil, urllib.request, importlib.metadata, json
folder = Path(sys.argv[1]); folder.mkdir(parents=True, exist_ok=True)
node_version = subprocess.check_output(['node', '--version'], text=True).strip()
for url, name in [
    (f'https://raw.githubusercontent.com/nodejs/node/{node_version}/LICENSE', 'Node-LICENSE.txt'),
    (f'https://raw.githubusercontent.com/python/cpython/v{sys.version.split()[0]}/LICENSE', 'Python-LICENSE.txt')
]:
    (folder / name).write_bytes(urllib.request.urlopen(url, timeout=30).read())
versions = {'Node': node_version}
for distribution in importlib.metadata.distributions():
    name = distribution.metadata['Name']; versions[name] = distribution.version
    for file in distribution.files or []:
        if any(word in file.name.upper() for word in ['LICENSE', 'COPYING', 'NOTICE']):
            source = Path(distribution.locate_file(file))
            if source.is_file():
                target = folder / name / file.name
                target.parent.mkdir(exist_ok=True)
                shutil.copy2(source, target)
(folder / 'versions.json').write_text(json.dumps(versions, indent=2) + '\n')
