"""Node sidecar process for the Marp pipeline.

``marp_sidecar.js`` is spawned once at service startup and stays alive for
the process lifetime.  It exposes ``render_html`` / ``render_pdf`` over a
line-delimited JSON-RPC protocol on stdin/stdout (logs go to stderr so they
never corrupt the protocol stream).  ``package.json`` pins the only two
runtime dependencies — ``@marp-team/marp-core`` and ``playwright``.
"""
