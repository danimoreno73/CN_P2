import sys
import logging
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.utils import getResolvedOptions
from pyspark.sql.functions import col, sum as spark_sum, count, avg, substring, desc
from awsglue.dynamicframe import DynamicFrame

# Configuración de logs
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def main():
    args = getResolvedOptions(sys.argv, ['database', 'table', 'output_path'])
    database = args['database']
    table = args['table']
    output_path = args['output_path']
    
    sc = SparkContext()
    glueContext = GlueContext(sc)
    
    # Leer datos
    dynamic_frame = glueContext.create_dynamic_frame.from_catalog(
        database=database,
        table_name=table
    )
    df = dynamic_frame.toDF()
    
    df = df.withColumn("month", substring(col("processed_at"), 1, 7))
    
    # Agregación Mensual
    monthly_df = df.groupBy("month", "country") \
        .agg(
            spark_sum("links_count").alias("total_enlaces"),
            count("name").alias("cantidad_aeropuertos"),
            avg("links_count").alias("promedio_enlaces")
        ) \
        .orderBy("month", desc("total_enlaces"))
    

    output_dynamic_frame = DynamicFrame.fromDF(monthly_df, glueContext, "output")
    
    glueContext.write_dynamic_frame.from_options(
        frame=output_dynamic_frame,
        connection_type="s3",
        connection_options={"path": output_path},
        format="parquet",
        format_options={"compression": "snappy"}
    )
    
    logger.info("Agregación mensual completada.")

if __name__ == "__main__":
    main()