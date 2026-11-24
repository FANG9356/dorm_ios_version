import hmac
import os
import re
from flask import Flask, request, jsonify
import pytesseract
import cv2

app = Flask(__name__)

# Configurable receiver name (no hardcoded personal default)
RECEIVER_NAME = os.getenv("RECEIVER_NAME", "").strip()
OCR_INTERNAL_TOKEN = os.getenv("OCR_INTERNAL_TOKEN", "").strip()


def _allowed_uploads_root():
    uploads_dir = os.getenv("UPLOADS_DIR", "").strip()
    if not uploads_dir:
        base_dir = os.getenv("BACKEND_DIR", "../backend-dorm")
        uploads_dir = os.path.join(base_dir, "uploads")
    return os.path.realpath(uploads_dir)


def _resolve_safe_slip_path(raw_filepath):
    if not raw_filepath or not isinstance(raw_filepath, str):
        return None
    base_dir = os.getenv("BACKEND_DIR", "../backend-dorm")
    candidate = raw_filepath if os.path.isabs(raw_filepath) else os.path.join(base_dir, raw_filepath)
    resolved = os.path.realpath(candidate)
    uploads_root = _allowed_uploads_root()
    if os.path.commonpath([uploads_root, resolved]) != uploads_root:
        return None
    if resolved == uploads_root:
        return None
    return resolved


def preprocess_image(image_path):
    img = cv2.imread(image_path)
    if img is None:
        return None
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    scale_percent = 150
    width = int(gray.shape[1] * scale_percent / 100)
    height = int(gray.shape[0] * scale_percent / 100)
    return cv2.resize(gray, (width, height), interpolation=cv2.INTER_LINEAR)


@app.route('/verify', methods=['POST'])
def verify_slip():
    if OCR_INTERNAL_TOKEN:
        supplied = request.headers.get("X-Internal-OCR-Token", "")
        if not hmac.compare_digest(supplied, OCR_INTERNAL_TOKEN):
            return jsonify({"valid": False, "reason": "Unauthorized"}), 401

    data = request.get_json(silent=True) or {}
    raw_filepath = data.get("filepath")
    expected_amount = data.get("amount")
    expected_receiver = (data.get("expected_receiver") or "").strip()

    if not raw_filepath or expected_amount is None:
        return jsonify({"valid": False, "reason": "Missing filepath or amount"}), 400

    filepath = _resolve_safe_slip_path(raw_filepath)
    if not filepath:
        return jsonify({"valid": False, "reason": "Invalid slip path"}), 400

    if not os.path.isfile(filepath):
        return jsonify({"valid": False, "reason": "Slip image file not found"}), 404

    try:
        amount_val = float(expected_amount)
    except (TypeError, ValueError):
        return jsonify({"valid": False, "reason": "Invalid amount"}), 400

    try:
        img = preprocess_image(filepath)
        if img is None:
            return jsonify({"valid": False, "reason": "Failed to read image"}), 400

        custom_config = r'--oem 3 --psm 4'
        text = pytesseract.image_to_string(img, lang='tha+eng', config=custom_config)
        clean_text = text.replace(" ", "").replace(",", "")

        # 1. Verify Receiver (fail closed if no receiver configured)
        receiver_to_check = expected_receiver if expected_receiver else RECEIVER_NAME
        if not receiver_to_check:
            return jsonify({"valid": False, "reason": "Expected receiver is not configured"}), 200

        receiver_candidates = [part.strip() for part in receiver_to_check.split("_") if part.strip()]
        matched_receiver = False
        for candidate in receiver_candidates:
            digits_only = candidate.replace("-", "")
            search_term = digits_only[-4:] if digits_only.isdigit() and len(digits_only) >= 4 else candidate
            if search_term and search_term in clean_text:
                matched_receiver = True
                break
        if not matched_receiver:
            return jsonify({"valid": False, "reason": "Recipient identifier not found on slip"}), 200

        # 2. Verify Amount (escape regex metacharacters so '.' matches literal decimal point)
        amount_exact = f"{amount_val:.2f}"
        patterns = [re.escape(amount_exact)]
        if amount_val.is_integer():
            patterns.append(re.escape(f"{int(amount_val)}"))
        amount_pattern = rf"(?<![\dA-Za-z])({'|'.join(patterns)})(?![\dA-Za-z])"
        if not re.search(amount_pattern, clean_text):
            return jsonify({"valid": False, "reason": f"Expected amount {amount_exact} not found on slip"}), 200

        return jsonify({"valid": True, "reason": "Verified locally via OCR"}), 200

    except Exception as e:
        return jsonify({"valid": False, "reason": f"OCR Processing Error: {str(e)}"}), 500


if __name__ == '__main__':
    app.run(host='127.0.0.1', port=5001)
