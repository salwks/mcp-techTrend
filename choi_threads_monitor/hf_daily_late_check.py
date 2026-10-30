#!/usr/bin/env python3
"""Late-day completeness check for the current Hugging Face Daily Papers page.

Metadata only. The editorial LLM report is generated once after this check.
"""
import datetime as dt
import json
from pathlib import Path
from collect_research import hf

DATA=Path(__file__).resolve().parent/"data"
OUT=DATA/"research_signals.json"
STATUS=DATA/"research_signals_status.json"

def write(path,payload):
    path.write_text(json.dumps(payload,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")

def main():
    now=dt.datetime.now(dt.timezone.utc)
    today=(now+dt.timedelta(hours=9)).date().isoformat()
    stamp=now.isoformat().replace("+00:00","Z")
    old=json.loads(OUT.read_text(encoding="utf-8"))
    existing={x["id"]:x for x in old.get("items",[]) if x.get("id")}
    previous_today=[x for x in existing.values() if x.get("source")=="hf_daily_papers" and x.get("daily_papers_date")==today]
    found=hf()
    if not found or any(x.get("daily_papers_date")!=today for x in found):
        raise ValueError("Daily Papers API returned an empty or wrong-date listing")
    if len({x["id"] for x in found}) < len(previous_today):
        raise ValueError("Hugging Face listing became smaller; refusing to silently drop papers")
    added=0
    for x in found:
        key=x["id"]
        if key not in existing:
            added+=1
        x["first_seen_at"]=existing.get(key,{}).get("first_seen_at",stamp)
        x["last_seen_at"]=stamp
        existing[key]=x
    cutoff=now-dt.timedelta(days=7)
    kept=[]
    for x in existing.values():
        first=x.get("first_seen_at")
        if not first:
            continue
        try:
            first_dt=dt.datetime.fromisoformat(first.replace("Z","+00:00"))
        except (TypeError,ValueError):
            continue
        if first_dt < cutoff:
            continue
        if x.get("daily_papers_date"):
            if x["daily_papers_date"] < (now-dt.timedelta(days=6)).date().isoformat():
                continue
        elif x.get("published_at","") < cutoff.isoformat().replace("+00:00","Z"):
            continue
        kept.append(x)
    kept.sort(key=lambda x:(x.get("published_at") or "",x["id"]),reverse=True)
    sources=dict(old.get("sources") or {})
    sources["hf_daily_papers"]={"status":"ok","fetched":len(found),"new":added,
                                "skipped_old_or_undated":0,"mode":"late_day_completeness_check"}
    DATA.mkdir(parents=True,exist_ok=True)
    write(OUT,{"generated_at":stamp,"retention_days":7,"items_count":len(kept),
               "sources":sources,"items":kept})
    write(STATUS,{"generated_at":stamp,"sources":sources})
    todays=[x for x in kept if x.get("source")=="hf_daily_papers" and x.get("daily_papers_date")==today]
    todays.sort(key=lambda x:(x.get("upvotes") or 0,x.get("title") or ""),reverse=True)
    write(DATA/"hf_daily_today.json",{"date":today,"items_count":len(todays),"items":todays})
    md=["# Hugging Face Daily Papers — "+today,"","Total: "+str(len(todays)),""]
    for i,x in enumerate(todays,1):
        md.extend([f"### {i}. {x.get('title') or '(untitled)'}",
                   f"Paper: {x.get('url') or ''}",
                   f"Upvotes: {x.get('upvotes') or 0}","",
                   str(x.get("summary") or "(No abstract supplied)"),""])
    (DATA/"hf_daily_today.md").write_text("\n".join(md)+"\n",encoding="utf-8")
    print(json.dumps({"date":today,"papers":len(todays),"late_additions":added}))

if __name__=="__main__":
    main()
