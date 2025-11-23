# Clear Xcode Cache and Fix Stale Errors

## If You're Seeing Red Errors in Xcode

Even though the build succeeds from command line, Xcode might show stale errors. Here's how to fix:

### Method 1: Clean Build Folder (Try This First)

1. In Xcode menu: **Product → Clean Build Folder** (Shift+Cmd+K)
2. Wait for it to finish
3. Build again: **Product → Build** (Cmd+B)

### Method 2: Delete Derived Data

If Method 1 doesn't work:

1. In Xcode menu: **Xcode → Settings** (Cmd+,)
2. Go to **Locations** tab
3. Click the arrow next to **Derived Data** path
4. Finder will open
5. Find the `radial-menu-...` folder
6. Delete it
7. Restart Xcode
8. Build again

### Method 3: Nuclear Option (If nothing else works)

```bash
# Close Xcode first!

# Delete all Xcode caches
rm -rf ~/Library/Developer/Xcode/DerivedData/*
rm -rf ~/Library/Caches/com.apple.dt.Xcode

# Reopen Xcode
open radial-menu.xcodeproj
```

## Verify Build Success

After cleaning:

1. **Build** (Cmd+B) - Should say "Build Succeeded"
2. **Run** (Cmd+R) - App should launch

## Current Build Status

✅ Command line build: **SUCCEEDED**
✅ Only warnings (not errors)
✅ App binary created successfully

Full build log available at: `~/Desktop/radial-menu-build.log`
