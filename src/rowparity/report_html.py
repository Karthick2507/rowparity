"""Renders the historical HTML report (`rowparity report`).

Adapts templates/report.html — a static file shipped with the package — by
substituting a handful of placeholders. No templating engine dependency:
the file is already valid HTML/CSS/JS, the placeholders are just tokens a
real value could never collide with.
"""
from __future__ import annotations

import json
import os
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

_TEMPLATE_PATH = os.path.join(os.path.dirname(__file__), "templates", "report.html")


def render_html_report(cases: List[Dict[str, Any]], *, days: int,
                        generated_at: Optional[datetime] = None) -> str:
    with open(_TEMPLATE_PATH, "r", encoding="utf-8") as fh:
        template = fh.read()

    generated_at = generated_at or datetime.now(tz=timezone.utc)
    generated_str = generated_at.strftime("%Y-%m-%d %H:%M UTC")

    # Real diff values are arbitrary strings from the underlying tables and
    # could legitimately contain "</script>" -- escape it so it can't break
    # out of the inline <script> block (standard JSON-in-<script> practice).
    cases_json = json.dumps(cases).replace("</script", "<\\/script")

    html = template.replace("__ROWPARITY_CASES_JSON__", cases_json)
    html = html.replace("__ROWPARITY_WINDOW_DAYS__", str(days))
    html = html.replace("__ROWPARITY_GENERATED_AT__", generated_str)
    return html


def render_report_from_sink(spec: str, *, table_prefix: str = "rowparity", days: int = 21) -> str:
    """The whole pipeline: read a result sink's history, reshape it, render HTML."""
    from .history import build_case_histories, read_raw_history

    summary_rows, diffs_rows = read_raw_history(spec, table_prefix=table_prefix, days=days)
    cases = build_case_histories(summary_rows, diffs_rows)
    return render_html_report(cases, days=days)