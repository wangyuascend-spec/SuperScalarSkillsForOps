import json,pathlib,collections,hashlib,re,sys
def events(path):
 decoder=json.JSONDecoder()
 with pathlib.Path(path).open() as f:
  buf=f.read(65536)
  pos=buf.find("[")
  if pos<0 or '"traceEvents"' not in buf[:pos]:raise ValueError("missing traceEvents array")
  buf=buf[pos+1:]
  first=True
  while True:
   while not buf.strip():
    chunk=f.read(65536)
    if not chunk:raise ValueError("truncated trace")
    buf+=chunk
   buf=buf.lstrip()
   if buf.startswith("]"):
    tail=buf[1:]+f.read()
    if tail.strip()!="}":raise ValueError("invalid root terminator")
    return
   if not first:
    if not buf.startswith(","):raise ValueError("missing event separator")
    buf=buf[1:].lstrip()
    while not buf:
     chunk=f.read(65536)
     if not chunk:raise ValueError("truncated trace")
     buf+=chunk
     buf=buf.lstrip()
   while True:
    try:event,end=decoder.raw_decode(buf);break
    except json.JSONDecodeError:
     chunk=f.read(65536)
     if not chunk:raise
     buf+=chunk
   yield event
   buf=buf[end:]
   first=False
def summarize(path):
 digest=hashlib.sha256();phases=collections.Counter();names=[];end=0
 for x in events(path):
  digest.update(json.dumps(x,sort_keys=True,separators=(",",":"),ensure_ascii=False).encode());digest.update(b"\n")
  phases[x["ph"]]+=1
  if x.get("ph")=="X":
   assert x["ts"]>=0 and x["dur"]>=0;end=max(end,x["ts"]+x["dur"])
  if x.get("name")=="process_name":names.append(x["args"]["name"])
 return {"events":sum(phases.values()),"phases":dict(phases),"event_digest":digest.hexdigest(),"max_slice_end_cycle":end,"processes":names,"bytes":pathlib.Path(path).stat().st_size}
if __name__=="__main__":
 old,new=map(pathlib.Path,sys.argv[1:3])
 a,b=summarize(old),summarize(new)
 assert a["event_digest"]==b["event_digest"],"trace event contents differ"
 out={"old":a,"new":b,"event_content_identical":True}
 print(json.dumps(out))
 new.with_name("semantic-comparison.json").write_text(json.dumps(out,indent=2))
