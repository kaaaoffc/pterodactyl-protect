#!/usr/bin/env bash
# restore_pterodactyl_original.sh - Restore ke file original Pterodactyl
set -Eeuo pipefail

require_root() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]] || { echo "❌ Run as root"; exit 1; }
}

require_root

echo "🔄 Restoring Pterodactyl to original state..."
echo "⚠️  Ini akan mengembalikan file ke versi original (hapus semua proteksi)"

# File utama yang perlu di-restore (Client API khususnya)
FILES_TO_RESTORE=(
    # CLIENT API - SERVER CONTROL (PENTING!)
    "/var/www/pterodactyl/app/Http/Controllers/Api/Client/Servers/ServerController.php"
    "/var/www/pterodactyl/app/Http/Controllers/Api/Client/Servers/FileController.php"
    "/var/www/pterodactyl/app/Http/Controllers/Api/Client/Servers/CommandController.php"
    "/var/www/pterodactyl/app/Http/Controllers/Api/Client/Servers/DatabaseController.php"
    "/var/www/pterodactyl/app/Http/Controllers/Api/Client/Servers/ScheduleController.php"
    "/var/www/pterodactyl/app/Http/Controllers/Api/Client/Servers/NetworkController.php"
    "/var/www/pterodactyl/app/Http/Controllers/Api/Client/Servers/SubuserController.php"
    
    # ADMIN AREA
    "/var/www/pterodactyl/app/Http/Controllers/Admin/Settings/IndexController.php"
    "/var/www/pterodactyl/app/Http/Controllers/Admin/Nests/NestController.php"
    "/var/www/pterodactyl/app/Http/Controllers/Admin/Nodes/NodeController.php"
    "/var/www/pterodactyl/app/Http/Controllers/Admin/LocationController.php"
    "/var/www/pterodactyl/app/Http/Controllers/Admin/UserController.php"
    
    # SERVICES
    "/var/www/pterodactyl/app/Services/Servers/ServerDeletionService.php"
    "/var/www/pterodactyl/app/Services/Servers/DetailsModificationService.php"
    "/var/www/pterodactyl/app/Services/Servers/StartupModificationService.php"
    "/var/www/pterodactyl/app/Services/Servers/SuspensionService.php"
)

# Download original files dari GitHub Pterodactyl
BASE_URL="https://raw.githubusercontent.com/pterodactyl/panel/develop"

# Buat backup dulu dari file saat ini
BACKUP_DIR="/root/pterodactyl_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "📦 Membuat backup ke: $BACKUP_DIR"

for file in "${FILES_TO_RESTORE[@]}"; do
    if [[ -f "$file" ]]; then
        # Backup file saat ini
        backup_path="$BACKUP_DIR/$(echo "$file" | sed 's|^/var/www/pterodactyl/||' | tr '/' '_')"
        cp "$file" "$backup_path"
        echo "💾 Backed up: $file -> $(basename "$backup_path")"
    fi
done

echo ""
echo "⬇️  Downloading original files dari GitHub..."

# Function untuk download file
download_file() {
    local file_path="$1"
    local relative_path="${file_path#/var/www/pterodactyl/}"
    local url="${BASE_URL}/${relative_path}"
    local temp_file="/tmp/$(basename "$file_path").download"
    
    echo "📥 Downloading: $relative_path"
    
    if curl -sSf -H "Accept: application/vnd.github.v3.raw" "$url" -o "$temp_file" 2>/dev/null; then
        if [[ -s "$temp_file" ]]; then
            # Replace file
            cp "$temp_file" "$file_path"
            chmod 644 "$file_path"
            chown www-data:www-data "$file_path" 2>/dev/null || true
            echo "✅ Restored: $(basename "$file_path")"
            return 0
        else
            echo "❌ File kosong: $relative_path"
            return 1
        fi
    else
        echo "❌ Gagal download: $relative_path"
        return 1
    fi
}

# Restore file satu per satu
SUCCESS_COUNT=0
FAIL_COUNT=0

for file in "${FILES_TO_RESTORE[@]}"; do
    if download_file "$file"; then
        ((SUCCESS_COUNT++))
    else
        ((FAIL_COUNT++))
    fi
done

echo ""
echo "📊 Hasil Restore:"
echo "   ✅ Berhasil: $SUCCESS_COUNT files"
echo "   ❌ Gagal: $FAIL_COUNT files"
echo ""
echo "💾 Backup disimpan di: $BACKUP_DIR"
echo ""
echo "🚀 **LANGKAH SELANJUTNYA (WAJIB):**"
echo ""
echo "1. Clear cache Pterodactyl:"
echo "   cd /var/www/pterodactyl"
echo "   php artisan cache:clear"
echo "   php artisan view:clear"
echo "   php artisan config:clear"
echo ""
echo "2. Restart queue worker:"
echo "   php artisan queue:restart"
echo "   systemctl restart pteroq.service"
echo ""
echo "3. Reload PHP:"
echo "   systemctl reload php8.2-fpm  # atau php8.1/php8.0"
echo ""
echo "4. Jika ada error, cek log:"
echo "   tail -f /var/www/pterodactyl/storage/logs/laravel-$(date +%Y-%m-%d).log"
echo ""
echo "5. Untuk rollback (jika perlu):"
echo "   cp $BACKUP_DIR/*.php /var/www/pterodactyl/..."
echo ""
echo "🎯 File utama yang sudah di-restore:"
echo "   • ServerController.php (Client API - control server)"
echo "   • FileController.php (Client API - file manager)"
echo "   • Semua controller client API"
echo "   • Semua controller admin"
