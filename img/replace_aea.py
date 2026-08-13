import os
import shutil
import sys

# --- CONFIGURATION ---
# Change this to whatever custom ID you want to use
CUSTOM_ID = "oe"
TARGET_STRING = "aea"

def process_dropped_files():
    # sys.argv[0] is always the script name itself. 
    # sys.argv[1:] contains the paths of all files dragged and dropped onto it.
    dropped_files = sys.argv[1:]
    
    if not dropped_files:
        print("No files detected.")
        print("To use this script, drag and drop file(s) directly onto it.")
        input("\nPress Enter to exit...")
        return

    print(f"Detected {len(dropped_files)} file(s). Processing...\n")
    copied_count = 0

    for file_path in dropped_files:
        # Resolve absolute path
        file_path = os.path.abspath(file_path)
        
        # Ensure it's a file, not a directory
        if not os.path.isfile(file_path):
            print(f"Skipped: '{os.path.basename(file_path)}' (Not a file)")
            continue
            
        directory = os.path.dirname(file_path)
        filename = os.path.basename(file_path)
        
        # Check if the target string (e.g., "base") is in the filename
        if TARGET_STRING in filename:
            # Create the new filename
            new_filename = filename.replace(TARGET_STRING, CUSTOM_ID)
            new_file_path = os.path.join(directory, new_filename)
            
            # Prevent overwriting existing files
            if os.path.exists(new_file_path):
                print(f"Skipped: '{new_filename}' already exists in this folder.")
                continue
                
            try:
                # Copy the file
                shutil.copy2(file_path, new_file_path)
                print(f"Copied: '{filename}' -> '{new_filename}'")
                copied_count += 1
            except Exception as e:
                print(f"Error copying '{filename}': {e}")
        else:
            print(f"Skipped: '{filename}' (Does not contain '{TARGET_STRING}')")

    print(f"\nProcess complete. Successfully created {copied_count} new files.")
    input("\nPress Enter to close this window...")

if __name__ == "__main__":
    process_dropped_files()