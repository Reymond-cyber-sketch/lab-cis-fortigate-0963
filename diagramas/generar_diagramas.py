from pathlib import Path
import subprocess
base = Path(__file__).resolve().parent
for archivo in base.glob('*.dot'):
    for formato in ('png', 'svg'):
        subprocess.run(['dot', '-T'+formato, str(archivo), '-o', str(archivo.with_suffix('.'+formato))], check=True)
print('Diagramas generados. Se requiere Graphviz en PATH.')
