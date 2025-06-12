import streamlit as st
import pandas as pd
import numpy as np
import pickle
import plotly.express as px
import plotly.graph_objects as go
from pathlib import Path
import io
import base64

# Custom CSS for adaptive, exquisite styling
st.markdown("""
<style>
    @import url('https://fonts.googleapis.com/css2?family=Roboto:wght@400;500;700&display=swap');
    
    :root {
        --primary: #1e3a8a;
        --primary-hover: #1e40af;
        --accent: #3b82f6;
        --accent-hover: #2563eb;
        --text: #1e293b;
        --text-secondary: #475569;
        --card-bg: #ffffff;
        --shadow: rgba(0,0,0,0.08);
        --shadow-hover: rgba(0,0,0,0.12);
        --success-bg: #ecfdf5;
        --success-text: #065f46;
        --error-bg: #fef2f2;
        --error-text: #b91c1c;
        --border: #cbd5e1;
    }
    
    @media (prefers-color-scheme: dark) {
        :root {
            --primary: #1e40af;
            --primary-hover: #3b82f6;
            --accent: #60a5fa;
            --accent-hover: #93c5fd;
            --text: #e2e8f0;
            --text-secondary: #94a3b8;
            --card-bg: #1f2937;
            --shadow: rgba(0,0,0,0.3);
            --shadow-hover: rgba(0,0,0,0.4);
            --success-bg: #064e3b;
            --success-text: #6ee7b7;
            --error-bg: #7f1d1d;
            --error-text: #f87171;
            --border: #4b5563;
        }
        .main {
            background: linear-gradient(135deg, #111827 0%, #1f2937 100%);
        }
        .stDataFrame, .stPlotlyChart, .stFileUploader, .footer {
            background: var(--card-bg);
        }
    }
    
    @media (prefers-color-scheme: light) {
        .main {
            background: linear-gradient(135deg, #f8fafc 0%, #e2e8f0 100%);
        }
    }
    
    .main {
        font-family: 'Roboto', sans-serif;
    }
    .stButton>button {
        background: linear-gradient(90deg, var(--primary), var(--accent));
        color: #ffffff;
        border-radius: 12px;
        padding: 14px 36px;
        font-size: 16px;
        font-weight: 600;
        border: none;
        transition: transform 0.2s, box-shadow 0.3s, background 0.3s;
    }
    .stButton>button:hover {
        transform: translateY(-3px);
        box-shadow: 0 6px 16px var(--shadow-hover);
        background: linear-gradient(90deg, var(--primary-hover), var(--accent-hover));
    }
    .stNumberInput input {
        border-radius: 10px;
        border: 1px solid var(--border);
        padding: 12px;
        font-size: 14px;
        background-color: var(--card-bg);
        transition: border-color 0.3s, box-shadow 0.3s, transform 0.2s;
    }
    .stNumberInput input:focus {
        border-color: var(--primary);
        box-shadow: 0 0 0 4px rgba(30,58,138,0.15);
        transform: scale(1.02);
    }
    .stNumberInput>label {
        font-size: 14px;
        font-weight: 500;
        color: var(--text-secondary);
        margin-bottom: 8px;
        letter-spacing: 0.5px;
        text-transform: uppercase;
    }
    .stSuccess {
        background-color: var(--success-bg);
        color: var(--success-text);
        padding: 20px;
        border-radius: 12px;
        font-size: 18px;
        font-weight: 500;
        border-left: 5px solid var(--success-text);
        box-shadow: 0 4px 12px var(--shadow);
    }
    .stError {
        background-color: var(--error-bg);
        color: var(--error-text);
        padding: 20px;
        border-radius: 12px;
        font-size: 16px;
        border-left: 5px solid var(--error-text);
        box-shadow: 0 4px 12px var(--shadow);
    }
    .header {
        font-size: 36px;
        font-weight: 700;
        color: var(--primary);
        text-align: center;
        margin-bottom: 24px;
        letter-spacing: -0.5px;
        text-shadow: 0 2px 4px var(--shadow);
    }
    .subheader {
        font-size: 24px;
        font-weight: 600;
        color: var(--text);
        margin: 32px 0 16px;
        border-bottom: 2px solid var(--border);
        padding-bottom: 8px;
    }
    .sidebar .sidebar-content {
        background: var(--card-bg);
        padding: 24px;
        border-radius: 12px;
        box-shadow: 0 4px 12px var(--shadow);
    }
    .feature-card {
        background-color: var(--card-bg);
        padding: 16px;
        border-radius: 12px;
        margin-bottom: 16px;
        box-shadow: 0 3px 8px var(--shadow);
        transition: transform 0.2s, box-shadow 0.3s;
    }
    .feature-card:hover {
        transform: translateY(-2px);
        box-shadow: 0 6px 16px var(--shadow-hover);
    }
    .footer {
        text-align: center;
        font-size: 14px;
        color: var(--text-secondary);
        margin-top: 60px;
        padding: 24px 0;
        border-top: 1px solid var(--border);
        border-radius: 12px;
    }
    .stDataFrame, .stPlotlyChart, .stFileUploader {
        border-radius: 12px;
        overflow: hidden;
        box-shadow: 0 4px 12px var(--shadow);
        padding: 12px;
    }
</style>
""", unsafe_allow_html=True)

# Initialize session state
if 'predictions' not in st.session_state:
    st.session_state.predictions = []
if 'input_valid' not in st.session_state:
    st.session_state.input_valid = False

# Load saved objects
@st.cache_resource
def load_objects():
    try:
        return {
            'model': pickle.load(open('model_rf.pkl', 'rb')),
            'scaler': pickle.load(open('standard_scaler.pkl', 'rb')),
            'pt': pickle.load(open('power_transformer.pkl', 'rb')),
            'poly': pickle.load(open('polynomial_features.pkl', 'rb')),
            'label_encoder': pickle.load(open('label_encoder.pkl', 'rb'))
        }
    except FileNotFoundError:
        st.error("🚨 Missing pickle files. Ensure 'model_rf.pkl', 'standard_scaler.pkl', 'power_transformer.pkl', 'polynomial_features.pkl', and 'label_encoder.pkl' are in the same directory.")
        st.stop()

objects = load_objects()
model, scaler, pt, poly, label_encoder = objects['model'], objects['scaler'], objects['pt'], objects['poly'], objects['label_encoder']

# Feature names and ranges
feature_names = ['tempmax', 'tempmin', 'temp', 'feelslikemax', 'feelslikemin', 'feelslike', 
                 'dew', 'humidity', 'precip', 'precipprob', 'precipcover', 'snow', 
                 'snowdepth', 'windspeed', 'winddir', 'sealevelpressure', 'cloudcover', 
                 'visibility', 'solarradiation', 'solarenergy', 'uvindex', 'conditions', 
                 'stations', 'cases']
feature_ranges = {
    'tempmax': (20.0, 40.0), 'tempmin': (15.0, 30.0), 'temp': (20.0, 35.0),
    'feelslikemax': (20.0, 50.0), 'feelslikemin': (15.0, 35.0), 'feelslike': (20.0, 40.0),
    'dew': (15.0, 30.0), 'humidity': (50.0, 100.0), 'precip': (0.0, 50.0),
    'precipprob': (0.0, 100.0), 'precipcover': (0.0, 100.0), 'snow': (0.0, 10.0),
    'snowdepth': (0.0, 10.0), 'windspeed': (0.0, 50.0), 'winddir': (0.0, 360.0),
    'sealevelpressure': (990.0, 1020.0), 'cloudcover': (0.0, 100.0), 'visibility': (0.0, 10.0),
    'solarradiation': (0.0, 400.0), 'solarenergy': (0.0, 30.0), 'uvindex': (0.0, 10.0),
    'conditions': (0.0, 5.0), 'stations': (0.0, 5.0), 'cases': (0.0, 20000.0)
}

# App title
st.markdown('<div class="header">🌍 Dengue Prediction</div>', unsafe_allow_html=True)
#st.markdown("Unlock precise risk predictions with advanced machine learning. Input weather and case data or upload a CSV for effortless analysis.", unsafe_allow_html=True)

# Sidebar for settings
st.sidebar.title("⚙️ Control Panel")
st.sidebar.markdown("Tailor your analysis with intuitive controls.")
show_visualizations = st.sidebar.checkbox("Show Data Visualizations", value=True)
show_feature_importance = st.sidebar.checkbox("Show Feature Importance", value=True)
clear_history = st.sidebar.button("Clear Prediction History")
download_template = st.sidebar.download_button(
    label="📄 Download CSV Template",
    data=pd.DataFrame(columns=feature_names).to_csv(index=False),
    file_name="template.csv",
    mime="text/csv"
)
if clear_history:
    st.session_state.predictions = []

# Single prediction
#st.markdown('<div class="subheader">Single Prediction</div>', unsafe_allow_html=True)
with st.form(key='single_prediction_form'):
    st.markdown("Enter feature values (hover for recommended ranges):")
    cols = st.columns(3)
    input_data = {}
    for i, feature in enumerate(feature_names):
        with cols[i % 3]:
            min_val, max_val = feature_ranges[feature]
            step = 0.1 if feature not in ['cases', 'uvindex', 'conditions', 'stations'] else 1.0
            input_data[feature] = st.number_input(
                feature,
                min_value=min_val,
                max_value=max_val,
                value=(min_val + max_val) / 2,
                step=step,
                format="%.2f",
                help=f"Recommended range: {min_val} to {max_val}",
                key=f"single_{feature}"
            )
    submit_button = st.form_submit_button("🚀 Predict Risk")

# Process single prediction
if submit_button:
    with st.spinner("Analyzing data..."):
        input_df = pd.DataFrame([input_data], columns=feature_names)
        try:
            input_scaled = scaler.transform(input_df)
            input_transformed = pt.transform(input_scaled)
            input_poly = poly.transform(input_transformed)
            prediction = model.predict(input_poly)
            predicted_label = label_encoder.inverse_transform(np.round(prediction).astype(int))[0]
            st.markdown(f'<div class="stSuccess">✅ Predicted Risk Level: <strong>{predicted_label}</strong></div>', unsafe_allow_html=True)
            st.session_state.predictions.append({'Input': input_data, 'Prediction': predicted_label})
            st.session_state.input_valid = True
        except Exception as e:
            st.markdown(f'<div class="stError">❌ Prediction Error: {str(e)}</div>', unsafe_allow_html=True)
            st.session_state.input_valid = False

# Batch prediction
st.markdown('<div class="subheader">Batch Prediction</div>', unsafe_allow_html=True)
uploaded_file = st.file_uploader("Upload a CSV file with all features (use template from sidebar)", type="csv")
if uploaded_file:
    try:
        batch_df = pd.read_csv(uploaded_file)
        if set(feature_names).issubset(batch_df.columns):
            with st.spinner("Processing batch predictions..."):
                batch_scaled = scaler.transform(batch_df[feature_names])
                batch_transformed = pt.transform(batch_scaled)
                batch_poly = poly.transform(batch_transformed)
                batch_predictions = model.predict(batch_poly)
                batch_labels = label_encoder.inverse_transform(np.round(batch_predictions).astype(int))
                batch_df['Predicted_Risk'] = batch_labels
                st.write("Batch Prediction Results:")
                st.dataframe(batch_df, use_container_width=True)
                csv = batch_df.to_csv(index=False)
                b64 = base64.b64encode(csv.encode()).decode()
                href = f'<a href="data:file/csv;base64,{b64}" download="batch_predictions.csv">📥 Download Results</a>'
                st.markdown(href, unsafe_allow_html=True)
        else:
            st.markdown(f'<div class="stError">❌ CSV must include all features: {', '.join(feature_names)}</div>', unsafe_allow_html=True)
    except Exception as e:
        st.markdown(f'<div class="stError">❌ Batch Processing Error: {str(e)}</div>', unsafe_allow_html=True)

# Visualizations
if show_visualizations and st.session_state.input_valid:
    st.markdown('<div class="subheader">Data Insights</div>', unsafe_allow_html=True)
    try:
        df = pd.read_csv('https://drive.google.com/uc?id=1BYbbHENjD7sVotwaggdkQTsW9wyiQc1S')
        df.drop('serial', axis=1, inplace=True, errors='ignore')
        key_features = ['temp', 'humidity', 'precip', 'cases']
        for feature in key_features:
            fig = px.histogram(df, x=feature, nbins=20, title=f'{feature} Distribution',
                              color_discrete_sequence=['var(--accent)'], marginal='box')
            fig.add_vline(x=input_data[feature], line_dash="dash", line_color="#dc2626", 
                         annotation_text="Your Input", annotation_position="top right")
            fig.update_layout(showlegend=False, plot_bgcolor='rgba(0,0,0,0)', paper_bgcolor='rgba(0,0,0,0)', 
                             font=dict(size=12, color='var(--text)'), 
                             title_font=dict(size=16, color='var(--primary)', weight='bold'),
                             margin=dict(l=40, r=40, t=60, b=40))
            st.plotly_chart(fig, use_container_width=True)
    except Exception as e:
        st.markdown(f'<div class="stError">⚠️ Unable to load dataset for visualization: {str(e)}</div>', unsafe_allow_html=True)

# Feature importance
if show_feature_importance:
    st.markdown('<div class="subheader">Feature Importance</div>', unsafe_allow_html=True)
    importance = model.feature_importances_[:len(feature_names)]
    fig = px.bar(x=importance, y=feature_names, orientation='h', title='Feature Importance in Risk Prediction',
                 color=importance, color_continuous_scale='Blues')
    fig.update_layout(xaxis_title='Importance Score', yaxis_title='Features', showlegend=False,
                      font=dict(size=12, color='var(--text)'), 
                      title_font=dict(size=16, color='var(--primary)', weight='bold'),
                      margin=dict(l=40, r=40, t=60, b=40))
    st.plotly_chart(fig, use_container_width=True)

# Prediction history
if st.session_state.predictions:
    st.markdown('<div class="subheader">Prediction History</div>', unsafe_allow_html=True)
    history_df = pd.DataFrame([{'Prediction': p['Prediction'], **p['Input']} for p in st.session_state.predictions])
    st.dataframe(history_df, use_container_width=True)
    csv = history_df.to_csv(index=False)
    b64 = base64.b64encode(csv.encode()).decode()
    href = f'<a href="data:file/csv;base64,{b64}" download="prediction_history.csv">📥 Download History</a>'
    st.markdown(href, unsafe_allow_html=True)

# Instructions
with st.expander("📚 User Guide & About", expanded=False):
    st.markdown("""
    ### User Guide
    1. **Single Prediction**: Enter feature values and click **Predict Risk** to view the risk level (e.g., Minimal to No Risk, Low Risk).
    2. **Batch Prediction**: Upload a CSV with all required features (download template from sidebar).
    3. **Visualizations**: Enable to compare inputs with training data distributions.
    4. **Feature Importance**: Analyze key drivers of predictions.
    5. **Tips**: Hover over inputs for recommended ranges to ensure accuracy.
    """)

# Footer
#st.markdown('<div class="footer">© 2025 xAI | Weather Risk Predictor v6.0 | Crafted with Streamlit</div>', unsafe_allow_html=True)
