#!/usr/bin/env python3
"""Curated AI research signal collector: Hugging Face Daily Papers and lab RSS."""
import datetime as dt
import email.utils
import json
from pathlib import Path
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

HERE=Path(__file__).resolve().parent
DATA=HERE/"data"
OUT=DATA/"research_signals.json"
STATE=DATA/"research_signals_status.json"
FEEDS={
    "openai_research":"https://openai.com/news/rss.xml",
    "deepmind_research":"https://deepmind.google/blog/rss.xml",
    "bair_research":"https://bair.berkeley.edu/blog/feed.xml",
}
NS={"atom":"http://www.w3.org/2005/Atom"}

def get(url):
    req=urllib.request.Request(url,headers={"User-Agent":"DailyAINewsResearchMonitor/1.0","Accept":"application/json, application/rss+xml, application/atom+xml, application/xml, */*"})
    with urllib.request.urlopen(req,timeout=35) as r:return r.read()
def utc(value):
    if not value:return None
    try:
        x=dt.datetime.fromisoformat(str(value).replace("Z","+00:00"))
        return x.astimezone(dt.timezone.utc).isoformat().replace("+00:00","Z")
    except (ValueError,TypeError):
        try:return email.utils.parsedate_to_datetime(value).astimezone(dt.timezone.utc).isoformat().replace("+00:00","Z")
        except (ValueError,TypeError):return None
def hf():
    rows=json.loads(get("https://huggingface.co/api/daily_papers?limit=100&sort=trending"))
    if not isinstance(rows,list):raise ValueError("unexpected Hugging Face response")
    out=[]
    for entry in rows:
        if not isinstance(entry,dict):continue
        p=entry.get("paper") or entry
        pid=p.get("id") or p.get("paperId")
        if not pid:continue
        url="https://huggingface.co/papers/"+str(pid)
        out.append({
            "id":"hf:"+str(pid),"source":"hf_daily_papers","type":"paper",
            "title":p.get("title") or entry.get("title"),
            "url":url,"arxiv_url":"https://arxiv.org/abs/"+str(pid),
            "published_at":utc(p.get("publishedAt") or entry.get("publishedAt")),
            "summary":(p.get("summary") or "")[:3200],
            "upvotes":p.get("upvotes",entry.get("upvotes",0)),
            "comments":p.get("numComments",entry.get("numComments",0)),
            "has_code":bool(p.get("githubRepo") or p.get("repository")),
            "project_page":p.get("projectPage"),
            "signals":["huggingface_curated"],
        })
    return out
def rss(source,url):
    raw=get(url)
    if raw.lstrip().startswith(b"<html") or raw.lstrip().startswith(b"<!DOCTYPE html"):\n        raise ValueError("RSS endpoint returned HTML rather than XML")
    root=ET.fromstring(raw)
    out=[]
    rss_items=root.findall(".//item")
    if rss_items:
        for x in rss_items:
            title=(x.findtext("title") or "").strip()
            link=(x.findtext("link") or "").strip()
            if title and link:
                out.append({"id":source+":"+link,"source":source,"type":"lab_announcement","title":title,"url":link,"published_at":utc(x.findtext("pubDate")),"summary":(x.findtext("description") or "")[:1400],"signals":["official_lab_publication"]})
    else:
        for x in root.findall(".//atom:entry",NS):
            title=(x.findtext("atom:title",default="",namespaces=NS) or "").strip()
            link_el=x.find("atom:link",NS)
            link=(link_el.get("href","") if link_el is not None else "").strip()
            if title and link:
                out.append({"id":source+":"+link,"source":source,"type":"lab_announcement","title":title,"url":link,"published_at":utc(x.findtext("atom:published",namespaces=NS) or x.findtext("atom:updated",namespaces=NS)),"summary":(x.findtext("atom:summary",default="",namespaces=NS) or "")[:1400],"signals":["official_lab_publication"]})
    return out
def main():
    now=dt.datetime.now(dt.timezone.utc)
    stamp=now.isoformat().replace("+00:00","Z")
    try: old=json.loads(OUT.read_text(encoding="utf-8"))
    except (OSError,ValueError):old={"items":[]}
    items={x["id"]:x for x in old.get("items",[]) if x.get("id")}
    report={}
    sources=[("hf_daily_papers",hf)]+[(k,lambda k=k,v=v:rss(k,v)) for k,v in FEEDS.items()]
    cutoff_date=now-dt.timedelta(days=7)
    for name,fn in sources:
        try:
            found=fn()
            if not found:raise ValueError("no entries")
            fresh=0
            skipped=0
            for x in found:
                published=utc(x.get("published_at"))
                if not published or dt.datetime.fromisoformat(published.replace("Z","+00:00")) < cutoff_date:
                    skipped+=1
                    continue
                key=x["id"]
                if key not in items:fresh+=1
                x["first_seen_at"]=items.get(key,{}).get("first_seen_at",stamp)
                x["last_seen_at"]=stamp
                items[key]=x
            report[name]={"status":"ok","fetched":len(found),"new":fresh,"skipped_old_or_undated":skipped}
        except Exception as e:
            report[name]={"status":"error","error":str(e)[:240]}
    cutoff=(now-dt.timedelta(days=7)).isoformat()
    # Seven days from first observation; don't reset the age on rediscovery.
    kept=[x for x in items.values() if (x.get("first_seen_at") or stamp)>=cutoff and x.get("published_at") and x["published_at"]>=cutoff]
    kept.sort(key=lambda x:(x.get("published_at") or "",x["id"]),reverse=True)
    DATA.mkdir(parents=True,exist_ok=True)
    OUT.write_text(json.dumps({"generated_at":stamp,"retention_days":7,"items_count":len(kept),"sources":report,"items":kept},ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    STATE.write_text(json.dumps({"generated_at":stamp,"sources":report},ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"items_count":len(kept),"sources":report},ensure_ascii=False))
    if all(v["status"]=="error" for v in report.values()):raise SystemExit("All research feeds unavailable")
if __name__=="__main__":main()
