#!/bin/zsh
# usage: cap.sh <variant> ; variant shipped|sonagi_name|sonagi_other|sonagi_knock
V=$1
OUT=/private/tmp/claude-501/-Users-sinjaeho-Documents-works-trend-mcp/057a2eec-410e-437b-bbc0-8a06d3c3c6ea/scratchpad/sonagi/cap/$V
rm -rf $OUT; mkdir -p $OUT
cd /Users/sinjaeho/Documents/works/trend-mcp-seolhwa-opening-a/seolhwa_godot
EXTRA=(); SECS=66
case $V in
  sonagi_name) EXTRA=(--opening=sonagi --sonagibot=name); SECS=${SECS_OVR:-88};;
  sonagi_other) EXTRA=(--opening=sonagi --sonagibot=other); SECS=${SECS_OVR:-88};;
  sonagi_knock) EXTRA=(--opening=sonagi_knock --sonagibot=name); SECS=${SECS_OVR:-88};;
esac
/opt/homebrew/bin/godot --path . --resolution 1280x720 -- --region=JL_NAMWON_UNBONG --savefile=user://st_sonagi_cap_${V}_$(date +%H%M%S).json --titletest=newcap:$OUT/frames --capsecs=$SECS --capstep=0.25 --capfine=30 --storylog $EXTRA > $OUT/log.txt 2>&1
echo "exit $?"
