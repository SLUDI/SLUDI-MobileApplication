import os
import re

package_name = "new_project"
root_dir = "lib"

# Map of filename -> new relative path from lib/
moves = {
    "api_service.dart": "services/api_service.dart",
    "offline_auth_service.dart": "services/offline_auth_service.dart",
    "storage_service.dart": "services/storage_service.dart",
    "app_theme.dart": "theme/app_theme.dart",
    "theme_provider.dart": "providers/theme_provider.dart",
    "offline_auth_dialog.dart": "widgets/offline_auth_dialog.dart",
}

screens = [
    "backup_screen.dart", "change_password_screen.dart", "edit_profile_screen.dart",
    "face_detection_screen.dart", "history_screen.dart", "id_card_selection_screen.dart",
    "id_verification_screen.dart", "login_screen.dart", "main_screen.dart",
    "otp_verification_screen.dart", "presentation_approval_screen.dart", "profile_tab_screen.dart",
    "recover_wallet_screen.dart", "register_screen.dart", "scan_screen.dart",
    "splash_screen.dart", "wallet_screen.dart"
]

for s in screens:
    moves[s] = f"screens/{s}"

def update_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()
    
    original_content = content
    
    for filename, new_path in moves.items():
        # 1. Replace package imports
        # package:new_project/filename -> package:new_project/new_path
        content = content.replace(f"package:{package_name}/{filename}", f"package:{package_name}/{new_path}")
        
        # 2. Replace relative imports with absolute package imports
        # pattern: import '.../filename'; or import 'filename';
        # capture group 1 is the prefix (e.g. "../" or "")
        # We replace the entire path contents with package:new_project/new_path
        
        # Regex to find import '...filename'
        # We match start quote, optional path chars, filename, end quote.
        # We want to be careful not to break existing package imports that we just fixed (so check if it starts with package:).
        
        # Actually, simpler approach:
        # Find any string that ends with /filename or is just filename, AND is inside an import statement
        # Check if it is a package import. If so, we already handled it or it's fine.
        # If it is NOT a package import (i.e. starts with . or just a word), convert to package import.
        
        def replace_clean(match):
            full_match = match.group(0) # import '...'
            path = match.group(1) # content inside quotes
            
            if path.startswith("package:"):
                return full_match # Already handled or verified
            if path.startswith("dart:"):
                return full_match
            
            # Use basic string check
            if path.endswith(filename):
                return f"import 'package:{package_name}/{new_path}'"
            return full_match

        # Match import '...' or import "..."
        content = re.sub(r"import\s+['\"]([^'\"]+)['\"]", replace_clean, content)

    if content != original_content:
        print(f"Updating {filepath}")
        with open(filepath, 'w') as f:
            f.write(content)

for root, dirs, files in os.walk(root_dir):
    for file in files:
        if file.endswith(".dart"):
            update_file(os.path.join(root, file))
