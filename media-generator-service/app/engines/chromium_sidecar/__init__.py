"""Chromium sidecar pipeline — HTML preview + PDF generation.

The heavy lifting lives in a long-running Node sidecar (``sidecar/``) that
keeps a warm Chromium instance, so each render call avoids the ~200ms Node
startup cost.  The Python side talks to it over stdio JSON-RPC via
``sidecar/sidecar_manager.py``.
"""
