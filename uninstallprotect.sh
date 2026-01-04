#!/usr/bin/env bash
# uninstall_protect.sh - Uninstall semua proteksi Pterodactyl
set -Eeuo pipefail

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "❌ Jalankan script ini sebagai root."
    exit 1
  fi
}

require_root

echo "🔄 Memulai uninstall semua proteksi Pterodactyl..."
echo "📦 Mencari file backup..."

# List semua file yang mungkin ada backup-nya
FILES=(
    "/var/www/pterodactyl/app/Services/Servers/ServerDeletionService.php"
    "/var/www/pterodactyl/app/Services/Servers/DetailsModificationService.php"
    "/var/www/pterodactyl/app/Http/Controllers/Api/Client/Servers/ServerController.php"
    "/var/www/pterodactyl/app/Http/Controllers/Api/Client/Servers/FileController.php"
    "/var/www/pterodactyl/app/Http/Controllers/Admin/Settings/IndexController.php"
    "/var/www/pterodactyl/app/Http/Controllers/Admin/Nests/NestController.php"
    "/var/www/pterodactyl/app/Http/Controllers/Admin/Nodes/NodeController.php"
    "/var/www/pterodactyl/app/Http/Controllers/Admin/LocationController.php"
    "/var/www/pterodactyl/app/Http/Controllers/Admin/UserController.php"
)

RESTORED_COUNT=0

for file in "${FILES[@]}"; do
    if [[ -f "$file" ]]; then
        # Cari backup file - coba beberapa format
        BACKUP_PATTERNS=(
            "${file}.bak"
            "${file}.bak_*"
            "${file}.backup"
            "${file}.backup_*"
            "${file}.orig"
            "${file}.original"
        )
        
        BACKUP_FOUND=""
        for pattern in "${BACKUP_PATTERNS[@]}"; do
            # Gunakan find untuk menghindari issues dengan wildcards
            BACKUP_FILE=$(find "$(dirname "$file")" -maxdepth 1 -name "$(basename "$pattern")" 2>/dev/null | sort -r | head -1)
            if [[ -n "$BACKUP_FILE" && -f "$BACKUP_FILE" ]]; then
                BACKUP_FOUND="$BACKUP_FILE"
                break
            fi
        done
        
        if [[ -n "$BACKUP_FOUND" ]]; then
            echo "🔄 Restoring: $(basename "$file")"
            
            # Backup file saat ini sebelum di-restore (opsional)
            CURRENT_BACKUP="${file}.current_$(date +%Y%m%d_%H%M%S)"
            cp "$file" "$CURRENT_BACKUP"
            
            # Restore dari backup
            cp "$BACKUP_FOUND" "$file"
            
            # Optional: hapus backup file lama jika ingin
            # rm "$BACKUP_FOUND"
            
            # Restore permission
            chmod 644 "$file"
            chown www-data:www-data "$file" 2>/dev/null || true
            
            ((RESTORED_COUNT++))
            echo "✅ $(basename "$file") restored from: $(basename "$BACKUP_FOUND")"
            echo "   (Current version backed up to: $(basename "$CURRENT_BACKUP"))"
        else
            echo "⚠️  No backup found for: $(basename "$file")"
            echo "   Looking in: $(dirname "$file")"
        fi
    else
        echo "❌ File not found: $file"
    fi
done

echo ""
echo "📊 Uninstall Summary:"
echo "   ✅ $RESTORED_COUNT files restored from backup"
echo ""
echo "🎯 Yang perlu dilakukan manual:"
echo "   🔄 Restart queue: php artisan queue:restart"
echo "   🧹 Clear cache: php artisan cache:clear && php artisan view:clear"
echo "   🔄 Reload PHP: systemctl reload php8.2-fpm (atau php8.1-fpm/php8.0-fpm)"
echo "   🚀 Restart worker: systemctl restart pteroq.service"
echo ""
echo "🔍 Cek backup files yang tersedia:"
find /var/www/pterodactyl -name "*.bak*" -o -name "*.backup*" -o -name "*.orig*" 2>/dev/null | head -20

echo ""
echo "📝 Jika file tidak di-restore dengan benar, coba restore manual:"
echo "   1. Cari backup: find /var/www/pterodactyl -name '*$(basename "${FILES[0]}")*'"
echo "   2. Copy manual: cp /path/to/backup /var/www/pterodactyl/..."
echo "   3. Fix permission: chown www-data:www-data /var/www/pterodactyl/..."
