import os, re, subprocess, urllib.parse, datetime
env = {}
for line in open(r'D:\latest_status_goo\backend\.env', encoding='utf-8'):
    m = re.match(r'^([A-Z_]+)=(.*)$', line.strip())
    if m:
        env[m.group(1)] = m.group(2).strip().strip('"')
u = urllib.parse.urlparse(env['DIRECT_DATABASE_URL'])
out_dir = r'C:\Users\jayes\statusgo-backups'
os.makedirs(out_dir, exist_ok=True)
out = os.path.join(out_dir, 'content-tables-before-content_format-%s.sql' % datetime.datetime.now().strftime('%Y%m%d-%H%M%S'))
e = dict(os.environ, PGPASSWORD=urllib.parse.unquote(u.password), PGCONNECT_TIMEOUT='20', PGSSLMODE='require')
tables = ['ShortVideo', 'ContentJob', 'ContentReview', 'ContentReport', 'ContentBookmark', 'ContentEvent', 'NewsStory', 'Scheme', 'AppConfig']
cmd = ['pg_dump', '-h', u.hostname, '-p', str(u.port), '-U', urllib.parse.unquote(u.username), '-d', u.path.lstrip('/'),
       '--no-owner', '--no-privileges', '-f', out] + [x for t in tables for x in ('-t', '"public"."%s"' % t)]
r = subprocess.run(cmd, env=e, capture_output=True, text=True)
print('exit', r.returncode, r.stderr.strip()[:400])
print(out, os.path.getsize(out) if os.path.exists(out) else 'missing')
