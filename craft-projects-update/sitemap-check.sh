#!/bin/bash
# usage: sitemap-check.sh <base-url>
base=${1%/}; host=$(echo "$base" | sed -E 's#(https?://[^/]+).*#\1#')
echo "ROOT $(curl -sk -o /dev/null -w '%{http_code}' "$base/")"
queue=("$base/sitemap.xml"); seen=(); pages=0; bad=0
while [ ${#queue[@]} -gt 0 ]; do
  sm=${queue[0]}; queue=("${queue[@]:1}"); seen+=("$sm")
  body=$(curl -sk -w '\n%{http_code}' "$sm"); code=$(tail -1 <<<"$body"); xml=$(sed '$d' <<<"$body")
  echo "SITEMAP $code $sm"; [ "$code" = 200 ] || continue
  locs=$(grep -oE '<loc>[^<]+</loc>' <<<"$xml" | sed -E 's#</?loc>##g' | sed -E "s#^https?://[^/]+#$host#")
  if grep -q '<sitemapindex' <<<"$xml"; then for l in $locs; do queue+=("$l"); done; continue; fi
  for l in $locs; do pages=$((pages+1)); c=$(curl -sk -o /dev/null -w '%{http_code}' "$l"); [ "$c" = 200 ] || { bad=$((bad+1)); echo "BAD $c $l"; }; done
done
echo "PAGES $pages NON200 $bad"
