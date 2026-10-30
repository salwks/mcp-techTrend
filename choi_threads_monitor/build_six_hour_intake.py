#!/usr/bin/env python3
"""Build a compact six-hour AI-news intake, without LLM or full article bodies."""
import datetime as dt
import json
from pathlib import Path

DATA=Path(__file__).resolve().parent/"data"
NOW=dt.datetime.now(dt.timezone.utc)
WINDOW_HOURS=6
LIMITS={"choi":150,"external":250,"research":60}

def timestamp(s):
    try:return dt.datetime.fromisoformat(str(s).replace("Z","+00:00")).astimezone(dt.timezone.utc)
    except (TypeError,ValueError):return None
def load(filename):
    try:return json.loads((DATA/filename).read_text(encoding="utf-8"))
    except (OSError,ValueError):return {}
def recent(s):
    d=timestamp(s)
    return d is not None and NOW-dt.timedelta(hours=WINDOW_HOURS)<=d<=NOW+dt.timedelta(minutes=5)
def compact(text,n=400):
    return " ".join(str(text or "").split())[:n]
def main():
    seen=set()
    news=[]
    counts={}
    def add(group,source,id,title,url,when,abstract="",**other):
        if not recent(when) or not title:return
        key=str(id or url)
        if key in seen:return
        seen.add(key)
        news.append({"group":group,"source":source,"id":key,"title":compact(title,320),"url":url,"published_at":when,**({"abstract":compact(abstract,650)} if abstract else {}),**other})
        counts[group]=counts.get(group,0)+1

    choi=load("choi_latest.json")
    for x in choi.get("posts",[]):
        add("choi","choi_threads",x.get("post_id"),x.get("text"),x.get("permalink"),x.get("published_at"))
    ext=load("external_news.json")
    for x in ext.get("items",[]):
        add("external",x.get("source"),x.get("id"),x.get("title"),x.get("url"),x.get("published_at"),hn_score=x.get("hn_score"))
    research=load("research_signals.json")
    for x in research.get("items",[]):
        add("research",x.get("source"),x.get("id"),x.get("title"),x.get("url"),x.get("published_at"),x.get("summary"),upvotes=x.get("upvotes"),signal_type=x.get("type"))
    news.sort(key=lambda x:x["published_at"],reverse=True)
    selected=[]
    for group,cap in LIMITS.items():
        group_items=[x for x in news if x["group"]==group]
        if group=="research":group_items.sort(key=lambda x:(x.get("upvotes") or 0,x["published_at"]),reverse=True)
        selected.extend(group_items[:cap])
    selected.sort(key=lambda x:x["published_at"],reverse=True)
    result={"generated_at":NOW.isoformat().replace("+00:00","Z"),"window_hours":WINDOW_HOURS,"total_candidates":len(selected),"counts_by_group":{k:sum(x["group"]==k for x in selected) for k in LIMITS},"source_status":{"choi":choi.get("collection_status"),"external":ext.get("sources"),"research":research.get("sources")},"caveat":"Candidate discovery only. Not fact-checked or semantically deduplicated; select and verify before publishing.","items":selected}
    DATA.mkdir(parents=True,exist_ok=True)
    (DATA/"six_hour_intake.json").write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    lines=[f"# AI News six-hour intake — {result['generated_at']}","",f"Candidates: {len(selected)} (CHOI {result['counts_by_group']['choi']}, external {result['counts_by_group']['external']}, research {result['counts_by_group']['research']})","","> Unverified candidates. Check original sources before publishing.",""]
    for x in selected:
        lines.append(f"- [{x['group']}/{x['source']}] {x['title']} ({x['published_at']}) — {x['url']}")
        if x.get("abstract"):lines.append("  Abstract: "+x["abstract"])
    (DATA/"six_hour_intake.md").write_text("\n".join(lines)+"\n",encoding="utf-8")
    print(json.dumps(result["counts_by_group"]))
if __name__=="__main__":main()
