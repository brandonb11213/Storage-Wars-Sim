"""Keep the Godot canvas inside Safari safe areas; no gameplay network access."""
from pathlib import Path
import re
p=Path('build/web/index.html')
s=p.read_text()
s=re.sub(r'<meta name="viewport"[^>]*>', '<meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no, viewport-fit=cover">', s)
s=s.replace('</head>', '''<style>
#canvas {position:fixed; left:env(safe-area-inset-left,0px); top:env(safe-area-inset-top,0px);
width:calc(100vw - env(safe-area-inset-left,0px) - env(safe-area-inset-right,0px)) !important;
height:calc(100dvh - env(safe-area-inset-top,0px) - env(safe-area-inset-bottom,0px)) !important; touch-action:none;}
@supports not (height:100dvh) { #canvas {height:calc(100vh - env(safe-area-inset-top,0px) - env(safe-area-inset-bottom,0px)) !important;} }
</style></head>''')
p.write_text(s)
