# 1. Extract the tarball
tar -xf icon_dump_2026-01-04.tar

# 2. Create a destination folder
mkdir -p processed_icons

# 3. Loop through the App Store directories and grab the best icon
# This prioritizes the highest resolution iPhone icon (60x60@3x)
for app_dir in icon_dump/appstore/*; do
    # Get the Bundle ID from the folder name (e.g., com.tigisoftware.Filza)
    bundle_id=$(basename "$app_dir")
    
    # Define the icon priority list (Best -> Worst)
    # We look for the main app icon first, then iPad variants if missing
    icon_path=$(find "$app_dir" -name "AppIcon60x60@3x.png" -print -quit)
    
    if [ -z "$icon_path" ]; then
        icon_path=$(find "$app_dir" -name "AppIcon60x60@2x.png" -print -quit)
    fi
    
    if [ -z "$icon_path" ]; then
        icon_path=$(find "$app_dir" -name "AppIcon76x76@2x~ipad.png" -print -quit)
    fi

    # If we found an icon, copy it to the clean folder
    if [ -n "$icon_path" ]; then
        cp "$icon_path" "processed_icons/${bundle_id}.png"
        echo "Processed: $bundle_id"
    else
        echo "Skipping: $bundle_id (No suitable icon found)"
    fi
done

echo "Done! Check the 'processed_icons' folder."
