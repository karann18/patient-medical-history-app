from flask import Flask, request, jsonify
from flask_cors import CORS
from models import Session, Patient, init_db
import os
import threading

app = Flask(__name__, static_folder='.', static_url_path='')
CORS(app)

@app.route('/')
def index():
    return app.send_static_file('index.html')


# Initialize NLP Model in a separate thread so it doesn't block server startup
tokenizer = None
model = None

def load_nlp():
    global tokenizer, model
    try:
        from transformers import AutoTokenizer, AutoModelForSeq2SeqLM
        print("Loading NLP Model (This might take a moment on first run)...")
        tokenizer = AutoTokenizer.from_pretrained("sshleifer/distilbart-cnn-12-6")
        model = AutoModelForSeq2SeqLM.from_pretrained("sshleifer/distilbart-cnn-12-6")
        print("NLP Model loaded successfully.")
    except Exception as e:
        print(f"Warning: Could not load NLP model. Ensure transformers and torch are installed. {e}")

threading.Thread(target=load_nlp, daemon=True).start()

def quick_summary(patient):
    allergy_str = ", ".join(patient['allergies']) if patient['allergies'] and patient['allergies'][0] != "None" else "no known allergies"
    return f"{patient['name']} is a {patient['age']}-year-old {patient['gender']} with {allergy_str}."

def generate_nlp_summary(patient):
    # If the model is not loaded yet or failed, fallback to a fast programmatic summary
    if model is None or tokenizer is None:
        return quick_summary(patient)

    # Construct a medical narrative for the NLP to summarize
    text = f"Patient {patient['name']} is {patient['age']} years old. "
    if patient['allergies'] and patient['allergies'][0] != "None":
        text += f"The patient is allergic to {', '.join(patient['allergies'])}. "
    else:
        text += "The patient has no known allergies. "
        
    if patient['frequentProblems'] and patient['frequentProblems'][0] != "None":
        text += f"They have a history of {', '.join(patient['frequentProblems'])}. "
        
    if patient['medications'] and patient['medications'][0] != "None":
        text += f"Current medications include {', '.join(patient['medications'])}. "

    # Let the model summarize the generated text block
    try:
        inputs = tokenizer([text], max_length=1024, return_tensors="pt", truncation=True)
        # Generate summary
        summary_ids = model.generate(inputs["input_ids"], max_length=30, min_length=10, do_sample=False)
        summary = tokenizer.decode(summary_ids[0], skip_special_tokens=True)
        return summary.strip()
    except Exception as e:
        print("Summarization failed:", e)
        return text # Fallback

def patient_to_dict(p, with_nlp=False):
    data = {
        "id": p.id,
        "name": p.name,
        "age": p.age,
        "gender": p.gender,
        "allergies": p.allergies,
        "frequentProblems": p.frequent_problems,
        "medications": p.medications,
        "surgeries": p.surgeries,
        "encounters": p.encounters
    }
    if with_nlp:
        data["nlp_summary"] = generate_nlp_summary(data)
    return data

@app.route('/api/patients', methods=['GET'])
def get_patients():
    session = Session()
    patients = session.query(Patient).all()
    results = [patient_to_dict(p) for p in patients]
    session.close()
    return jsonify(results)

@app.route('/api/patients/<patient_id>', methods=['GET'])
def get_patient(patient_id):
    session = Session()
    patient = session.query(Patient).filter_by(id=patient_id).first()
    if not patient:
        session.close()
        return jsonify({"error": "Patient not found"}), 404
    result = patient_to_dict(patient, with_nlp=True)
    session.close()
    return jsonify(result)

@app.route('/api/patients', methods=['POST'])
def add_patient():
    data = request.json
    session = Session()
    
    new_patient = Patient(
        id=data.get('id'),
        name=data.get('name'),
        age=data.get('age'),
        gender=data.get('gender'),
        allergies=data.get('allergies', ["None"]),
        frequent_problems=data.get('frequentProblems', ["None"]),
        medications=data.get('medications', ["None"]),
        surgeries=data.get('surgeries', ["None"]),
        encounters=data.get('encounters', [])
    )
    
    session.add(new_patient)
    session.commit()
    
    res = patient_to_dict(new_patient, with_nlp=True)
    session.close()
    
    return jsonify(res), 201

if __name__ == '__main__':
    # Initialize DB if it doesn't exist
    if not os.path.exists('patients.db'):
        init_db()

    # use_reloader=False avoids restarts when ML libs write cache files under site-packages
    port = int(os.environ.get("PORT", "5000"))
    is_cloud = os.environ.get("RENDER") == "true"
    app.run(
        debug=not is_cloud,
        host="0.0.0.0" if is_cloud else "127.0.0.1",
        port=port,
        use_reloader=False,
    )
