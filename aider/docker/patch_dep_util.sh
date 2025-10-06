#!/bin/bash

# Patch script to fix setuptools.dep_util issues in astropy
# This script patches the astropy code to handle missing dep_util

find . -name "*.py" -exec grep -l "from setuptools.dep_util import" {} \; | while read file; do
    echo "Patching $file for setuptools.dep_util..."
    # Create a backup
    cp "$file" "$file.bak"
    
    # Use Python to do the replacement with proper indentation
    python3 -c "
import re
with open('$file', 'r') as f:
    content = f.read()

# Replace the import with a try/except block, preserving indentation
pattern = r'^(\s*)from setuptools\.dep_util import (.+)$'
replacement = r'\1try:\n\1    from setuptools.dep_util import \2\n\1except ImportError:\n\1    from distutils.dep_util import \2'
content = re.sub(pattern, replacement, content, flags=re.MULTILINE)

with open('$file', 'w') as f:
    f.write(content)
"
done

# Also handle specific astropy files that may have this issue
if [ -f "astropy/wcs/setup_package.py" ]; then
    echo "Patching astropy/wcs/setup_package.py specifically..."
    cp "astropy/wcs/setup_package.py" "astropy/wcs/setup_package.py.bak"
    
    python3 -c "
import re
with open('astropy/wcs/setup_package.py', 'r') as f:
    content = f.read()

# Replace the import with a try/except block, preserving indentation
pattern = r'^(\s*)from setuptools\.dep_util import (.+)$'
replacement = r'\1try:\n\1    from setuptools.dep_util import \2\n\1except ImportError:\n\1    from distutils.dep_util import \2'
content = re.sub(pattern, replacement, content, flags=re.MULTILINE)

with open('astropy/wcs/setup_package.py', 'w') as f:
    f.write(content)
"
fi

echo "Patching complete"