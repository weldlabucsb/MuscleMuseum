import os
import glob
from pathlib import Path

def generate_doc_file(file_path, src_root, api_output_dir):
    """
    Generates an .rst file for a single MATLAB file and places it in the
    correct output directory.
    """
    file_name = file_path.stem
    directive = None
    is_class = False
    
    # Check file extension to determine the Sphinx directive
    if file_path.suffix == '.mlapp':
        directive = 'autoapplication'
    elif file_path.suffix == '.m':
        # Heuristic to distinguish between classes and functions in MATLAB
        # Class files typically start with an uppercase letter
        is_class = file_name[0].isupper()
        if is_class:
            directive = 'autoclass'
        else:
            directive = 'autofunction'
    
    if not directive:
        return None # Skip files that are not .m or .mlapp

    # Construct the Sphinx-friendly MATLAB module path to include 'src' at the root.
    relative_path_to_file = os.path.relpath(file_path, src_root)
    # Split the path into parts, remove the file extension, and handle '+' prefixes
    parts = os.path.splitext(relative_path_to_file)[0].split(os.sep)
    module_parts = ['src'] + [p.lstrip('+') for p in parts]
    module_name = ".".join(module_parts)
    
    # Build the core content without a trailing newline after the directive
    rst_content = f"""{file_name}
{'=' * len(file_name)}

.. mat:{directive}:: {module_name}"""

    # Add extra directives for class files without an empty line
    if is_class:
        rst_content += """
   :members:
   :private-members:
   :show-inheritance:
   :undoc-members:
"""
    else:
        # Add a single newline for non-class files for proper formatting
        rst_content += "\n"
    
    output_file_path = api_output_dir / f'{file_name}.rst'
    with open(output_file_path, 'w') as f:
        f.write(rst_content)
    
    return file_name


def main():
    """
    Main function to orchestrate the documentation generation.
    """
    script_path = Path(__file__).resolve()
    project_root = script_path.parent.parent.parent
    
    src_root = project_root / 'src'
    api_root = script_path.parent / 'source' / 'api'
    
    print(f"Generating documentation for MATLAB source files in {src_root}...")

    # --- Step 1: Map all source files to their intended doc file paths ---
    source_to_doc_map = {}
    for module_dir in src_root.iterdir():
        if module_dir.is_dir() and module_dir.name not in ['__pycache__']:
            module_name = module_dir.name
            module_api_dir = api_root / module_name
            
            # Find all .m and .mlapp files recursively
            files_to_doc = list(module_dir.rglob('*.m')) + list(module_dir.rglob('*.mlapp'))
            
            for file_path in files_to_doc:
                file_name = file_path.stem
                doc_path = module_api_dir / f'{file_name}.rst'
                source_to_doc_map[file_path] = doc_path

    # --- Step 2: Create missing doc files and directories ---
    print("Checking for missing documentation files...")
    for source_path, doc_path in source_to_doc_map.items():
        if not doc_path.exists():
            print(f"Creating doc file for: {source_path}")
            # Ensure the output directory exists
            doc_path.parent.mkdir(parents=True, exist_ok=True)
            generate_doc_file(source_path, src_root, doc_path.parent)

    # --- Step 3: Delete extra doc files that no longer have a source ---
    print("Checking for outdated documentation files...")
    all_doc_paths = set(api_root.rglob('*.rst'))
    for doc_path in all_doc_paths:
        if doc_path.name == 'index.rst':
            continue
        
        if doc_path not in source_to_doc_map.values():
            print(f"Deleting outdated doc file: {doc_path}")
            os.remove(doc_path)
    
    # --- Step 4: Rebuild module and main index files ---
    print("Rebuilding index files...")
    top_level_modules = []
    for module_dir in src_root.iterdir():
        if module_dir.is_dir() and module_dir.name not in ['__pycache__']:
            module_name = module_dir.name
            top_level_modules.append(module_name)
            
            module_api_dir = api_root / module_name
            module_doc_files = []
            
            if module_api_dir.exists():
                for doc_file_path in module_api_dir.glob('*.rst'):
                    if doc_file_path.name != 'index.rst':
                        module_doc_files.append(doc_file_path.stem)
            
            # Create a single index file for this module, named 'index.rst'
            module_index_path = module_api_dir / 'index.rst'
            with open(module_index_path, 'w') as f:
                f.write(f"{module_name}\n")
                f.write(f"{'=' * len(module_name)}\n\n")
                f.write(f".. toctree::\n")
                f.write(f"   :maxdepth: 2\n\n")
                for doc_file in sorted(module_doc_files):
                    f.write(f"   {doc_file}\n")
    
    # Create/update the main API index.rst file to link to module indexes
    main_api_index_path = api_root / 'index.rst'
    with open(main_api_index_path, 'w') as f:
        f.write("API Documentation\n")
        f.write("=================\n\n")
        f.write(".. toctree::\n")
        f.write("   :maxdepth: 2\n\n")
        for module in sorted(top_level_modules):
            f.write(f"   {module}/index\n")

    print("Documentation files generated and toctrees updated successfully.")

if __name__ == '__main__':
    main()
