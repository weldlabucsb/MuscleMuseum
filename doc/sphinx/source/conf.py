# Configuration file for the Sphinx documentation builder.
#
# For the full list of built-in configuration values, see the documentation:
# https://www.sphinx-doc.org/en/master/usage/configuration.html

# -- Project information -----------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#project-information

import os
import sys
sys.path.append('sphinx_extensions')
from copy_files import copy_files

copy_files() # Override internal linkcode module to correctly link matlab source.

project = 'MuscleMuseum'
copyright = '2025, Weld Lab'
author = 'Weld Lab'
release = '0.1'
highlight_language = 'matlab'
primary_domain = "mat"

# -- General configuration ---------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#general-configuration

extensions = [
    'sphinx.ext.mathjax',
    'sphinxcontrib.matlab', 
    'sphinx.ext.autodoc',
    'sphinx.ext.linkcode',
    'sphinx_copybutton',
    'sphinx.ext.viewcode',
    ]

templates_path = ['_templates']
exclude_patterns = []

# -- Linkcode definition -----------------------------------------------------

def linkcode_resolve(domain, info):
    module_name = info['module']
    if not(module_name) or module_name == '.':
        module_name = ''
    else:
        module_name = f"/{module_name.replace('.', '/')}"

    fullname = info['fullname']
    name = fullname.split('.')[0]

    repo_base_url = 'https://github.com/XiaoCasd/MuscleMuseum'
    source_url = f"{repo_base_url}/blob/main{module_name}/{name}.m"
    return source_url

# -- MATLAB options ----------------------------------------------------------

thisdir = os.path.dirname(__file__)
matlab_src_dir = os.path.abspath(os.path.join(thisdir, "..", "..",".."))
matlab_auto_link = "false"
matlab_show_property_default_value = True
matlab_show_property_specs = True
matlab_class_signature = True
matlab_short_links = True

# -- Options for HTML output -------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#options-for-html-output

html_theme = 'sphinx_book_theme'
html_static_path = ['_static']
html_theme_options = {
    "show_navbar_depth": int(4),
    "max_navbar_depth": int(4),
    "repository_url": "https://github.com/XiaoCasd/MuscleMuseum",
    "use_source_button": True,
    "use_repository_button": True,
    "repository_branch": "main",
    "path_to_docs": "doc/sphinx/source",
}
html_context = {
  'display_github': True,
  'github_user': 'XiaoCasd',
  'github_repo': 'MuscleMuseum',
  'github_version': 'main',
  "conf_py_path": "/doc/sphinx/source/"
}