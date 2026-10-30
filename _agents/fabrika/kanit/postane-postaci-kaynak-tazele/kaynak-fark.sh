#!/usr/bin/env bash
# beceri kopyası ⟷ cloudtop (sultanxgokce/cloudtop) origin/main infra/postane — hedef: postane 0.1.6
C=/config/projects/cloudtop
echo "cloudtop origin/main: $(git -C $C rev-parse origin/main)"
echo "cloudtop postane sürümü (package.json): $(git -C $C show origin/main:infra/postane/package.json | python3 -c 'import sys,json;print(json.load(sys.stdin)["version"])')"
echo "postane.mjs son commit: $(git -C $C log origin/main --oneline -1 -- infra/postane/postane.mjs)"
d=0; for f in postaci.mjs postane.mjs ajan-adlari.mjs ulid.mjs; do
  a=$(git -C $C show origin/main:infra/postane/$f | sha256sum | cut -d' ' -f1)
  b=$(sha256sum "$1/postane-postaci/scripts/$f" | cut -d' ' -f1); [ "$a" = "$b" ] || d=$((d+1)); done
echo "kaynaktan farklı dosya: $d"; exit 0
