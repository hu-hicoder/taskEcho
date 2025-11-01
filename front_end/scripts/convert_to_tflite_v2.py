"""
Convert Japanese Sentence-BERT model to TFLite format
Using transformers TFAutoModel for direct conversion
"""
import os
import numpy as np
from transformers import AutoTokenizer, TFAutoModel
import tensorflow as tf

# Model name
MODEL_NAME = "sonoisa/sentence-bert-base-ja-mean-tokens-v2"

# Output directories
TFLITE_PATH = "../assets/models/sentence_bert_ja.tflite"

# Create directories
os.makedirs("../assets/models", exist_ok=True)

print("Step 1: Loading TensorFlow model...")
tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)
model = TFAutoModel.from_pretrained(MODEL_NAME, from_pt=True)

print(f"Model loaded successfully")

# Prepare dummy input for shape inference
print("\nStep 2: Preparing dummy input for conversion...")
dummy_text = "これはテストです。"
encoded = tokenizer(dummy_text, return_tensors="tf", padding="max_length", max_length=128, truncation=True)
input_ids = encoded['input_ids']
attention_mask = encoded['attention_mask']

print(f"Input IDs shape: {input_ids.shape}")
print(f"Attention mask shape: {attention_mask.shape}")

# Test the model
print("\nStep 3: Testing TensorFlow model...")
outputs = model(input_ids=input_ids, attention_mask=attention_mask)
print(f"Output shape: {outputs.last_hidden_state.shape}")

# Create a concrete function for conversion
print("\nStep 4: Creating concrete function...")

class BertEmbeddingModel(tf.keras.Model):
    def __init__(self, bert_model):
        super(BertEmbeddingModel, self).__init__()
        self.bert = bert_model
    
    @tf.function(input_signature=[
        tf.TensorSpec(shape=[None, 128], dtype=tf.int32, name='input_ids'),
        tf.TensorSpec(shape=[None, 128], dtype=tf.int32, name='attention_mask')
    ])
    def call(self, input_ids, attention_mask):
        outputs = self.bert(input_ids=input_ids, attention_mask=attention_mask)
        # Mean pooling
        token_embeddings = outputs.last_hidden_state
        attention_mask_expanded = tf.cast(
            tf.expand_dims(attention_mask, -1), tf.float32
        )
        sum_embeddings = tf.reduce_sum(token_embeddings * attention_mask_expanded, axis=1)
        sum_mask = tf.clip_by_value(tf.reduce_sum(attention_mask_expanded, axis=1), 1e-9, tf.float32.max)
        embeddings = sum_embeddings / sum_mask
        return embeddings

embedding_model = BertEmbeddingModel(model)

# Test the embedding model
print("\nStep 5: Testing embedding model...")
test_embedding = embedding_model(input_ids, attention_mask)
print(f"Embedding shape: {test_embedding.shape}")
print(f"Embedding sample: {test_embedding[0][:5]}")

# Convert to TFLite
print("\nStep 6: Converting to TFLite...")
converter = tf.lite.TFLiteConverter.from_keras_model(embedding_model)

# Optimization options
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.target_spec.supported_types = [tf.float16]  # Use FP16 for smaller model size

# Convert
print("Converting... (this may take a few minutes)")
tflite_model = converter.convert()

# Save TFLite model
with open(TFLITE_PATH, 'wb') as f:
    f.write(tflite_model)

print(f"\nTFLite model saved to: {TFLITE_PATH}")
print(f"TFLite model size: {len(tflite_model) / 1024 / 1024:.2f} MB")

# Test the TFLite model
print("\nStep 7: Testing TFLite model...")
interpreter = tf.lite.Interpreter(model_path=TFLITE_PATH)
interpreter.allocate_tensors()

# Get input and output details
input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

print("\nInput details:")
for detail in input_details:
    print(f"  Name: {detail['name']}, Shape: {detail['shape']}, Type: {detail['dtype']}")

print("\nOutput details:")
for detail in output_details:
    print(f"  Name: {detail['name']}, Shape: {detail['shape']}, Type: {detail['dtype']}")

# Test inference
print("\nStep 8: Testing inference...")
test_text = "日本語のテキストです。"
test_encoded = tokenizer(test_text, return_tensors="np", padding="max_length", max_length=128, truncation=True)

# Set input tensors
interpreter.set_tensor(input_details[0]['index'], test_encoded['input_ids'].astype(np.int32))
interpreter.set_tensor(input_details[1]['index'], test_encoded['attention_mask'].astype(np.int32))

# Run inference
interpreter.invoke()

# Get output
output_data = interpreter.get_tensor(output_details[0]['index'])
print(f"Output embedding shape: {output_data.shape}")
print(f"Output embedding sample: {output_data[0][:5]}")

print("\n✅ Conversion completed successfully!")
print(f"Final model: {TFLITE_PATH}")
print(f"Model size: {len(tflite_model) / 1024 / 1024:.2f} MB")
