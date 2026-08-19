import os
import glob
import re

base_dir = "/Users/fang/Desktop/พัฒนาต่อ/อันนี้โปรเจคของจริงนะฟ่าง/dorm_project/backend-dorm"

def read_file(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()

def write_file(path, content):
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)

# 1. Models
os.makedirs(f"{base_dir}/models", exist_ok=True)
models_content = read_file(f"{base_dir}/models.go")
models_content = models_content.replace("package main", "package models")
write_file(f"{base_dir}/models/models.go", models_content)

# 2. Utils
os.makedirs(f"{base_dir}/utils", exist_ok=True)
helpers_content = read_file(f"{base_dir}/helpers.go")
helpers_content = helpers_content.replace("package main", "package utils")
utils_funcs = ["isAllowedUploadExt", "isSafeBackupName", "isSafeZipEntry", "enableCORS", "writeJSON", "saveUploadedFile", "rollbackOnErr", "performZipBackup", "generateZipBackupData"]
for f in utils_funcs:
    helpers_content = re.sub(rf'\b{f}\b', f[0].upper() + f[1:], helpers_content)
write_file(f"{base_dir}/utils/helpers.go", helpers_content)

tls_content = read_file(f"{base_dir}/tls.go")
tls_content = tls_content.replace("package main", "package utils")
tls_content = re.sub(r'\bgenerateSelfSignedCert\b', "GenerateSelfSignedCert", tls_content)
write_file(f"{base_dir}/utils/tls.go", tls_content)

# 3. Handlers
os.makedirs(f"{base_dir}/handlers", exist_ok=True)
api_files = glob.glob(f"{base_dir}/api_*.go") + [f"{base_dir}/auth.go"]
for file in api_files:
    content = read_file(file)
    content = content.replace("package main", "package handlers\n\nimport (\n\t\"dorm_os/models\"\n\t\"dorm_os/utils\"\n)")
    
    # Models replace
    for m in ["User", "Payment", "Room", "SystemLog", "RoomTypeDef", "DepositRefund", "DashboardStats", "RoomCondition", "Maintenance"]:
        content = re.sub(rf'\b{m}\b(?!\.)', f"models.{m}", content)
    
    # Utils replace
    for f in utils_funcs:
        content = re.sub(rf'\b{f}\b', f"utils.{f[0].upper() + f[1:]}", content)
    
    # Capitalize setup functions
    content = re.sub(r'\bsetup([A-Za-z]+Routes)\b', r'Setup\1', content)
    content = re.sub(r'\binitializeDatabase\b', 'InitializeDatabase', content)
    content = re.sub(r'\binitAdminTable\b', 'InitAdminTable', content)
    content = re.sub(r'\bstartBackupScheduler\b', 'StartBackupScheduler', content)
    
    # Fix handlers functions in auth.go
    auth_funcs = ["loginHandler", "changePasswordHandler", "getAdminsHandler", "createAdminHandler", "deleteAdminHandler", "updateAdminHandler", "pingAdminHandler", "logoutAdminHandler"]
    for af in auth_funcs:
        content = re.sub(rf'\b{af}\b', af[0].upper() + af[1:], content)

    write_file(f"{base_dir}/handlers/{os.path.basename(file)}", content)

# 4. Main
main_content = read_file(f"{base_dir}/main.go")
main_content = main_content.replace("package main", "package main\n\nimport (\n\t\"dorm_os/handlers\"\n\t\"dorm_os/utils\"\n)")

# Replace setups
for s in ["setupDormRoutes", "setupRoomRoutes", "setupUserRoutes", "setupPaymentRoutes", "setupMaintenanceRoutes", "setupLogRoutes", "setupDashboardRoutes", "setupAuthResetRoutes"]:
    main_content = re.sub(rf'\b{s}\b', f"handlers.{s[0].upper() + s[1:]}", main_content)

main_content = re.sub(r'\binitializeDatabase\b', 'handlers.InitializeDatabase', main_content)
main_content = re.sub(r'\binitAdminTable\b', 'handlers.InitAdminTable', main_content)
main_content = re.sub(r'\bstartBackupScheduler\b', 'handlers.StartBackupScheduler', main_content)

auth_funcs = ["loginHandler", "changePasswordHandler", "getAdminsHandler", "createAdminHandler", "deleteAdminHandler", "updateAdminHandler", "pingAdminHandler", "logoutAdminHandler"]
for af in auth_funcs:
    main_content = re.sub(rf'\b{af}\b', f"handlers.{af[0].upper() + af[1:]}", main_content)

for u in ["isSafeBackupName", "performZipBackup", "generateZipBackupData", "enableCORS", "writeJSON"]:
    main_content = re.sub(rf'\b{u}\b', f"utils.{u[0].upper() + u[1:]}", main_content)

main_content = re.sub(r'\bgenerateSelfSignedCert\b', 'utils.GenerateSelfSignedCert', main_content)

write_file(f"{base_dir}/main.go", main_content)

# Delete old files
for f in api_files + [f"{base_dir}/models.go", f"{base_dir}/helpers.go", f"{base_dir}/tls.go"]:
    if os.path.exists(f):
        os.remove(f)

print("Refactor script complete.")
