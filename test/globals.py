# Runtime global-access audit (luacheck isn't installable on the box):
# runs the full harness in each mode with the add-on's environment wrapped,
# then lists every global the add-on read or wrote.
import lupa.lua51 as l, os, re
os.chdir(os.path.dirname(os.path.abspath(__file__)))
src = open('harness.lua').read()
src = src.replace('local chunk = assert(loadfile("../AlchemistsCookbook/AlchemistsCookbook.lua"))',
 '''local chunk = assert(loadfile("../AlchemistsCookbook/AlchemistsCookbook.lua"))
READS, WRITES = {}, {}
setfenv(chunk, setmetatable({}, {__index=function(t,k) READS[k]=true return _G[k] end, __newindex=function(t,k,v) WRITES[k]=true _G[k]=v end}))''')
reads, writes = set(), set()
for mode in ("modern", "legacy", "classic"):
    L = l.LuaRuntime(); L.execute('AC_MODE=%r' % mode); L.execute(src)
    reads |= set(L.eval('READS').keys()); writes |= set(L.eval('WRITES').keys())
# static: every identifier the file uses that's never declared local
code = open('../AlchemistsCookbook/AlchemistsCookbook.lua').read()
code_nc = re.sub(r'--[^\n]*', '', re.sub(r'"(\\.|[^"\\])*"', '""', code))
locals_ = set(re.findall(r'local\s+function\s+(\w+)', code_nc))
for m in re.findall(r'local\s+([\w\s,]+?)\s*(?:=|\n)', code_nc): locals_ |= {x.strip() for x in m.split(',')}
for m in re.findall(r'function\s*[\w.:]*\(([^)]*)\)', code_nc): locals_ |= {x.strip() for x in m.split(',')}
for m in re.findall(r'for\s+([\w\s,]+?)\s+(?:=|in)', code_nc): locals_ |= {x.strip() for x in m.split(',')}
kw = set('and break do else elseif end false for function if in local nil not or repeat return then true until while self'.split())
idents = set(re.findall(r'(?<![.:\w])([A-Za-z_]\w*)', code_nc))
static_globals = sorted(i for i in idents - locals_ - kw)
print("runtime reads:", ",".join(sorted(reads)))
print("runtime writes:", ",".join(sorted(writes)))
print("static candidates never read at runtime:", ",".join(g for g in static_globals if g not in reads and g not in writes))
