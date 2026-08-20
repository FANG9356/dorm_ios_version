import os
import glob

def patch_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()
    
    # We want to replace 'func(w http.ResponseWriter, r *http.Request) {\n'
    # with 'func(w http.ResponseWriter, r *http.Request) {\n\tdb = getTenantDB(r, db)\n'
    # But only inside Setup...Routes functions.
    # To be safe, we'll just look for http.HandleFunc or http.Handle with inline funcs.
    
    lines = content.split('\n')
    new_lines = []
    
    for line in lines:
        new_lines.append(line)
        if 'func(w http.ResponseWriter, r *http.Request) {' in line:
            # We must be careful not to inject it where `db` is not in scope.
            # Usually `db` is passed to SetupXRoutes(db *sql.DB)
            # We'll just inject it, and if it fails to compile, we fix manually.
            indent = line[:len(line) - len(line.lstrip())]
            new_lines.append(indent + '\tdb = getTenantDB(r, db)')

    with open(filepath, 'w') as f:
        f.write('\n'.join(new_lines))
    print(f"Patched {filepath}")

for f in glob.glob('/Volumes/FangB/dorm_project/backend-dorm/handlers/api_*.go'):
    if not f.endswith('api_dorm.go'):
        patch_file(f)
