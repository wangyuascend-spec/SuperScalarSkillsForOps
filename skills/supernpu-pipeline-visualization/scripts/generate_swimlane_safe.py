#!/usr/bin/env python3
"""Generate a SwimLane JSON (and optional PipeView) under a memory cap.

Runs gfsim from the SuperScalarModel root. 4PE ELFs use --conf fourpe.
Random SoC seed defaults to 2. Bandwidth, latency, and credit stay at
configs/core.toml unless --set overrides them.
"""
import argparse
import hashlib
import json
import pathlib
import re
import resource
import subprocess
import sys

INTERVAL_KEY = "dfx.swimCounterSampleInterval"
REJECTED_SETTINGS = {"softcore.multiThreadNum"}


def sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def git_text(model, args):
    try:
        return subprocess.check_output(args, cwd=model, text=True, stderr=subprocess.DEVNULL).strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return "unknown"


def memory_budget(requested_gib):
    meminfo = {}
    for line in pathlib.Path("/proc/meminfo").read_text().splitlines():
        if line.startswith(("MemAvailable:", "SwapFree:")):
            meminfo[line.split(":", 1)[0]] = int(line.split()[1]) * 1024
    available = meminfo["MemAvailable"]
    budget = min(int(requested_gib * 1024**3), int(available * 0.6))
    if budget < 2 * 1024**3:
        raise SystemExit(
            "Insufficient available memory for a SwimLane trace; leave at least 2 GiB for gfsim."
        )
    return budget, available


def fourpe_conf(model, interval):
    source = (model / "configs/fourpe.conf").read_text()
    lines = source.splitlines(keepends=True)
    found = False
    changed = False
    rewritten = []
    for line in lines:
        body = line.split("#", 1)[0].strip()
        if body.startswith(INTERVAL_KEY + "="):
            found = True
            current = body.split("=", 1)[1].strip()
            if current != str(interval):
                changed = True
                newline = "\n" if line.endswith("\n") else ""
                rewritten.append(f"{INTERVAL_KEY}={interval}{newline}")
                continue
        rewritten.append(line)
    if not found:
        changed = True
        if rewritten and not rewritten[-1].endswith("\n"):
            rewritten[-1] += "\n"
        rewritten.append(f"{INTERVAL_KEY}={interval}\n")
    return "".join(rewritten), changed


def parse_log(text):
    cycles = re.search(r"(?m)^Total Cycles\.+:\s+(\d+)\s*$", text)
    tiles = [int(value) for value in re.findall(r"scb_waw_tile=(\d+)", text)]
    violations = len(re.findall(r"scb_waw_violation", text))
    return {
        "report_stop": "SuperScalar Report Stop" in text,
        "total_cycles": int(cycles.group(1)) if cycles else None,
        "scb_waw_tile": sum(tiles),
        "scb_waw_violation_mentions": violations,
        "explicit_pe_config": "explicit PE config present" in text,
        "thread_count_4": "core.threadCount=4" in text,
        "pe_cluster_enable": "fourpe.pe_cluster_enable=true" in text,
        "pe_cluster_count_4": "fourpe.pe_cluster_count=4" in text,
        "soc_random": "core.soc_random=true" in text,
        "soc_seed_line": "core.soc_lat_random_seed=" in text,
    }


def peak_rss_kb(time_log):
    if not time_log.is_file():
        return None
    match = re.search(r"Maximum resident set size \(kbytes\):\s+(\d+)", time_log.read_text(errors="replace"))
    return int(match.group(1)) if match else None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model", required=True, type=pathlib.Path)
    parser.add_argument("--elf", required=True, type=pathlib.Path)
    parser.add_argument("--output-dir", required=True, type=pathlib.Path)
    parser.add_argument("--counter-interval", type=int, default=8)
    parser.add_argument("--memory-gib", type=float, default=6.0)
    parser.add_argument("--timeout", type=int, default=900)
    parser.add_argument("--fake-l2", choices=["true", "false"], default="false")
    parser.add_argument("--soc-random", choices=["true", "false"], default="true")
    parser.add_argument("--seed", type=int, default=2)
    parser.add_argument("--pe", choices=["auto", "4", "1"], default="auto")
    parser.add_argument("--pipeview", choices=["off", "block", "full"], default="off")
    parser.add_argument("--pipe-filter-group", action="store_true")
    parser.add_argument("--set", action="append", default=[], metavar="KEY=VALUE")
    args = parser.parse_args()
    if args.counter_interval < 1 or args.memory_gib <= 0 or args.timeout < 1:
        parser.error("limits must be positive")

    model = args.model.resolve()
    elf = args.elf.resolve()
    out = args.output_dir.resolve()
    gfsim = model / "bin/gfsim"
    if not elf.is_file():
        raise SystemExit(f"ELF not found: {elf}")
    if not gfsim.is_file():
        raise SystemExit(f"gfsim not found: {gfsim}")
    if not (model / "configs/fourpe.conf").is_file():
        raise SystemExit(f"fourpe profile not found under {model}/configs")

    pe = args.pe
    if pe == "auto":
        pe = "4" if elf.name.endswith("_PE4.elf") else "1"

    settings = {
        "tlsu.fake_l2_enable": args.fake_l2,
        "core.soc_random": args.soc_random,
        "core.soc_lat_random_seed": str(args.seed),
    }
    for item in args.set:
        if "=" not in item:
            parser.error(f"--set expects key=value, got {item}")
        key, value = item.split("=", 1)
        if key in REJECTED_SETTINGS:
            parser.error(f"{key} does not select gfsim PE mode; pass --pe 4")
        if key == INTERVAL_KEY:
            parser.error("set the counter interval with --counter-interval")
        settings[key] = value

    budget, available = memory_budget(args.memory_gib)
    out.mkdir(parents=True, exist_ok=False)

    conf_args = []
    interval_source = "dfx-toml-override"
    if pe == "4":
        text, changed = fourpe_conf(model, args.counter_interval)
        if changed:
            custom = out / "fourpe-trace.conf"
            custom.write_text(text)
            conf_args = ["--conf", str(custom)]
            interval_source = "copied-fourpe-conf"
        else:
            conf_args = ["--conf", "fourpe"]
            interval_source = "fourpe.conf"
        conf_args += ["--pto-v02", "true"]
    else:
        settings[INTERVAL_KEY] = str(args.counter_interval)

    swim = out / "pipeline.json"
    command = ["timeout", "-k", "10s", f"{args.timeout}s", str(gfsim), "-f", str(elf)]
    command += conf_args
    for key, value in settings.items():
        command += ["-s", f"{key}={value}"]
    command += ["--swimlane", "1", "--swimfile", str(swim)]
    pipe_base = out / f"{elf.stem}.pipeview.log"
    if args.pipeview != "off" or args.pipe_filter_group:
        mode = "1" if args.pipeview == "full" else "2"
        command += ["-p", mode, "--pipefile", str(pipe_base)]
        if args.pipe_filter_group:
            command.append("--pipe_filter_group")

    def cap():
        resource.setrlimit(resource.RLIMIT_AS, (budget, budget))
        resource.setrlimit(resource.RLIMIT_CORE, (0, 0))

    metadata = {
        "command": command,
        "pe": pe,
        "fake_l2": args.fake_l2,
        "soc_random": settings["core.soc_random"],
        "soc_seed": settings["core.soc_lat_random_seed"],
        "counter_interval": args.counter_interval,
        "counter_interval_source": interval_source,
        "memory_limit_bytes": budget,
        "mem_available_bytes": available,
        "model_sha": git_text(model, ["git", "rev-parse", "HEAD"]),
        "model_diff_sha256": hashlib.sha256(git_text(model, ["git", "diff"]).encode()).hexdigest(),
        "gfsim_sha256": sha256(gfsim),
        "elf_sha256": sha256(elf),
        "overrides": settings,
    }
    manifest = out / "manifest.json"
    manifest.write_text(json.dumps(metadata, indent=2) + "\n")

    log_path = out / "gfsim.log"
    time_path = out / "gfsim.time"
    timed = ["/usr/bin/time", "-v", "-o", str(time_path)] + command
    launcher = timed if pathlib.Path("/usr/bin/time").is_file() else command
    with log_path.open("w") as log:
        completed = subprocess.run(launcher, cwd=model, stdout=log, stderr=subprocess.STDOUT, preexec_fn=cap)
    rc = completed.returncode
    log_text = log_path.read_text(errors="replace")
    parsed = parse_log(log_text)
    pipe_out = pathlib.Path(str(pipe_base) + ".out")

    dump_aborted = parsed["report_stop"] and parsed["total_cycles"] is not None and (not swim.is_file() or swim.stat().st_size == 0)
    if rc == 124:
        status = "TIMEOUT"
    elif dump_aborted and rc != 0:
        status = "DUMP_FAIL"
    elif rc != 0:
        status = "MODEL_FAIL"
    elif not parsed["report_stop"] or parsed["total_cycles"] is None:
        status = "MODEL_FAIL"
    elif settings["core.soc_random"] == "true" and not parsed["soc_random"]:
        status = "CONFIG_FAIL"
    elif f"core.soc_lat_random_seed={settings['core.soc_lat_random_seed']}" not in log_text:
        status = "CONFIG_FAIL"
    elif pe == "4" and not (
        parsed["explicit_pe_config"]
        and parsed["thread_count_4"]
        and parsed["pe_cluster_enable"]
        and parsed["pe_cluster_count_4"]
    ):
        status = "CONFIG_FAIL"
    elif not swim.is_file() or swim.stat().st_size == 0:
        status = "MODEL_FAIL"
    else:
        status = "PASS"

    metadata.update(parsed)
    metadata["exit_code"] = rc
    metadata["status"] = status
    metadata["peak_rss_kb"] = peak_rss_kb(time_path)
    metadata["swimlane"] = str(swim) if swim.is_file() else None
    metadata["swimlane_bytes"] = swim.stat().st_size if swim.is_file() else 0
    metadata["pipeview"] = str(pipe_out) if pipe_out.is_file() else None
    manifest.write_text(json.dumps(metadata, indent=2) + "\n")

    print(f"status: {status}")
    print(f"exit_code: {rc}")
    print(f"Total Cycles: {parsed['total_cycles']}")
    print(f"scb_waw_tile: {parsed['scb_waw_tile']}")
    if parsed["scb_waw_tile"]:
        print("scb_waw_tile is nonzero; report it with the result")
    print(f"SwimLane: {metadata['swimlane']} ({metadata['swimlane_bytes']} bytes)")
    if metadata["pipeview"]:
        print(f"PipeView: {metadata['pipeview']}")
    print(f"Log: {log_path}")
    if status == "PASS":
        preview = pathlib.Path(__file__).with_name("render_swimlane_preview.py")
        preview_rc = subprocess.run([sys.executable, str(preview), str(swim), "--output-dir", str(out)]).returncode
        metadata["preview_exit_code"] = preview_rc
        manifest.write_text(json.dumps(metadata, indent=2) + "\n")
        if preview_rc != 0:
            print(f"preview failed with exit {preview_rc}")
    print(json.dumps(metadata))
    if status != "PASS":
        raise SystemExit(rc or 1)


if __name__ == "__main__":
    main()
