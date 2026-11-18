import lupa.lua51 as l, sys, os
os.chdir(os.path.dirname(os.path.abspath(__file__)))
src = open('harness.lua').read()
total = 0
for mode in ("modern", "legacy", "classic"):
    L = l.LuaRuntime()
    L.execute('AC_MODE = %r' % mode)
    print("== mode:", mode)
    total += L.execute(src)
L = l.LuaRuntime()
for f in ['../AlchemistsCookbook/AlchemistsCookbook.lua']:
    r = L.eval('function(s) local f, e = loadstring(s) return e or "ok" end')(open(f).read())
    print(f, "syntax:", r)
    if r != "ok": total += 1
sys.exit(1 if total else 0)
