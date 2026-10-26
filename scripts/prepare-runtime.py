"""Use generic build metadata instead of embedding the packager's home directory."""
from pathlib import Path
import importlib
import pprint
import sys
import sysconfig

folder = Path(sys.argv[1]); folder.mkdir(parents=True, exist_ok=True)
name = sysconfig._get_sysconfigdata_name()
values = importlib.import_module(name).build_time_vars
home = str(Path.home())
cleaned = {key: value.replace(home, '/opt/skinerd-build') if isinstance(value, str) else value
           for key, value in values.items()}
(folder / (name + '.py')).write_text('build_time_vars = ' + pprint.pformat(cleaned) + '\n')
