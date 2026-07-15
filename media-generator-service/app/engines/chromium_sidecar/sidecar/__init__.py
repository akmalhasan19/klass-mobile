"""Node sidecar process for the Chromium pipeline.

``chromium_sidecar.js`` is spawned once at service startup and stays alive for
the process lifetime.  It exposes ``html_to_pdf`` and ``health`` over a
line-delimited JSON-RPC protocol on stdin/stdout (logs go to stderr so they
never corrupt the protocol stream).  ``package.json`` pins the only runtime
dependency — ``playwright``.
"""
