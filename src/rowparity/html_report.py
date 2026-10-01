"""Findings-first HTML pages, rendered from published records.

* ``render_test(record)``: one test's run, from its result.json. Written next
  to it as ``report.html`` and by ``rowparity show --html``.
* ``render_run(summary)``: a whole run, from summarize's summary. Written as
  ``_runs/<run_date>_<run_id>/index.html``, linking to each test's page.
* ``render_compare(runs, title)``: totals of several runs side by side, from
  ``rowparity compare-runs``. Written as ``_compare/<name>.html``.

All are single self-contained files (inline CSS, one line of JS for copy
buttons) and follow the console's order: verdict, size, ranked findings, then
the detail most readers never open. Rendering is plain Python so a page can be
rebuilt from result.json alone, years after the ComparisonResult is gone.
"""
from __future__ import annotations

from html import escape
from typing import Any, Dict, Optional

from .findings import _ratio

STATUS_CLASS = {
    "EQUIVALENT": "eq",
    "WITHIN_TOLERANCE": "tol",
    "DIFFERENT": "diff",
    "ERROR": "err",
    "NO RESULT": "err",
}

CSS = """
:root{--ground:#F5F7FA;--panel:#FFFFFF;--sunk:#EAEEF3;--ink:#131A23;--muted:#586476;--rule:#D8DEE7;
--accent:#1D5FB0;--accent-soft:#DCE8F7;--code:#0F1620;--code-ink:#D7DEE8;
--eq:#1E7A4C;--eq-soft:#DDF0E5;--tol:#9A6400;--tol-soft:#F6E9CF;--diff:#B0281F;--diff-soft:#F7DEDC;
--err:#6A5A96;--err-soft:#E7E2F2;
--sans:"Source Sans 3","Segoe UI","Helvetica Neue",Arial,sans-serif;
--display:"Barlow Semi Condensed","Arial Narrow","Helvetica Neue",Arial,sans-serif;
--mono:"JetBrains Mono",SFMono-Regular,Menlo,Consolas,monospace}
@media (prefers-color-scheme:dark){:root:not([data-theme="light"]){--ground:#0E131A;--panel:#161D27;
--sunk:#1B2330;--ink:#E4E9F0;--muted:#9AA6B6;--rule:#2A3441;--accent:#7EB0EE;--accent-soft:#1B2D45;
--code:#080C12;--eq:#5CC693;--eq-soft:#173326;--tol:#E2B04F;--tol-soft:#3A2D12;--diff:#F07A70;
--diff-soft:#3D1C1A;--err:#B7A6E6;--err-soft:#2A2440}}
:root[data-theme="dark"]{--ground:#0E131A;--panel:#161D27;--sunk:#1B2330;--ink:#E4E9F0;--muted:#9AA6B6;
--rule:#2A3441;--accent:#7EB0EE;--accent-soft:#1B2D45;--code:#080C12;--eq:#5CC693;--eq-soft:#173326;
--tol:#E2B04F;--tol-soft:#3A2D12;--diff:#F07A70;--diff-soft:#3D1C1A;--err:#B7A6E6;--err-soft:#2A2440}
*{box-sizing:border-box}
body{margin:0;background:var(--ground);color:var(--ink);font:16px/1.55 var(--sans)}
main{max-width:1080px;margin:0 auto;padding:36px 28px 80px}
a{color:var(--accent)}
h1,h2{font-family:var(--display);line-height:1.15;margin:0;text-wrap:balance}
h1{font-size:40px;font-weight:700;word-break:break-word}
h2{font-size:24px;font-weight:600;margin:40px 0 12px}
code,.mono{font-family:var(--mono);font-size:.88em}
.eyebrow{font-family:var(--mono);font-size:12.5px;color:var(--muted)}
.band{border-left:6px solid var(--c);background:var(--panel);border-radius:0 6px 6px 0;padding:20px 24px;
margin:18px 0 8px;display:grid;gap:8px}
.band .verdict{font-family:var(--mono);font-weight:600;font-size:15px;color:var(--c);letter-spacing:.03em}
.band .size{font-size:18px}
.eq{--c:var(--eq);--s:var(--eq-soft)}.tol{--c:var(--tol);--s:var(--tol-soft)}
.diff{--c:var(--diff);--s:var(--diff-soft)}.err{--c:var(--err);--s:var(--err-soft)}
.pill{display:inline-block;font-family:var(--mono);font-size:11.5px;font-weight:600;padding:2px 8px;
border-radius:4px;color:var(--c);background:var(--s);white-space:nowrap}
.query{display:flex;gap:8px;align-items:stretch;margin-top:4px}
.query pre{flex:1;margin:0}
pre{background:var(--code);color:var(--code-ink);font:12.5px/1.6 var(--mono);padding:10px 14px;
border-radius:5px;overflow-x:auto;white-space:pre}
button.copy{font:600 12px var(--sans);border:1px solid var(--rule);background:var(--sunk);color:var(--ink);
border-radius:5px;padding:0 12px;cursor:pointer}
button.copy:focus-visible,summary:focus-visible,a:focus-visible{outline:2px solid var(--accent);outline-offset:2px}
ol.findings{list-style:none;margin:0;padding:0;display:grid;gap:14px}
.finding{background:var(--panel);border:1px solid var(--rule);border-radius:6px;padding:16px 20px;
display:grid;grid-template-columns:34px minmax(0,1fr);gap:4px 14px}
.finding .n{font-family:var(--display);font-weight:700;font-size:24px;color:var(--accent);line-height:1.1}
.finding.blocker{border-color:var(--diff)}
.finding.blocker .n{color:var(--diff)}
.finding h3{margin:0;font-size:18px;font-weight:600;line-height:1.35}
.finding ul{margin:6px 0 0;padding:0;list-style:none;display:grid;gap:3px;color:var(--muted);font-size:15px}
.finding ul li.ex{font-family:var(--mono);font-size:12.5px;color:var(--ink);overflow-wrap:anywhere}
.finding dl{margin:10px 0 0;display:grid;grid-template-columns:max-content minmax(0,1fr);gap:4px 12px;font-size:15px}
.finding dt{font-size:11.5px;letter-spacing:.08em;text-transform:uppercase;color:var(--muted);font-weight:600;padding-top:3px}
.finding dd{margin:0}
.finding details{margin-top:10px}
.finding .rows{grid-column:2}
summary{cursor:pointer;color:var(--accent);font-size:14.5px}
.notes{margin:18px 0 0;padding:14px 18px;background:var(--sunk);border-radius:6px;display:grid;gap:4px;font-size:15px;color:var(--muted)}
.tbl{overflow-x:auto;border:1px solid var(--rule);border-radius:6px;background:var(--panel)}
table{border-collapse:collapse;width:100%;font-size:14.5px}
th,td{text-align:left;padding:8px 12px;border-bottom:1px solid var(--rule);vertical-align:top}
tr:last-child td{border-bottom:0}
th{font-size:11.5px;letter-spacing:.08em;text-transform:uppercase;color:var(--muted);background:var(--sunk);white-space:nowrap}
td.num{font-variant-numeric:tabular-nums;font-family:var(--mono);font-size:13px;white-space:nowrap}
.stats{display:flex;flex-wrap:wrap;gap:10px 28px;margin:16px 0 0}
.counts{margin:18px 2px 0;padding:14px 18px;background:var(--panel);border:1px solid var(--rule);border-radius:6px}
.counts b{font-size:24px}
.arrow{color:var(--muted)}
.d{color:var(--muted);font-size:13px}
details > details{margin:8px 0 0 14px}
details > details > summary{font-family:var(--mono);font-size:13px}
.stats div{display:grid}
.stats b{font-family:var(--display);font-size:30px;font-weight:700;line-height:1;font-variant-numeric:tabular-nums}
.stats span{font-size:12px;letter-spacing:.07em;text-transform:uppercase;color:var(--muted)}
details.more{margin-top:28px;border-top:1px solid var(--rule);padding-top:14px}
.scroll{max-height:440px;overflow:auto}
details[open] > summary{margin-bottom:10px}
details.more > summary{font-family:var(--display);font-size:20px;font-weight:600;color:var(--ink)}
footer{margin-top:48px;color:var(--muted);font-size:13px}
"""

COPY_JS = (
    "document.addEventListener('click',function(e){var b=e.target.closest('button.copy');"
    "if(!b)return;var t=b.parentNode.querySelector('pre').innerText;"
    "if(navigator.clipboard){navigator.clipboard.writeText(t).then(function(){b.textContent='Copied';"
    "setTimeout(function(){b.textContent='Copy'},1500)})}});"
)


def _page(title: str, body: str) -> str:
    return (
        '<!doctype html>\n<html lang="en"><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width,initial-scale=1">'
        f"<title>{escape(title)}</title><style>{CSS}</style></head>"
        f"<body><main>{body}</main><script>{COPY_JS}</script></body></html>\n"
    )


def _status_class(status: Optional[str]) -> str:
    return STATUS_CLASS.get(status or "ERROR", "err")


def _pill(status: Optional[str]) -> str:
    label = (status or "ERROR").replace("_", " ")
    return f'<span class="pill {_status_class(status)}">{escape(label)}</span>'


def _query_block(sql: str) -> str:
    return (
        f'<div class="query"><pre>{escape(sql)}</pre>'
        '<button class="copy" type="button">Copy</button></div>'
    )


def _size_sentence(record: Dict[str, Any]) -> str:
    exp, act = record.get("expected_label", "expected"), record.get("actual_label", "actual")
    diffs = int(record.get("total_differences") or 0)
    parts = (
        f"<b>{escape(exp)}</b> {int(record.get('expected_rows') or 0):,} rows &middot; "
        f"<b>{escape(act)}</b> {int(record.get('actual_rows') or 0):,} rows &middot; "
    )
    if not diffs:
        return parts + "no row differences found"
    limit = record.get("max_diff_ratio") or 0
    verdict = ""
    if limit:
        within = record.get("status") == "WITHIN_TOLERANCE"
        verdict = f", {'within' if within else 'over'} the {_ratio(limit)} limit"
    noun = "row differs" if diffs == 1 else "rows differ"
    return parts + f"<b>{diffs:,}</b> {noun} ({_ratio(record.get('diff_ratio') or 0)}{verdict})"


def _finding(index: int, finding: Dict[str, Any], rows_query: Optional[str]) -> str:
    blocker = finding.get("severity") == "blocker"
    details = []
    for line in finding.get("details") or []:
        stripped = line.strip()
        cls = ' class="ex"' if stripped.startswith(("e.g.", "at ")) else ""
        details.append(f"<li{cls}>{escape(stripped)}</li>")
    dl = []
    if finding.get("likely"):
        dl.append(f"<dt>Likely</dt><dd>{escape(finding['likely'])}</dd>")
    if finding.get("next_step"):
        dl.append(f"<dt>Next</dt><dd>{escape(finding['next_step'])}</dd>")
    rows = ""
    if rows_query and not blocker:
        rows = (
            f"<details><summary>Rows for this finding in Presto</summary>"
            f"{_query_block(f'{rows_query} AND finding_id = {index}')}</details>"
        )
    tag = '<span class="pill diff">BLOCKER</span> ' if blocker else ""
    return (
        f'<li class="finding{" blocker" if blocker else ""}"><div class="n">{index}</div><div>'
        f"<h3>{tag}{escape(finding['title'])}</h3>"
        f"{'<ul>' + ''.join(details) + '</ul>' if details else ''}"
        f"{'<dl>' + ''.join(dl) + '</dl>' if dl else ''}{rows}</div></li>"
    )


TOP_ROWS_SHOWN = 25


def _counts_strip(record: Dict[str, Any]) -> str:
    """Rows on each side and how the differences split, in one line."""
    exp, act = record.get("expected_label", "expected"), record.get("actual_label", "actual")
    moved = sum(f.get("rows", 0) for f in (record.get("findings") or []) if f.get("kind") == "moved")
    parts = [
        (f"{int(record.get('expected_rows') or 0):,}", f"{exp} rows"),
        (f"{int(record.get('actual_rows') or 0):,}", f"{act} rows"),
        (f"{int(record.get('changed') or 0):,}", "changed"),
        (f"{int(record.get('missing') or 0):,}", f"only in {exp}"),
        (f"{int(record.get('added') or 0):,}", f"only in {act}"),
    ]
    if moved:
        parts.append((f"{moved:,}", "moved (counted on both sides above)"))
    return ('<div class="stats counts">'
            + "".join(f"<div><b>{escape(v)}</b><span>{escape(label)}</span></div>" for v, label in parts)
            + "</div>")


def _delta(expected: Any, actual: Any) -> str:
    try:
        difference = float(actual) - float(expected)
    except (TypeError, ValueError):
        return ""
    if difference == int(difference):
        return f"{int(difference):+,}"
    return f"{difference:+,.6g}"


def _top_rows(record: Dict[str, Any]) -> str:
    """The first differing rows, with what differs on each."""
    examples = record.get("examples") or []
    if not examples:
        return ""
    total = int(record.get("total_differences") or 0)
    exp, act = record.get("expected_label", "expected"), record.get("actual_label", "actual")
    rows = []
    for example in examples[:TOP_ROWS_SHOWN]:
        kind = example.get("kind_label") or example.get("kind", "")
        where = " | ".join(part["text"] for part in (example.get("summary") or [])) or example.get("key", "")
        if example.get("columns"):
            differs = "<br>".join(
                f'<span class="mono">{escape(c["column"])}</span> '
                f'{escape(str(c["expected"]))} <span class="arrow">&rarr;</span> {escape(str(c["actual"]))}'
                + (f' <span class="d">{escape(_delta(c["expected"], c["actual"]))}</span>'
                   if _delta(c["expected"], c["actual"]) else "")
                for c in example["columns"][:4]
            )
            if len(example["columns"]) > 4:
                differs += f'<br><span class="d">+{len(example["columns"]) - 4} more columns</span>'
        else:
            side = exp if example.get("kind") == "missing" else act
            differs = f'<span class="d">the whole row, only in {escape(side)}</span>'
        rows.append(
            f'<tr><td>{escape(kind)}</td><td class="mono">{escape(where)}</td><td>{differs}</td></tr>'
        )
    shown = len(rows)
    more = ""
    if total > shown:
        more = (f'<p class="d">Showing the first {shown:,} of {total:,} differing rows. '
                f'The rest are in Presto, with the query above.</p>')
    return (
        f'<h2>Differing rows</h2>{more}<div class="tbl"><table><thead><tr><th>Kind</th>'
        f"<th>Row</th><th>What differs ({escape(exp)} &rarr; {escape(act)})</th></tr></thead>"
        f"<tbody>{''.join(rows)}</tbody></table></div>"
    )


def _sql_blocks(record: Dict[str, Any]) -> str:
    """The SQL each side ran, bindings filled in."""
    sources = (record.get("definition") or {}).get("sources") or {}
    blocks = []
    for side in ("expected", "actual"):
        source = sources.get(side)
        if not source:
            continue
        label = source.get("label") or side
        sql = source.get("sql")
        if sql:
            body = f'<pre class="scroll">{escape(sql)}</pre>'
        else:
            body = (f'<p class="d">Not stored: {int(source.get("sql_bytes") or 0):,} bytes. '
                    f'It is in the suite at <span class="mono">{escape(str(source.get("query_file") or ""))}</span>, '
                    f'fingerprint <span class="mono">{escape((source.get("sql_sha256") or "")[:12])}</span>.</p>')
        blocks.append(f"<details><summary>{escape(label)}</summary>{body}</details>")
    if not blocks:
        return ""
    return f'<details class="more"><summary>The SQL that ran</summary>{"".join(blocks)}</details>'


def _columns_table(record: Dict[str, Any]) -> str:
    columns = record.get("columns") or []
    if not columns:
        return ""
    status_class = {
        "MATCHED": "eq", "MATCHED - VALUE DIFF": "diff", "MATCHED - TYPE DIFF": "tol",
        "MATCHED - EQUIVALENT": "tol", "DIFF": "diff",
    }
    rows = []
    for col in sorted(columns, key=lambda c: (c.get("status") == "MATCHED", c["column"])):
        cls = status_class.get(col.get("status"), "err")
        rows.append(
            f"<tr><td class=\"mono\">{escape(col['column'])}</td>"
            f"<td><span class=\"pill {cls}\">{escape(col.get('status') or '')}</span></td>"
            f"<td class=\"mono\">{escape(str(col.get('expected_type') or ''))}</td>"
            f"<td class=\"mono\">{escape(str(col.get('actual_type') or ''))}</td>"
            f"<td class=\"num\">{escape(str(col.get('diff_rows') or ''))}</td></tr>"
        )
    return (
        f'<details class="more"><summary>Columns ({len(columns)})</summary><div class="tbl scroll"><table>'
        f"<thead><tr><th>Column</th><th>Status</th><th>{escape(record.get('expected_label', 'expected'))} type</th>"
        f"<th>{escape(record.get('actual_label', 'actual'))} type</th><th>Rows differing</th></tr></thead>"
        f"<tbody>{''.join(rows)}</tbody></table></div></details>"
    )


def _definition(record: Dict[str, Any]) -> str:
    definition = record.get("definition") or {}
    run = record.get("run") or {}
    rows = []
    for side, src in (definition.get("sources") or {}).items():
        where = src.get("query_file") or src.get("table") or ""
        sha = (src.get("sql_sha256") or "")[:12]
        rows.append(
            f"<tr><td>{escape(src.get('label') or side)}</td><td class=\"mono\">{escape(str(src.get('type') or ''))}</td>"
            f"<td class=\"mono\">{escape(str(where))}</td><td class=\"mono\">{escape(sha)}</td></tr>"
        )
    facts = [
        ("run_id", run.get("run_id")), ("run date", run.get("run_date")),
        ("generated", run.get("generated_at")), ("rowparity", run.get("rowparity_version")),
        ("git commit", run.get("git_commit")), ("build", run.get("build_url")),
        ("params", ", ".join(f"{k}={v}" for k, v in (run.get("params") or {}).items())),
    ]
    fact_rows = "".join(
        f"<tr><td>{escape(k)}</td><td class=\"mono\" colspan=\"3\">{escape(str(v))}</td></tr>"
        for k, v in facts if v
    )
    return (
        '<details class="more"><summary>Run and definition</summary><div class="tbl"><table>'
        "<thead><tr><th>Side</th><th>Type</th><th>SQL</th><th>SQL sha256</th></tr></thead>"
        f"<tbody>{''.join(rows)}{fact_rows}</tbody></table></div></details>"
    )


def render_test(record: Dict[str, Any]) -> str:
    name = record.get("case", "")
    status = record.get("status")
    run = record.get("run") or {}
    eyebrow = "rowparity"
    if run.get("run_date"):
        eyebrow += f" &middot; run {escape(run['run_date'])}"
    if run.get("run_id"):
        eyebrow += f" &middot; run_id {escape(run['run_id'])}"

    body = [f'<div class="eyebrow">{eyebrow}</div><h1>{escape(name)}</h1>']
    if status == "ERROR":
        body.append(
            f'<div class="band err"><div class="verdict">ERROR</div>'
            f'<div class="size">{escape(record.get("error_type") or "Error")}: {escape(record.get("error") or "")}</div>'
            "<div>No verdict: the pair did not complete. It is safe to retry.</div></div>"
        )
        body.append(_definition(record))
        return _page(f"{name} - rowparity", "".join(body))

    diffs = record.get("diffs") or {}
    query = diffs.get("query")
    band = [
        f'<div class="band {_status_class(status)}">'
        f'<div class="verdict">{escape((status or "").replace("_", " "))}</div>'
        f'<div class="size">{_size_sentence(record)}</div>'
    ]
    if query:
        band.append(f"<div>Every differing row of this run, in Presto:</div>{_query_block(query)}")
        if diffs.get("complete") is False:
            band.append(
                f"<div>Stores the first {int(diffs.get('stored_rows') or 0):,} differing rows of "
                f"{int(record.get('total_differences') or 0):,}.</div>"
            )
    band.append("</div>")
    body.append("".join(band))
    body.append(_counts_strip(record))

    findings = record.get("findings") or []
    if findings:
        body.append("<h2>Findings</h2><ol class=\"findings\">")
        body.extend(_finding(i, f, query) for i, f in enumerate(findings, 1))
        body.append("</ol>")
    notes = record.get("notes") or []
    if notes:
        body.append('<div class="notes">' + "".join(f"<div>{escape(n)}</div>" for n in notes) + "</div>")

    body.append(_top_rows(record))
    body.append(_sql_blocks(record))
    body.append(_columns_table(record))
    body.append(_definition(record))
    body.append("<footer>Generated by rowparity from result.json.</footer>")
    return _page(f"{name} - rowparity", "".join(body))


def render_run(summary: Dict[str, Any], test_link=None) -> str:
    """``test_link(case)`` returns a relative href to that test's report, or None."""
    run_id, run_date = summary.get("run_id", ""), summary.get("run_date") or ""
    failed = summary.get("failed") or []
    status = "DIFFERENT" if failed or summary.get("no_result") else "EQUIVALENT"

    def link(case: str) -> str:
        href = test_link(case) if test_link else None
        return f'<a href="{escape(href)}">{escape(case)}</a>' if href else escape(case)

    stats = [
        ("tests", summary.get("tests", 0)), ("passed", summary.get("passed", 0)),
        ("within tolerance", summary.get("within_tolerance", 0)),
        ("different", summary.get("different", 0)), ("errored", summary.get("errored", 0)),
        ("no result", len(summary.get("no_result") or [])),
    ]
    body = [
        f'<div class="eyebrow">rowparity &middot; run {escape(run_date)} &middot; run_id {escape(run_id)}</div>',
        f"<h1>Run {escape(run_date)}</h1>",
        f'<div class="band {_status_class(status)}"><div class="verdict">'
        f"{'EVERY TEST PASSED' if status == 'EQUIVALENT' else 'SOME TESTS DID NOT PASS'}</div>"
        '<div class="stats">'
        + "".join(f"<div><b>{int(v):,}</b><span>{escape(k)}</span></div>" for k, v in stats)
        + "</div></div>",
    ]

    causes = summary.get("common_causes") or []
    if causes:
        rows = "".join(
            f"<tr><td class=\"num\">{c['test_count']:,}</td><td class=\"num\">{c['rows']:,}</td>"
            f"<td>{escape(c['cause'])}<br><span class=\"mono\" style=\"color:var(--muted)\">"
            f"{', '.join(link(t) for t in c['tests'][:12])}{' ...' if len(c['tests']) > 12 else ''}</span></td></tr>"
            for c in causes
        )
        body.append(
            "<h2>Common causes across tests</h2><div class=\"tbl\"><table><thead><tr><th>Tests</th>"
            f"<th>Rows</th><th>Cause</th></tr></thead><tbody>{rows}</tbody></table></div>"
        )

    if failed or summary.get("no_result"):
        rows = []
        for f in failed:
            detail = f.get("error") if f.get("status") == "ERROR" else f.get("top_finding")
            ratio = _ratio(f["diff_ratio"]) if f.get("diff_ratio") else ""
            rows.append(
                f"<tr><td>{_pill(f.get('status'))}</td><td class=\"num\">{ratio}</td>"
                f"<td class=\"mono\">{link(f['case'])}</td><td>{escape(detail or '')}</td></tr>"
            )
        for name in summary.get("no_result") or []:
            rows.append(
                f"<tr><td>{_pill('NO RESULT')}</td><td></td><td class=\"mono\">{escape(name)}</td>"
                "<td>The task never published a result.</td></tr>"
            )
        body.append(
            "<h2>Did not pass, worst first</h2><div class=\"tbl\"><table><thead><tr><th>Status</th>"
            f"<th>Differ</th><th>Test</th><th>Top finding</th></tr></thead><tbody>{''.join(rows)}</tbody></table></div>"
        )

    passed = summary.get("passed_cases") or []
    if passed:
        items = ", ".join(link(c) for c in passed)
        body.append(
            f'<details class="more"><summary>Passed ({len(passed):,})</summary>'
            f'<p class="mono" style="line-height:1.9">{items}</p></details>'
        )
    body.append("<footer>Generated by rowparity summarize.</footer>")
    return _page(f"Run {run_date} - rowparity", "".join(body))



def render_compare(runs, title: str, expected_label: str = "expected", actual_label: str = "actual") -> str:
    """``rowparity compare-runs``: one column per run, oldest on the left."""
    metrics = [
        ("Tests", "tests", "{:,}"), ("Passed", "passed", "{:,}"), ("Errored", "errored", "{:,}"),
        ("Rows compared", "rows_compared", "{:,}"),
        (f"{expected_label} rows", "expected_rows", "{:,}"), (f"{actual_label} rows", "actual_rows", "{:,}"),
        ("Rows mismatching", "rows_mismatching", "{:,}"), ("Mismatch %", "mismatch_ratio", None),
    ]
    head = "".join(
        f"<th>{escape(r['run_date'])}<br><span class=\"d\">{escape(r['run_id'])}</span></th>" for r in runs
    )
    rows = "".join(
        f"<tr><th>{escape(label)}</th>"
        + "".join(
            f"<td class=\"num\">{_ratio(r[key]) if fmt is None else fmt.format(r[key])}</td>" for r in runs
        )
        + "</tr>"
        for label, key, fmt in metrics
    )
    body = (
        '<div class="eyebrow">rowparity &middot; compare runs</div>'
        f"<h1>{escape(title)}</h1>"
        '<p class="d">Rows compared is the larger side of each test. Errored tests are counted but add no rows.</p>'
        f'<div class="tbl"><table><thead><tr><th></th>{head}</tr></thead><tbody>{rows}</tbody></table></div>'
        "<footer>Generated by rowparity compare-runs.</footer>"
    )
    return _page(f"{title} - rowparity", body)
