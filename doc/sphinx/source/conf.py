# Configuration file for the Sphinx documentation builder.
#
# For the full list of built-in configuration values, see the documentation:
# https://www.sphinx-doc.org/en/master/usage/configuration.html

# -- Project information -----------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#project-information

project = 'MuscleMuseum'
copyright = '2025, Weld Lab'
author = 'Weld Lab'
release = '0.1'
highlight_language = 'matlab'

# -- General configuration ---------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#general-configuration

extensions = ['sphinxcontrib.matlab', 'sphinx.ext.autodoc']

templates_path = ['_templates']
exclude_patterns = []

# -- MATLAB options ----------------------------------------------------------

import os
primary_domain = "mat"
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
}