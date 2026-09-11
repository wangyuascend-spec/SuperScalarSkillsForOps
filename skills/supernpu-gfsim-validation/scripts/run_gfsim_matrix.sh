#!/usr/bin/env bash
set -uo pipefail

usage() {
  cat <<'EOF'
Usage:
  run_gfsim_matrix.sh --model-dir DIR --elf FILE --case NAME --out-dir DIR [options]

Options:
  --mode real|fake|both   L2 modes to run (default: real)
  --timeout SECONDS      Per-run timeout (default: 900)
  --repeat N             Repeat each L2 mode N times (default: 1)
  --pto-v02 true|false   Value passed to --pto-v02 (default: true)
  --dry-run              Print commands without running gfsim
  -h, --help             Show this help
EOF
}

model_dir=""
elf=""
case_name=""
out_dir=""
mode="real"
timeout_s="900"
repeat="1"
pto_v02="true"
dry_run="false"

while (($#)); do
  case "$1" in
    --model-dir) model_dir=${2:-}; shift 2 ;;
    --elf) elf=${2:-}; shift 2 ;;
    --case) case_name=${2:-}; shift 2 ;;
    --out-dir) out_dir=${2:-}; shift 2 ;;
    --mode) mode=${2:-}; shift 2 ;;
    --timeout) timeout_s=${2:-}; shift 2 ;;
    --repeat) repeat=${2:-}; shift 2 ;;
    --pto-v02) pto_v02=${2:-}; shift 2 ;;
    --dry-run) dry_run="true"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ -z "$model_dir" || -z "$elf" || -z "$case_name" || -z "$out_dir" ]]; then
  printf 'Missing required argument.\n' >&2
  usage >&2
  exit 2
fi
if [[ "$mode" != "real" && "$mode" != "fake" && "$mode" != "both" ]]; then
  printf 'Invalid --mode: %s\n' "$mode" >&2
  exit 2
fi
if ! [[ "$timeout_s" =~ ^[1-9][0-9]*$ && "$repeat" =~ ^[1-9][0-9]*$ ]]; then
  printf '%s\n' '--timeout and --repeat must be positive integers.' >&2
  exit 2
fi
if [[ "$pto_v02" != "true" && "$pto_v02" != "false" ]]; then
  printf 'Invalid --pto-v02: %s\n' "$pto_v02" >&2
  exit 2
fi
if [[ ! -d "$model_dir" ]]; then
  printf 'Model directory does not exist: %s\n' "$model_dir" >&2
  exit 2
fi
if [[ ! -f "$elf" ]]; then
  printf 'ELF does not exist: %s\n' "$elf" >&2
  exit 2
fi

model_dir=$(realpath "$model_dir")
elf=$(realpath "$elf")
out_dir=$(realpath -m "$out_dir")
gfsim="$model_dir/bin/gfsim"
safe_case=${case_name//[^A-Za-z0-9_.-]/_}

if [[ ! -x "$gfsim" ]]; then
  printf 'gfsim is not executable: %s\n' "$gfsim" >&2
  exit 2
fi
if [[ ! -f "$model_dir/configs/fourpe.conf" ]]; then
  printf 'Config does not exist: %s\n' "$model_dir/configs/fourpe.conf" >&2
  exit 2
fi

mkdir -p "$out_dir"
summary="$out_dir/summary.tsv"
manifest="$out_dir/manifest.txt"
printf 'case\tl2_mode\trun\texit_code\ttotal_cycles\tstatus\tlog\n' > "$summary"
{
  printf 'generated_at=%s\n' "$(date -Iseconds)"
  printf 'host=%s\n' "$(uname -a)"
  printf 'model_dir=%s\n' "$model_dir"
  printf 'model_commit=%s\n' "$(git -C "$model_dir" rev-parse HEAD 2>/dev/null || printf UNKNOWN)"
  printf 'gfsim_md5=%s\n' "$(md5sum "$gfsim" | awk '{print $1}')"
  printf 'elf=%s\n' "$elf"
  printf 'elf_sha256=%s\n' "$(sha256sum "$elf" | awk '{print $1}')"
  printf 'pe_config=fourpe\n'
  printf 'pto_v02=%s\n' "$pto_v02"
  printf 'timeout_seconds=%s\n' "$timeout_s"
  printf 'repeat=%s\n' "$repeat"
} > "$manifest"

if [[ "$mode" == "both" ]]; then
  modes=(real fake)
else
  modes=("$mode")
fi

overall_rc=0
for l2_mode in "${modes[@]}"; do
  if [[ "$l2_mode" == "fake" ]]; then
    fake_l2="true"
  else
    fake_l2="false"
  fi

  for ((run=1; run<=repeat; run++)); do
    stem="${safe_case}-${l2_mode}-l2-run${run}"
    log="$out_dir/$stem.log"
    exit_file="$out_dir/$stem.exit"
    cmd=(timeout "$timeout_s" "$gfsim" -f "$elf" --conf fourpe --pto-v02 "$pto_v02" -s "tlsu.fake_l2_enable=$fake_l2")

    printf '%s command: ' "$stem"
    printf '%q ' "${cmd[@]}"
    printf '\n'

    if [[ "$dry_run" == "true" ]]; then
      continue
    fi

    (
      cd "$model_dir" || exit 2
      if [[ -x /usr/bin/time ]]; then
        /usr/bin/time -v "${cmd[@]}"
      else
        "${cmd[@]}"
      fi
    ) > "$log" 2>&1
    rc=$?
    printf '%s\n' "$rc" > "$exit_file"

    total_cycles=$(awk '/^Total Cycles/{print $NF; exit}' "$log")
    report_stop=false
    explicit_pe=false
    thread_count=false
    cluster_count=false
    cluster_enable=false
    frontend_threads=false
    effective_l2=false
    deadlock=false
    fatal=false
    grep -q 'SuperScalar Report Stop' "$log" && report_stop=true
    grep -q 'explicit PE config present; skipping ELF auto-detection' "$log" && explicit_pe=true
    grep -q 'core.threadCount=4' "$log" && thread_count=true
    grep -q 'fourpe.pe_cluster_count=4' "$log" && cluster_count=true
    grep -q 'fourpe.pe_cluster_enable=true' "$log" && cluster_enable=true
    grep -q 'fourpe.pe_cluster_frontend_thread_count=4' "$log" && frontend_threads=true
    grep -q "tlsu.fake_l2_enable=$fake_l2" "$log" && effective_l2=true
    grep -qi 'Deadlock detected' "$log" && deadlock=true
    grep -Eq 'FATAL:|ASSERTION FAILED:|received signal' "$log" && fatal=true

    if [[ $rc -eq 0 && "$report_stop" == "true" && "$explicit_pe" == "true" && "$thread_count" == "true" && "$cluster_count" == "true" && "$cluster_enable" == "true" && "$frontend_threads" == "true" && "$effective_l2" == "true" && -n "$total_cycles" && "$deadlock" == "false" && "$fatal" == "false" ]]; then
      status="PASS"
    elif [[ "$deadlock" == "true" ]]; then
      status="DEADLOCK"
      overall_rc=1
    elif [[ $rc -eq 124 ]]; then
      status="TIMEOUT"
      overall_rc=1
    elif [[ "$explicit_pe" != "true" || "$thread_count" != "true" || "$cluster_count" != "true" || "$cluster_enable" != "true" || "$frontend_threads" != "true" || "$effective_l2" != "true" ]]; then
      status="CONFIG_FAIL"
      overall_rc=1
    else
      status="MODEL_FAIL"
      overall_rc=1
    fi

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$case_name" "$l2_mode" "$run" "$rc" "${total_cycles:-NA}" "$status" "$log" >> "$summary"
    printf '%s status=%s exit=%s total_cycles=%s\n' "$stem" "$status" "$rc" "${total_cycles:-NA}"
  done
done

printf 'Manifest: %s\n' "$manifest"
printf 'Summary: %s\n' "$summary"
exit "$overall_rc"
