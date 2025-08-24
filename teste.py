import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq
import s3fs

# DataFrame fictício
df = pd.DataFrame({
    'id': range(1, 6),
    'nome': ['Ana', 'Bruno', 'Carlos', 'Diana', 'Eduardo'],
    'idade': [23, 35, 42, 29, 31]
})

# Configuração do MinIO/S3
fs = s3fs.S3FileSystem(
    key='admin',
    secret='admin123',
    client_kwargs={'endpoint_url': 'http://localhost:9000'}
)

# Caminho no bucket (ajuste o bucket e pasta conforme necessário)
parquet_path = 'bucket-test/teste_dataset/dados.parquet'

# Salvar no MinIO
with fs.open(parquet_path, 'wb') as f:
    table = pa.Table.from_pandas(df)
    pq.write_table(table, f)

print(f"Arquivo Parquet salvo em: s3://{parquet_path}")

# Exemplo de DDL para criar a tabela no Trino baseada no DataFrame
print("""
-- DDL para criar a tabela no Trino (ajuste o schema/catalog/bucket se necessário)
CREATE TABLE hive.bucket_test.teste_dataset (
    id INTEGER,
    nome VARCHAR,
    idade INTEGER
)
WITH (
    external_location = 's3a://bucket-test/teste_dataset/',
    format = 'PARQUET'
);
""")