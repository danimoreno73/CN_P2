import json
import base64
import datetime

def lambda_handler(event, context):
    output = []
    for record in event['records']:
        try:
           
            payload = base64.b64decode(record['data']).decode('utf-8')
            data_json = json.loads(payload)
            
            
            if 'country' not in data_json or not data_json['country']:
                output_record = {
                    'recordId': record['recordId'],
                    'result': 'Dropped',
                    'data': record['data']
                }
            else:
                
                processing_time = datetime.datetime.now(datetime.timezone.utc)
                data_json['processed_at'] = processing_time.isoformat()
                
                
                payload_transformed = json.dumps(data_json) + '\n'
                
                output_record = {
                    'recordId': record['recordId'],
                    'result': 'Ok',
                    'data': base64.b64encode(payload_transformed.encode('utf-8')).decode('utf-8')
                }
                
            output.append(output_record)

        except Exception as e:
            print(f"Error: {e}")
            output.append({
                'recordId': record['recordId'],
                'result': 'ProcessingFailed',
                'data': record['data']
            })
    
    return {'records': output}