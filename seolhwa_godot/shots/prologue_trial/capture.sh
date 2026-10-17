#!/bin/zsh
# usage: cap.sh <variant> ; variant current|current_e|framed
V=$1
OUT=/private/tmp/claude-501/-Users-sinjaeho-Documents-works-trend-mcp/057a2eec-410e-437b-bbc0-8a06d3c3c6ea/scratchpad/cap/$V
rm -rf $OUT; mkdir -p $OUT
cd /Users/sinjaeho/Documents/works/trend-mcp-seolhwa-prologue-trial/seolhwa_godot
EXTRA=()
[[ $V != current ]] && EXTRA=(--prologue=$V)
/opt/homebrew/bin/godot --path . --resolution 1280x720 -- --region=JL_NAMWON_UNBONG --savefile=user://st_protrial_$V.json --titletest=newcap:$OUT/frames --capsecs=64 --capstep=0.25 --capfine=15 --storylog $EXTRA > $OUT/log.txt 2>&1
echo "exit $?"
