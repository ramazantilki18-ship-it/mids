import os

source_path = r"c:\Users\PC\Desktop\TEST - 11.05.2026\denetim_app\analysis_output.txt"
dest_path = r"c:\Users\PC\Desktop\TEST - 11.05.2026\denetim_app\analysis_output_utf8.md"

if os.path.exists(source_path):
    with open(source_path, "r", encoding="utf-16-le") as f:
        content = f.read()
    with open(dest_path, "w", encoding="utf-8") as f:
        f.write(content)
    print("Conversion successful!")
else:
    print("Source file not found!")
