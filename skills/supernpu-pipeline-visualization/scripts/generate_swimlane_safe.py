#!/usr/bin/env python3
"""Generate a full SwimLane trace with a per-process memory cap."""
import argparse,json,pathlib,resource,subprocess,hashlib,re
p=argparse.ArgumentParser()
p.add_argument("--model",required=True,type=pathlib.Path)
p.add_argument("--elf",required=True,type=pathlib.Path)
p.add_argument("--output-dir",required=True,type=pathlib.Path)
p.add_argument("--counter-interval",type=int,default=128)
p.add_argument("--memory-gib",type=float,default=3.0)
p.add_argument("--timeout",type=int,default=900)
p.add_argument("--fake-l2",choices=["true","false"],default="false")
p.add_argument("--soc-random",choices=["true","false"],default="true")
p.add_argument("--seed",type=int,default=2)
a=p.parse_args()
if a.counter_interval<1 or a.memory_gib<=0 or a.timeout<1:p.error("limits must be positive")
model=a.model.resolve();elf=a.elf.resolve();out=a.output_dir.resolve()
mem=dict((line.split(":")[0],int(line.split()[1])*1024) for line in pathlib.Path("/proc/meminfo").read_text().splitlines() if line.startswith(("MemAvailable:","SwapFree:")))
budget=min(int(a.memory_gib*1024**3),int(mem["MemAvailable"]*0.6))
if budget<2*1024**3:raise SystemExit("Insufficient available memory for full trace; leave at least 2 GiB for gfsim.")
out.mkdir(parents=True,exist_ok=False)
configs=out/"configs";configs.mkdir()
profile=(model/"configs/fourpe.conf").read_text()
profile=re.sub(r"(?m)^dfx.swimCounterSampleInterval=.*$",f"dfx.swimCounterSampleInterval={a.counter_interval}",profile)
conf=configs/"fourpe-memory-safe.conf";conf.write_text(profile)
args=["timeout","-k","10s",str(a.timeout)+"s",str(model/"bin/gfsim"),"-f",str(elf),"--conf",str(conf),"--pto-v02","true","-s","tlsu.fake_l2_enable="+a.fake_l2,"-s","core.soc_random="+a.soc_random,"-s","core.soc_lat_random_seed="+str(a.seed),"--swimlane","1","--swimfile",str(out/"pipeline.json")]
def cap():
 resource.setrlimit(resource.RLIMIT_AS,(budget,budget))
 resource.setrlimit(resource.RLIMIT_CORE,(0,0))
sha=lambda x:hashlib.sha256(pathlib.Path(x).read_bytes()).hexdigest()
metadata={"command":args,"memory_limit_bytes":budget,"counter_interval":a.counter_interval,"model_sha":subprocess.check_output(["git","rev-parse","HEAD"],cwd=model,text=True).strip(),"gfsim_sha256":sha(model/"bin/gfsim"),"elf_sha256":sha(elf)}
metadata["model_diff_sha256"]=hashlib.sha256(subprocess.check_output(["git","diff"],cwd=model)).hexdigest()
(out/"manifest.json").write_text(json.dumps(metadata,indent=2))
with (out/"gfsim.log").open("w") as log:
 rc=subprocess.run(["/usr/bin/time","-v","-o",str(out/"gfsim.time")]+args,cwd=model,stdout=log,stderr=subprocess.STDOUT,preexec_fn=cap).returncode
metadata["exit_code"]=rc
(out/"manifest.json").write_text(json.dumps(metadata,indent=2))
print(json.dumps(metadata))
raise SystemExit(rc)
