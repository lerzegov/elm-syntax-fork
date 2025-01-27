#!/bin/bash
file="src/ParserFast.elm"
module_name=$(basename "$file" .elm)

# Get the exposing list: start at 'exposing' line, continue until closing parenthesis
exposed=$(sed -n '/^module.*exposing/,/)/p' "$file" | \
         grep -v "module" | \
         tr -d '(' | tr -d ')' | \
         tr '\n' ' ' | \
         sed 's/,//g' | \
         tr -s ' ')

# Debug
echo "Found exposed items: $exposed"

# Find the line number of the first import
import_line=$(grep -n "^import" "$file" | head -1 | cut -d: -f1)

if [ ! -z "$import_line" ]; then
    # Insert @docs before the first import
    sed -i '' "${import_line}i\\
{-| @docs ${exposed}\
-}\\
" "$file"
fi

# Process each exposed item
for item in $exposed; do
    # Remove any leading/trailing whitespace
    item=$(echo "$item" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # Debug
    echo "Processing item: '$item'"
    
    # Find line with type signature (containing ':')
    if grep -q "^${item}[[:space:]]*:" "$file"; then
        echo "Found signature for: $item"
        sed -i '' "/^${item}[[:space:]]*:/i\\
{-| ${item} functionality\
-}\\
" "$file"
    fi
done