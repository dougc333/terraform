#!/usr/bin/env python3
import argparse, concurrent.futures, json, random, signal, threading, time
from urllib.parse import quote
import requests

STOP = threading.Event()

def stop_handler(*_): STOP.set()

def fetch_mbpp(limit):
    url = "https://datasets-server.huggingface.co/rows?dataset=" + quote("google-research-datasets/mbpp", safe="") + f"&config=full&split=test&offset=0&length={limit}"
    r = requests.get(url, timeout=60); r.raise_for_status()
    tasks = []
    for item in r.json()["rows"]:
        row = item["row"]
        prompt = row.get("text") or row.get("prompt")
        if prompt:
            tasks.append({"prompt": prompt, "tests": row.get("test_list") or [], "task_id": row.get("task_id", item.get("row_idx"))})
    if not tasks: raise RuntimeError("No MBPP tasks returned")
    return tasks

def make_prompt(task):
    tests = "\n".join(task["tests"][:3])
    return f"Write a correct Python solution for this MBPP coding task. Return only Python code, without Markdown fences.\n\nTask:\n{task['prompt']}\n\nExample tests:\n{tests}\n"

def one_request(session, args, task):
    payload = {"model": args.model, "messages": [{"role":"system","content":"You are a concise Python coding assistant."},{"role":"user","content":make_prompt(task)}], "temperature":0.2, "max_tokens":args.max_tokens, "stream":False}
    started = time.perf_counter()
    try:
        r = session.post(args.url.rstrip("/") + "/v1/chat/completions", json=payload, timeout=args.timeout)
        elapsed = time.perf_counter() - started; r.raise_for_status()
        text = r.json()["choices"][0]["message"]["content"]
        return True, elapsed, len(text), task["task_id"], None
    except Exception as exc:
        return False, time.perf_counter() - started, 0, task["task_id"], str(exc)

def worker(i, args, tasks, counters, lock):
    session = requests.Session()
    while not STOP.is_set():
        ok, latency, chars, task_id, error = one_request(session, args, random.choice(tasks))
        with lock:
            counters["requests"] += 1; counters["latency"] += latency
            if ok: counters["ok"] += 1; counters["chars"] += chars
            else: counters["errors"] += 1
        if args.verbose: print(f"worker={i} task={task_id} {'OK' if ok else 'ERROR'} latency={latency:.2f}s chars={chars} {error or ''}", flush=True)
        if args.delay: STOP.wait(args.delay)

def reporter(counters, lock, started):
    previous_requests, previous_time = 0, started
    while not STOP.wait(5):
        now = time.time()
        with lock: snap = dict(counters)
        interval_requests = snap["requests"] - previous_requests
        mean = snap["latency"] / max(snap["requests"], 1)
        print(f"elapsed={now-started:.0f}s total={snap['requests']} ok={snap['ok']} errors={snap['errors']} recent_rps={interval_requests/max(now-previous_time,0.001):.2f} mean_latency={mean:.2f}s", flush=True)
        previous_requests, previous_time = snap["requests"], now

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--url", default="http://127.0.0.1:8080")
    p.add_argument("--model", default="qwen2.5-0.5b-instruct")
    p.add_argument("--workers", type=int, default=12)
    p.add_argument("--duration", type=int, default=600)
    p.add_argument("--tasks", type=int, default=100)
    p.add_argument("--max-tokens", type=int, default=192)
    p.add_argument("--timeout", type=int, default=180)
    p.add_argument("--delay", type=float, default=0.0)
    p.add_argument("--verbose", action="store_true")
    args = p.parse_args()
    signal.signal(signal.SIGINT, stop_handler); signal.signal(signal.SIGTERM, stop_handler)
    print(f"Downloading {args.tasks} MBPP tasks...", flush=True)
    tasks = fetch_mbpp(args.tasks)
    counters = {"requests":0,"ok":0,"errors":0,"latency":0.0,"chars":0}; lock = threading.Lock(); started = time.time()
    threading.Thread(target=reporter, args=(counters,lock,started), daemon=True).start()
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
        futures = [pool.submit(worker, i, args, tasks, counters, lock) for i in range(args.workers)]
        STOP.wait(args.duration); STOP.set()
        for f in futures: f.result()
    with lock: snap = dict(counters)
    snap["duration_seconds"] = round(time.time()-started,2); snap["mean_latency_seconds"] = round(snap["latency"]/max(snap["requests"],1),3)
    print(json.dumps(snap, indent=2))

if __name__ == "__main__": main()
