#!/bin/bash
for file in src/Elm/Parser/*.elm; do
    module_name=$(basename "$file" .elm)
    exposed=$(grep -A1 "^module" "$file" | grep "exposing" | sed 's/.*exposing (//' | sed 's/).*//')
    
    # Find the line number of the first import
    import_line=$(grep -n "^import" "$file" | head -1 | cut -d: -f1)
    
    if [ ! -z "$import_line" ]; then
        # Insert @docs before the first import
        sed -i '' "${import_line}i\\
{-| @docs ${exposed}\
-}\\
" "$file"
    fi
    
    # Only add function docs before type signatures
    for item in $(echo $exposed | tr ',' '\n'); do
        # Find line with type signature (containing ':')
        if grep -q "^${item}[[:space:]]*:" "$file"; then
            sed -i '' "/^${item}[[:space:]]*:/i\\
{-| ${item} functionality\
-}\\
" "$file"
        fi
    done
done