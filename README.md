# Práctica Entregable 2: Computación en la Nube  
## Pipeline de Datos Serverless para Análisis de Tráfico Aéreo en AWS

## Descripción
Este proyecto implementa una arquitectura de datos completa en la nube de AWS para la ingesta, almacenamiento, procesamiento y análisis de datos de aeropuertos en tiempo real.

El objetivo es capturar información sobre conexiones aéreas y países, procesarla automáticamente mediante servicios *Serverless* y generar reportes agregados (diarios y mensuales) listos para ser consultados mediante SQL.

## Arquitectura
El flujo de datos sigue el siguiente recorrido:

1. **Generación**  
   Un script en Python simula el envío de datos de aeropuertos.

2. **Ingesta**  
   Amazon Kinesis Data Streams recibe los datos en tiempo real.

3. **Buffer y Entrega**  
   Amazon Kinesis Firehose agrupa los datos y utiliza una función AWS Lambda para transformarlos (añadir saltos de línea y *timestamp*).

4. **Almacenamiento (Raw)**  
   Los datos crudos se guardan en Amazon S3 (`/raw`).

5. **Catalogación**  
   AWS Glue Crawler descubre el esquema de los datos.

6. **Procesamiento (ETL)**  
   AWS Glue Jobs (Spark) limpian y agregan los datos.

7. **Almacenamiento (Processed)**  
   Los resultados se guardan en formato Parquet (`/processed`).

8. **Análisis**  
   Consultas interactivas mediante Amazon Athena.

## Estructura del Proyecto
- `kinesis.py`: Script productor que envía datos simulados al stream.  
- `firehoseDML.py`: Código de la función Lambda para transformar los registros antes de guardarlos.  
- `airports_aggregation_daily.py`: Script ETL de Spark para el reporte diario.  
- `airports_aggregation_monthly.py`: Script ETL de Spark para el reporte mensual.  
- `commands.ps1` / `script.sh`: Comandos de AWS CLI para desplegar la infraestructura.

## Pasos para Desplegar

### 1. Prerrequisitos
- Tener configurado AWS CLI con las credenciales de **LabRole**.  
- Tener Python 3 instalado.  
- Tener acceso a la consola de AWS.

### 2. Configuración del Entorno
- Definir las variables de entorno principales (Bucket, Role ARN, Region) en la terminal.

### 3. Creación de Infraestructura
Ejecutar los comandos para:
- Crear el bucket S3 y las carpetas (`raw/`, `processed/`, `scripts/`).  
- Crear el stream de Kinesis y el Firehose.  
- Desplegar la función Lambda y vincularla al Firehose.

### 4. Generación de Datos
Ejecutar el script productor para enviar datos a la nube:

```bash
    python kinesis.py
```
Verificar que los archivos `.json` comienzan a aparecer en la carpeta `raw/` del bucket S3.

### 5. Catalogación y ETL
- **Crawler**: Ejecutar el Crawler de Glue para que detecte la tabla *raw* en la base de datos `airports_db`.
- **Subir Scripts**: Copiar los archivos `.py` de agregación a la carpeta `s3://.../scripts/`.
- **Glue Jobs**: Crear y lanzar los Jobs `airports-daily-aggregation` y `airports-monthly-aggregation`.

### 6. Resultados
Una vez finalizados los Jobs (estado `SUCCEEDED`), los datos procesados estarán disponibles en S3 y podrán consultarse en Amazon Athena:
```bash
    SELECT country, total_enlaces
    FROM "airports_db"."airports_daily"
    ORDER BY total_enlaces DESC;
```

## Tecnologías Utilizadas
- **Lenguajes**: Python (Boto3), PySpark, SQL.
- **AWS Services**: S3, Kinesis, Lambda, Glue, IAM.

  
Desarrollado por: Daniel Moreno López
Computación en la Nube – **ULPGC**
