import boto3
import json
import time
from loguru import logger
import datetime

STREAM_NAME = 'airports-stream' 
REGION = 'us-east-1'
INPUT_FILE = 'airports.json'  

kinesis = boto3.client('kinesis', region_name=REGION)

def load_data(file_path):
    with open(file_path, 'r', encoding='utf-8') as f: 
        return json.load(f)

def run_producer():
    
    data = load_data(INPUT_FILE)
    records_sent = 0
    
    logger.info(f"Iniciando transmisión al stream: {STREAM_NAME}...")
    
    
    for airport in data:
        try:
           
            payload = airport 
            
            pais = airport.get('country', 'Unknown')
            
            # Enviar a Kinesis
            response = kinesis.put_record(
                StreamName=STREAM_NAME,
                Data=json.dumps(payload),
                PartitionKey=pais 
            )
            
            records_sent += 1
            
            # Ver qué aeropuerto se envía
            logger.info(f"Registro enviado al shard {response['ShardId']}")
            logger.info(f"Enviado: {airport.get('name')} ({pais})")
            
            
            time.sleep(0.01) 
            
        except Exception as e:
            logger.error(f"Error enviando registro: {e}")

    logger.info(f"Fin de la transmisión. Total registros enviados: {records_sent}")

if __name__ == '__main__':
    run_producer()