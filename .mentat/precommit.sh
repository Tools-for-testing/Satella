#!/bin/bash

# Pre-commit script to validate GitHub Actions workflow files
echo "Running pre-commit checks for GitHub Actions workflows..."

# Check for existence of workflow files
if [ -d ".github/workflows" ]; then
  echo "✓ Found .github/workflows directory"
else
  echo "❌ No .github/workflows directory found"
  exit 1
fi

# Validate GitHub Actions workflow files with actionlint if available
if command -v actionlint &> /dev/null; then
  echo "Running actionlint to validate workflow files..."
  actionlint .github/workflows/*.yml
  
  if [ $? -ne 0 ]; then
    echo "❌ actionlint found issues with workflow files"
    exit 1
  else
    echo "✓ actionlint validation passed"
  fi
else
  echo "⚠️  actionlint not installed, skipping detailed validation"
  echo "   Consider installing actionlint for better workflow validation:"
  echo "   https://github.com/rhysd/actionlint#installation"
fi

# Basic YAML validation for workflow files
for file in .github/workflows/*.yml; do
  if [ -f "$file" ]; then
    # Use Ruby for basic YAML validation if available
    if command -v ruby &> /dev/null; then
      ruby -ryaml -e "YAML.load_file('$file')" 2>/dev/null
      
      if [ $? -ne 0 ]; then
        echo "❌ Invalid YAML in $file"
        exit 1
      else
        echo "✓ Valid YAML in $file"
      fi
    else
      echo "⚠️  Ruby not available, skipping YAML validation for $file"
    fi
    
    # Check for common action versions
    if grep -q "actions/checkout@v[1-3]" "$file"; then
      echo "⚠️  $file is using an older version of actions/checkout. Consider updating to v4."
    fi
    
    if grep -q "actions/upload-artifact@v[1-3]" "$file"; then
      echo "⚠️  $file is using an older version of actions/upload-artifact. Consider updating to v4."
    fi
    
    if grep -q "softprops/action-gh-release@v1" "$file"; then
      echo "⚠️  $file is using an older version of softprops/action-gh-release. Consider updating to v2."
    fi
    
    # Check for proper error handling in shell commands
    if grep -q "mv.*sdk" "$file" && ! grep -q "mv.*sdk.*||" "$file"; then
      echo "⚠️  SDK move command in $file might not have error handling."
    fi
    
    if grep -q "cp.*deb" "$file" && ! grep -q "cp.*deb.*||" "$file"; then
      echo "⚠️  DEB copy command in $file might not have error handling."
    fi
  fi
done

echo "Pre-commit checks completed"
exit 0
