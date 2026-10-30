#!/usr/bin/env python3
"""Collect external AI/technology headlines without disturbing the CHOI queue."""
import concurrent.futures
import datetime as dt
import email.utils
import hashlib
import json
import os
from pathlib import Path
import urllib.request
import xml.etree.ElementTree as ET

BASE=Path(__file__).resolve().parent
DATA=BASE/"data"
OUTPUT=DATA/"external_news.json"
STATUS=DATA/"external_news_status.json"
UA="DailyAINewsCollector/1.0 (news feed metadata)"
KEYWORDS=("ai","artificial intelligence","openai","anthropic","claude","chatgpt","gpt-","gemini","google deepmind","mistral","llm","language model","machine learning","neural","robot","agent","nvidia","inference","model weights","hugging face","qwen","deepseek","chip","semiconductor","datacenter","data center","cursor","codex","copilot","xai","grok","perplexity","midjourney","diffusion","generative","transformer","quantum")
def fetch(url):
    req=urllib.request.Request(url,headers={"User-Agent":UA,"Accept":"application/json, application/rss+xml, application/xml, text/xml, */*"})
    with urllib.request.urlopen(req,timeout=25) as response:
        return response.read()
def iso(ts):
    return dt.datetime.fromtimestamp(int(ts),dt.timezone.utc).isoformat().replace("+00:00","Z")
def normalize_url(url):
    return (url or "").split("#",1)[0].rstrip("/")
def ident(url):
    return hashlib.sha256(normalize_url(url).encode("utf-8")).hexdigest()[:24]
def parse_rss():
    root=ET.fromstring(fetch("https://www.techmeme.com/feed.xml"))
    out=[]
    for item in root.findall(".//item"):
        title=(item.findtext("title") or "").strip()
        url=(item.findtext("link") or "").strip()
        if not title or not url: continue
        pub=(item.findtext("pubDate") or "").strip()
        try: published=email.utils.parsedate_to_datetime(pub).astimezone(dt.timezone.utc).isoformat().replace("+00:00","Z")
        except Exception: published=None
        out.append({"id":"techmeme:"+ident(url),"source":"techmeme","title":title,"url":url,"published_at":published,"discovered_via":"rss"})
    return out
def hn_item(item_id):
    try:
        x=json.loads(fetch(f"https://hacker-news.firebaseio.com/v0/item/{int(item_id)}.json"))
        if not isinstance(x,dict) or x.get("type")!="story" or x.get("deleted") or x.get("dead"):return None
        title=x.get("title","")
        if not any(word in title.lower() for word in KEYWORDS):return None
        return {"id":"hackernews:"+str(x["id"]),"source":"hackernews","title":title,"url":x.get("url") or f"https://news.ycombinator.com/item?id={x['id']}","published_at":iso(x["time"]),"hn_score":x.get("score"),"hn_comments":x.get("descendants"),"discovered_via":"newstories"}
    except Exception:return None
def collect_hn():
    ids=json.loads(fetch("https://hacker-news.firebaseio.com/v0/newstories.json"))
    if not isinstance(ids,list) or not ids:raise ValueError("empty Hacker News newstories")
    # Up to 250 most recent submissions per run; capture metadata only.
    with concurrent.futures.ThreadPoolExecutor(max_workers=12) as pool:
        result=list(pool.map(hn_item,ids[:250]))
    return [x for x in result if x]
def read_previous():
    if not OUTPUT.exists():return {"items":[]}
    try:return json.loads(OUTPUT.read_text(encoding="utf-8"))
    except Exception:return {"items":[]}
def main():
    now=dt.datetime.now(dt.timezone.utc)
    stamp=now.isoformat().replace("+00:00","Z")
    previous=read_previous()
    by_id={x["id"]:x for x in previous.get("items",[]) if isinstance(x,dict) and x.get("id")}
    diagnostics={}
    for name,fn in (("techmeme",parse_rss),("hackernews",collect_hn)):
        try:
            records=fn()
            if not records:raise ValueError("empty source response")
            new=0
            for entry in records:
                if entry["id"] not in by_id:
                    entry["first_seen_at"]=stamp
                    new+=1
                else:
                    entry["first_seen_at"]=by_id[entry["id"]].get("first_seen_at",stamp)
                entry["last_seen_at"]=stamp
                by_id[entry["id"]]=entry
            diagnostics[name]={"status":"ok","fetched":len(records),"new":new}
        except Exception as exc:
            diagnostics[name]={"status":"error","error":str(exc)[:300]}
    DATA.mkdir(parents=True,exist_ok=True)
    # Keep a rolling 7-day history while preserving source errors in a separate status file.
    cutoff=(now-dt.timedelta(days=7)).isoformat()
    items=[x for x in by_id.values() if (x.get("first_seen_at") or stamp)>=cutoff]
    items.sort(key=lambda x:(x.get("published_at") or "",x["id"]),reverse=True)
    payload={"generated_at":stamp,"retention_days":7,"items_count":len(items),"sources":diagnostics,"items":items}
    OUTPUT.write_text(json.dumps(payload,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    STATUS.write_text(json.dumps({"generated_at":stamp,"sources":diagnostics},ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"items_count":len(items),"sources":diagnostics},ensure_ascii=False))
    if all(x["status"]=="error" for x in diagnostics.values()):raise SystemExit("All sources failed")
if __name__=="__main__":main()
