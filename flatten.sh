#!/bin/bash
find contracts/ -maxdepth 1 -type f -exec sh -c 'echo "{}" | sed "s#^\(.*\/\)\(\w\+\.sol\)\$#npx hardhat flatten \1\2 > flattened/\2#"' \; | xargs -I {} sh -c "{}"
