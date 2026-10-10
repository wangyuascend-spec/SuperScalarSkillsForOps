#!/usr/bin/env python3
"""Render a PE-union SwimLane preview from pipeline.json.

Vector lanes come from VECTOR_0..3 (pids 70000, 70036, 70072, 70108).
TLOAD and TSTORE lanes come from TLSU thread names *_PE0N_LOAD_* and
*_PE0N_STORE_*. Overlapping slices on one PE are merged. The HTML is the
view to show; the PNGs are the same pixels without labels.
"""
import argparse
import json
import pathlib
import struct
import zlib

VECTOR_PIDS = {70000: 0, 70036: 1, 70072: 2, 70108: 3}
COLORS = {"Vector": (76, 141, 255), "TLOAD": (61, 186, 122), "TSTORE": (240, 162, 2)}
KINDS = ("Vector", "TLOAD", "TSTORE")


def events(path):
    decoder = json.JSONDecoder()
    with pathlib.Path(path).open() as handle:
        buf = ""
        while True:
            chunk = handle.read(1 << 20)
            if not chunk:
                raise ValueError("missing traceEvents array")
            buf += chunk
            start = buf.find("[")
            if start >= 0 and '"traceEvents"' in buf[:start]:
                buf = buf[start + 1 :]
                break
        first = True
        while True:
            buf = buf.lstrip()
            while not buf:
                chunk = handle.read(1 << 20)
                if not chunk:
                    raise ValueError("truncated trace")
                buf += chunk
                buf = buf.lstrip()
            if buf.startswith("]"):
                return
            if not first:
                if not buf.startswith(","):
                    raise ValueError("missing event separator")
                buf = buf[1:].lstrip()
                while not buf:
                    chunk = handle.read(1 << 20)
                    if not chunk:
                        raise ValueError("truncated trace")
                    buf += chunk
                buf = buf.lstrip()
            while True:
                try:
                    event, end = decoder.raw_decode(buf)
                    break
                except json.JSONDecodeError:
                    chunk = handle.read(1 << 20)
                    if not chunk:
                        raise
                    buf += chunk
            yield event
            buf = buf[end:]
            first = False


def lane_of(event, threads):
    pid = event.get("pid")
    if pid in VECTOR_PIDS:
        return ("Vector", VECTOR_PIDS[pid])
    name = threads.get((pid, event.get("tid")), "")
    marker = "_PE"
    if marker not in name:
        return None
    pe = int(name.split(marker, 1)[1][:2])
    if "LOAD" in name:
        return ("TLOAD", pe)
    if "STORE" in name:
        return ("TSTORE", pe)
    return None


def merge(intervals):
    if not intervals:
        return []
    intervals.sort()
    start, end = intervals[0]
    merged = []
    for left, right in intervals[1:]:
        if left <= end:
            end = max(end, right)
        else:
            merged.append((start, end))
            start, end = left, right
    merged.append((start, end))
    return merged


def collect(path):
    threads = {}
    raw = {(kind, pe): [] for kind in KINDS for pe in range(4)}
    for event in events(path):
        phase = event.get("ph")
        if phase == "M" and event.get("name") == "thread_name":
            threads[(event["pid"], event["tid"])] = event["args"]["name"]
            continue
        if phase != "X":
            continue
        key = lane_of(event, threads)
        if key is None or key not in raw:
            continue
        start = event["ts"]
        end = start + event["dur"]
        if end > start:
            raw[key].append((start, end))
    lanes = {key: merge(value) for key, value in raw.items()}
    last = max((item[1] for value in lanes.values() for item in value), default=0)
    return lanes, last


def busy(intervals):
    return sum(end - start for start, end in intervals)


def write_png(path, width, height, rgb):
    raw = b"".join(b"\x00" + bytes(rgb[y * width * 3 : (y + 1) * width * 3]) for y in range(height))

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 6))
    png += chunk(b"IEND", b"")
    path.write_bytes(png)


def paint(lanes, rows, x0, x1, width, path):
    pad, row_h = 36, 22
    height = pad + len(rows) * row_h + 8
    rgb = bytearray([24, 24, 28]) * (width * height)
    span = max(1, x1 - x0)
    for row, (kind, pe) in enumerate(rows):
        marks = [0] * width
        for start, end in lanes[(kind, pe)]:
            if end <= x0 or start >= x1:
                continue
            left = max(start, x0)
            right = min(end, x1)
            i0 = max(0, min(width - 1, int((left - x0) / span * width)))
            i1 = int((right - x0) / span * width)
            i1 = max(i0 + 1, min(width, i1))
            for index in range(i0, i1):
                marks[index] = 1
        color = bytes(COLORS[kind])
        y0 = pad + row * row_h
        for x, on in enumerate(marks):
            if not on:
                continue
            for y in range(y0 + 3, y0 + row_h - 3):
                offset = (y * width + x) * 3
                rgb[offset : offset + 3] = color
    for tick in range(11):
        x = min(width - 1, int(tick / 10 * (width - 1)))
        for y in range(8, 28):
            offset = (y * width + x) * 3
            rgb[offset : offset + 3] = b"\xaa\xaa\xaa"
    write_png(path, width, height, rgb)


def html_rows(lanes, rows, x0, x1, width):
    span = max(1, x1 - x0)
    parts = []
    for kind, pe in rows:
        segs = []
        for start, end in lanes[(kind, pe)]:
            if end <= x0 or start >= x1:
                continue
            left = max(start, x0)
            right = min(end, x1)
            segs.append(
                f'<div class="seg {kind}" style="left:{(left - x0) / span * width:.2f}px;'
                f'width:{max(1, (right - left) / span * width):.2f}px"></div>'
            )
        parts.append(
            f'<div class="row"><div class="lab">{kind} PE{pe}</div>'
            f'<div class="track">{"".join(segs)}</div></div>'
        )
    return "\n".join(parts)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("trace", type=pathlib.Path)
    parser.add_argument("--output-dir", type=pathlib.Path)
    parser.add_argument("--title", default="SwimLane preview")
    parser.add_argument("--zoom-start", type=int)
    parser.add_argument("--zoom-len", type=int, default=3000)
    args = parser.parse_args()
    trace = args.trace.resolve()
    out = (args.output_dir or trace.parent).resolve()
    out.mkdir(parents=True, exist_ok=True)
    lanes, last = collect(trace)
    rows = [(kind, pe) for kind in KINDS for pe in range(4)]
    zoom_len = min(args.zoom_len, last) if last else args.zoom_len
    zoom_start = args.zoom_start if args.zoom_start is not None else max(0, last // 3)
    zoom_end = min(last, zoom_start + zoom_len) if last else zoom_start + zoom_len
    paint(lanes, rows, 0, max(last, 1), 1100, out / "overview.png")
    paint(lanes, rows, zoom_start, max(zoom_end, zoom_start + 1), 1100, out / "row_zoom.png")
    summary = {
        "trace": str(trace),
        "last_cycle": last,
        "zoom": [zoom_start, zoom_end],
        "lanes": {
            f"{kind} PE{pe}": {
                "slices": len(lanes[(kind, pe)]),
                "busy_cycles": busy(lanes[(kind, pe)]),
            }
            for kind, pe in rows
        },
    }
    (out / "preview_summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    page = f"""<!doctype html><meta charset="utf-8"><title>{args.title}</title>
<style>
body{{background:#141418;color:#ddd;font:13px/1.3 ui-sans-serif,sans-serif;margin:16px}}
h1{{font-size:16px;font-weight:600}} h2{{font-size:14px;font-weight:600}}
.panel{{margin:18px 0 28px}}
.row{{display:flex;align-items:center;height:28px}}
.lab{{width:110px;color:#bbb}}
.track{{position:relative;height:16px;width:1100px;background:#2a2a32;border-radius:2px}}
.seg{{position:absolute;top:0;height:16px;border-radius:1px}}
.Vector{{background:#4c8dff}} .TLOAD{{background:#3dba7a}} .TSTORE{{background:#f0a202}}
.note{{color:#999}}
</style>
<h1>{args.title}</h1>
<p class="note">Blue Vector, green TLOAD, orange TSTORE. Each row is the union of that PE's lanes. Last slice ends at cycle {last}.</p>
<div class="panel"><h2>Full run</h2>{html_rows(lanes, rows, 0, max(last, 1), 1100)}</div>
<div class="panel"><h2>Cycles {zoom_start}–{zoom_end}</h2>{html_rows(lanes, rows, zoom_start, max(zoom_end, zoom_start + 1), 1100)}</div>
"""
    html_path = out / "preview.html"
    html_path.write_text(page)
    print(f"preview: {html_path}")
    print(f"overview: {out / 'overview.png'}")
    print(f"zoom: {out / 'row_zoom.png'} cycles {zoom_start}-{zoom_end}")
    for kind in KINDS:
        for pe in range(4):
            item = summary["lanes"][f"{kind} PE{pe}"]
            print(f"{kind} PE{pe}: slices={item['slices']} busy={item['busy_cycles']}")


if __name__ == "__main__":
    main()
