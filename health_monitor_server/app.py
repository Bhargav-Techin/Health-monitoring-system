from flask import Flask, request, jsonify
from flask_cors import CORS
import joblib
import pandas as pd
import numpy as np
import os

app = Flask(__name__)
CORS(app)  # Enable CORS for frontend integration

# Load the trained model when server starts
MODEL_PATH = "medical_anomaly_detector.pkl"
model_data = None
detector = None

def load_trained_model():
    global model_data, detector
    try:
        model_data = joblib.load(MODEL_PATH)
        print("✅ Model loaded successfully!")
        return True
    except Exception as e:
        print(f"❌ Error loading model: {e}")
        return False

# Load model on startup
load_trained_model()

class ModelPredictor:
    def __init__(self, model_data):
        self.model = model_data['model']
        self.scaler = model_data['scaler']
        self.feature_names = model_data['feature_names']
    
    def create_features(self, df_input):
        """Create enhanced features - same as training"""
        df = df_input.copy()
        
        # Basic ratios with safe division
        df['HR_Temp_Ratio'] = df['Heart_rate'] / (df['Temp'] + 1e-8)
        df['SpO2_HR_Ratio'] = df['SpO2'] / (df['Heart_rate'] + 1e-8)
        df['Temp_SpO2_Ratio'] = df['Temp'] / (df['SpO2'] + 1e-8)
        
        # Deviations from normal
        df['HR_Deviation'] = np.abs(df['Heart_rate'] - 70)
        df['Temp_Deviation'] = np.abs(df['Temp'] - 36.5)
        df['SpO2_Deficit'] = np.maximum(0, 98 - df['SpO2'])
        
        # Combined risk score
        df['Risk_Score'] = (df['HR_Deviation'] / 70 + 
                           df['Temp_Deviation'] / 36.5 + 
                           df['SpO2_Deficit'] / 98)
        
        # Additional medical indicators
        df['HR_High'] = (df['Heart_rate'] > 100).astype(int)
        df['HR_Low'] = (df['Heart_rate'] < 60).astype(int)
        df['Temp_High'] = (df['Temp'] > 37.2).astype(int)
        df['Temp_Low'] = (df['Temp'] < 36.1).astype(int)
        df['SpO2_Low'] = (df['SpO2'] < 95).astype(int)
        
        return df
    
    def predict(self, heart_rate, temperature, spo2):
        """Make prediction"""
        try:
            # Create input dataframe
            input_data = pd.DataFrame({
                'Heart_rate': [heart_rate],
                'Temp': [temperature],
                'SpO2': [spo2]
            })
            
            # Create features
            input_features = self.create_features(input_data)
            
            # Select features in exact order
            X_input = input_features[self.feature_names]
            
            # Scale input
            X_input_scaled = self.scaler.transform(X_input)
            X_input_scaled = pd.DataFrame(X_input_scaled, columns=self.feature_names)
            
            # Make prediction
            prediction = self.model.predict(X_input_scaled)[0]
            probability = self.model.predict_proba(X_input_scaled)[0]
            
            return {
                'prediction': int(prediction),
                'probabilities': {
                    'normal': float(probability[0]),
                    'anomaly': float(probability[1])
                },
                'confidence': float(probability[prediction]),
                'status': 'success'
            }
            
        except Exception as e:
            return {
                'error': str(e),
                'status': 'error'
            }

# Initialize predictor
predictor = ModelPredictor(model_data) if model_data else None

@app.route('/', methods=['GET'])
def home():
    """Health check endpoint"""
    return jsonify({
        'message': 'Medical Anomaly Detection API',
        'status': 'running',
        'model_loaded': model_data is not None
    })

@app.route('/predict', methods=['POST'])
def predict():
    """Main prediction endpoint"""
    if not predictor:
        return jsonify({
            'error': 'Model not loaded',
            'status': 'error'
        }), 500
    
    try:
        # Get data from request
        data = request.get_json()
        
        # Validate input
        required_fields = ['heart_rate', 'temperature', 'spo2']
        for field in required_fields:
            if field not in data:
                return jsonify({
                    'error': f'Missing required field: {field}',
                    'status': 'error'
                }), 400
        
        # Extract values
        heart_rate = float(data['heart_rate'])
        temperature = float(data['temperature'])
        spo2 = float(data['spo2'])
        
        # Validate ranges
        if not (30 <= heart_rate <= 200):
            return jsonify({'error': 'Heart rate must be between 30-200 bpm'}), 400
        if not (30 <= temperature <= 45):
            return jsonify({'error': 'Temperature must be between 30-45°C'}), 400
        if not (70 <= spo2 <= 100):
            return jsonify({'error': 'SpO2 must be between 70-100%'}), 400
        
        # Make prediction
        result = predictor.predict(heart_rate, temperature, spo2)
        
        if result['status'] == 'error':
            return jsonify(result), 500
        
        # Add medical interpretation
        if result['prediction'] == 1:
            interpretation = {
                'result': 'ANOMALY DETECTED',
                'recommendation': 'Seek medical evaluation',
                'urgency': 'High' if result['confidence'] > 0.8 else 'Medium'
            }
        else:
            interpretation = {
                'result': 'NORMAL',
                'recommendation': 'Vital signs appear normal',
                'urgency': 'Low'
            }
        
        result['interpretation'] = interpretation
        result['input'] = {
            'heart_rate': heart_rate,
            'temperature': temperature,
            'spo2': spo2
        }
        
        return jsonify(result)
        
    except ValueError as e:
        return jsonify({
            'error': 'Invalid input values',
            'details': str(e),
            'status': 'error'
        }), 400
    except Exception as e:
        return jsonify({
            'error': 'Internal server error',
            'details': str(e),
            'status': 'error'
        }), 500

@app.route('/batch_predict', methods=['POST'])
def batch_predict():
    """Batch prediction endpoint"""
    if not predictor:
        return jsonify({'error': 'Model not loaded'}), 500
    
    try:
        data = request.get_json()
        patients = data.get('patients', [])
        
        if not patients:
            return jsonify({'error': 'No patient data provided'}), 400
        
        results = []
        for i, patient in enumerate(patients):
            try:
                result = predictor.predict(
                    patient['heart_rate'],
                    patient['temperature'],
                    patient['spo2']
                )
                result['patient_id'] = patient.get('id', f'patient_{i+1}')
                results.append(result)
            except Exception as e:
                results.append({
                    'patient_id': patient.get('id', f'patient_{i+1}'),
                    'error': str(e),
                    'status': 'error'
                })
        
        return jsonify({
            'results': results,
            'total_patients': len(patients),
            'status': 'success'
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/model_info', methods=['GET'])
def model_info():
    """Get model information"""
    if not model_data:
        return jsonify({'error': 'Model not loaded'}), 500
    
    return jsonify({
        'feature_names': model_data['feature_names'],
        'model_type': type(model_data['model']).__name__,
        'performance_metrics': model_data.get('results', []),
        'status': 'success'
    })

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)