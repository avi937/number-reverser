"""
Number Reverser — HTTP API
Endpoints:
  GET  /health        → {"status": "ok"}
  POST /reverse       → {"input": "12345", "result": "54321"}
  GET  /reverse?n=123 → {"input": "123",   "result": "321"}
"""

import os
from flask import Flask, request, jsonify
from reverser import reverse_number

app = Flask(__name__)


@app.route("/health")
def health():
    return jsonify({"status": "ok"}), 200


@app.route("/reverse", methods=["GET", "POST"])
def reverse():
    if request.method == "POST":
        data = request.get_json(silent=True) or {}
        # Use `is not None` check so integer 0 is not treated as falsy
        value = (
            data.get("n") if data.get("n") is not None
            else data.get("number") if data.get("number") is not None
            else data.get("input")
        )
    else:
        value = request.args.get("n")

    if value is None:
        return jsonify({"error": "Missing parameter 'n' (number to reverse)."}), 400

    try:
        result = reverse_number(str(value))
        return jsonify({"input": str(value), "result": result}), 200
    except ValueError as exc:
        return jsonify({"error": str(exc)}), 422


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port)
