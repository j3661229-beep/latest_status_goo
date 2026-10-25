import os, re, subprocess, sys, urllib.parse
env = {}
for line in open(r'D:\latest_status_goo\backend\.env', encoding='utf-8'):
    m = re.match(r'^([A-Z_]+)=(.*)$', line.strip())
    if m:
        env[m.group(1)] = m.group(2).strip().strip('"')
u = urllib.parse.urlparse(env['DIRECT_DATABASE_URL'])
sql = sys.argv[1]
e = dict(os.environ, PGPASSWORD=urllib.parse.unquote(u.password), PGCONNECT_TIMEOUT='15', PGSSLMODE='require')
r = subprocess.run(['psql', '-h', u.hostname, '-p', str(u.port), '-U', urllib.parse.unquote(u.username), '-d', u.path.lstrip('/'),
                    '-A', '-t', '-c', sql], env=e, capture_output=True, text=True)
print(r.stdout.strip()); print(r.stderr.strip()[:500])
