
zip firehoseDML.zip firehoseDML.py


$env:AWS_REGION="us-east-1"
$env:ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
$env:BUCKET_NAME="cn-p2-airports-$($env:ACCOUNT_ID)"
$env:ROLE_ARN=$(aws iam get-role --role-name LabRole --query 'Role.Arn' --output text)

# Crear el bucket
aws s3 mb s3://$env:BUCKET_NAME

# Crear carpetas (objetos vacíos con / al final)
aws s3api put-object --bucket $env:BUCKET_NAME --key raw/
aws s3api put-object --bucket $env:BUCKET_NAME --key processed/
aws s3api put-object --bucket $env:BUCKET_NAME --key config/
aws s3api put-object --bucket $env:BUCKET_NAME --key scripts/
aws s3api put-object --bucket $env:BUCKET_NAME --key queries/
aws s3api put-object --bucket $env:BUCKET_NAME --key errors/
aws kinesis create-stream --stream-name airports-stream --shard-count 1

# Lambda

aws lambda create-function --function-name airports-firehose-lambda --runtime python3.12 --role $env:ROLE_ARN --handler firehoseDML.lambda_handler --zip-file fileb://firehoseDML.zip --timeout 60 --memory-size 128
aws lambda update-function-code --function-name airports-firehose-lambda --zip-file fileb://firehoseDML.zip 


$env:LAMBDA_ARN=(aws lambda get-function --function-name airports-firehose-lambda --query 'Configuration.FunctionArn' --output text)

# Firehose
aws firehose create-delivery-stream --delivery-stream-name airports-delivery-stream --delivery-stream-type KinesisStreamAsSource --kinesis-stream-source-configuration ("KinesisStreamARN=arn:aws:kinesis:" + $env:AWS_REGION + ":" + $env:ACCOUNT_ID + ":stream/airports-stream,RoleARN=" + $env:ROLE_ARN) --extended-s3-destination-configuration ('{\"BucketARN\":\"arn:aws:s3:::' + $env:BUCKET_NAME + '\",\"RoleARN\":\"' + $env:ROLE_ARN + '\",\"Prefix\":\"raw/\",\"ErrorOutputPrefix\":\"errors/\",\"BufferingHints\":{\"SizeInMBs\":1,\"IntervalInSeconds\":60},\"ProcessingConfiguration\":{\"Enabled\":true,\"Processors\":[{\"Type\":\"Lambda\",\"Parameters\":[{\"ParameterName\":\"LambdaArn\",\"ParameterValue\":\"' + $env:LAMBDA_ARN + '\"},{\"ParameterName\":\"BufferSizeInMBs\",\"ParameterValue\":\"1\"},{\"ParameterName\":\"BufferIntervalInSeconds\",\"ParameterValue\":\"60\"}]}]}}')


#Base de datos
aws glue create-database --database-input '{\"Name\": \"airports_db\"}'

#Crawler
aws glue create-crawler --name airports-raw-crawler --role $env:ROLE_ARN --database-name airports_db --targets ('{\"S3Targets\": [{\"Path\": \"s3://' + $env:BUCKET_NAME + '/raw/\"}]}')

aws glue start-crawler --name airports-raw-crawler

#Script para crear el Job

aws s3 cp airports_aggregation_daily.py s3://$env:BUCKET_NAME/scripts/
aws s3 cp airports_aggregation_monthly.py s3://$env:BUCKET_NAME/scripts/

$env:DATABASE="airports_db"
$env:TABLE_INPUT="raw"
#Crear el Job
aws glue create-job --name airports-daily-aggregation --role $env:ROLE_ARN --glue-version "4.0" --number-of-workers 2 --worker-type "G.1X" --command ('{\"Name\": \"glueetl\", \"ScriptLocation\": \"s3://' + $env:BUCKET_NAME + '/scripts/airports_aggregation_daily.py\", \"PythonVersion\": \"3\"}') --default-arguments ('{\"--database\": \"' + $env:DATABASE + '\", \"--table\": \"' + $env:TABLE_INPUT + '\", \"--output_path\": \"s3://' + $env:BUCKET_NAME + '/processed/airports_daily/\", \"--enable-continuous-cloudwatch-log\": \"true\"}')
aws glue create-job --name airports-monthly-aggregation --role $env:ROLE_ARN --glue-version "4.0" --number-of-workers 2 --worker-type "G.1X" --command ('{\"Name\": \"glueetl\", \"ScriptLocation\": \"s3://' + $env:BUCKET_NAME + '/scripts/airports_aggregation_monthly.py\", \"PythonVersion\": \"3\"}') --default-arguments ('{\"--database\": \"' + $env:DATABASE + '\", \"--table\": \"' + $env:TABLE + '\", \"--output_path\": \"s3://' + $env:BUCKET_NAME + '/processed/airports_monthly/\", \"--enable-continuous-cloudwatch-log\": \"true\"}')


aws glue start-job-run --job-name airports-daily-aggregation
aws glue start-job-run --job-name airports-monthly-aggregation

