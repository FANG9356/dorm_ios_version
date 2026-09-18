import os
import re
from flask import Flask, request, jsonify
import pytesseract
import cv2
import numpy as np
from PIL import Image

app = Flask(__name__)

# Configurable receiver name for verification
RECEIVER_NAME = os.getenv("RECEIVER_NAME", "ภคพล")

def preprocess_image(image_path):
    img = cv2.imread(image_path)
    if img is None:
        return None
    # Convert to grayscale
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    
    # Resize to make text larger for better OCR
    scale_percent = 150 # percent of original size
    width = int(gray.shape[1] * scale_percent / 100)
    height = int(gray.shape[0] * scale_percent / 100)
    dim = (width, height)
    resized = cv2.resize(gray, dim, interpolation = cv2.INTER_LINEAR)
    
    return resized

@app.route('/verify', methods=['POST'])
def verify_slip():
    data = request.json
    filepath = data.get("filepath")
    expected_amount = data.get("amount")
    
    if not filepath or expected_amount is None:
        return jsonify({"valid": False, "reason": "Missing filepath or amount"}), 400
        
    if not os.path.isabs(filepath):
        base_dir = os.getenv("BACKEND_DIR", "../backend-dorm")
        filepath = os.path.join(base_dir, filepath)

    if not os.path.exists(filepath):
        return jsonify({"valid": False, "reason": f"Slip image file not found: {filepath}"}), 404

    try:
        img = preprocess_image(filepath)
        if img is None:
            return jsonify({"valid": False, "reason": "Failed to read image"}), 400

        # Run OCR (using Thai + English)
        custom_config = r'--oem 3 --psm 4'
        text = pytesseract.image_to_string(img, lang='tha+eng', config=custom_config)
        
        # Clean up text for easier searching
        clean_text = text.replace(" ", "").replace(",", "")
        
        # 1. Verify Name
        if RECEIVER_NAME not in clean_text:
            return jsonify({"valid": False, "reason": f"Recipient name '{RECEIVER_NAME}' not found on slip"}), 200
            
        # 2. Verify Amount
        amount_str = f"{float(expected_amount):.2f}"
        amount_str_no_decimal = f"{int(float(expected_amount))}"
        
        if amount_str not in clean_text and amount_str_no_decimal not in clean_text:
            return jsonify({"valid": False, "reason": f"Expected amount {amount_str} not found on slip"}), 200

        return jsonify({"valid": True, "reason": "Verified locally via OCR"}), 200

    except Exception as e:
        return jsonify({"valid": False, "reason": f"OCR Processing Error: {str(e)}"}), 500

if __name__ == '__main__':
    app.run(host='127.0.0.1', port=5001)
