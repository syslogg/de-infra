#!/bin/bash

# setup.sh - Script para inicializar o ambiente no WSL2

echo "🚀 Configurando ambiente Data Lake com MinIO, Trino e Hive Metastore (WSL2)"

# Verificar se está rodando no WSL2
if grep -qi microsoft /proc/version; then
    echo "✅ WSL2 detectado"
    WSL_HOST_IP=$(grep nameserver /etc/resolv.conf | awk '{print $2}')
    echo "🌐 IP do host Windows: $WSL_HOST_IP"
else
    echo "⚠️  WSL2 não detectado, mas continuando..."
fi

# Criar estrutura de diretórios
echo "📁 Criando estrutura de diretórios..."
mkdir -p config/trino/catalog
mkdir -p config

# Verificar se Docker está rodando
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker não está rodando. No WSL2, certifique-se que:"
    echo "   1. Docker Desktop está rodando no Windows"
    echo "   2. A integração WSL2 está habilitada"
    echo "   3. Sua distribuição WSL está habilitada no Docker Desktop"
    exit 1
fi

echo "✅ Docker está rodando"

# Criar configurações do Hive
echo "📝 Criando configurações do Hive Metastore..."

cat > config/hive-site.xml << 'EOF'
<?xml version="1.0"?>
<configuration>
  <!-- Database Configuration -->
  <property>
    <n>javax.jdo.option.ConnectionURL</n>
    <value>jdbc:postgresql://postgres:5432/metastore</value>
  </property>
  
  <property>
    <n>javax.jdo.option.ConnectionDriverName</n>
    <value>org.postgresql.Driver</value>
  </property>
  
  <property>
    <n>javax.jdo.option.ConnectionUserName</n>
    <value>hive</value>
  </property>
  
  <property>
    <n>javax.jdo.option.ConnectionPassword</n>
    <value>hive123</value>
  </property>

  <!-- S3/MinIO Configuration -->
  <property>
    <n>fs.s3a.endpoint</n>
    <value>http://minio:9000</value>
  </property>
  
  <property>
    <n>fs.s3a.access.key</n>
    <value>admin</value>
  </property>
  
  <property>
    <n>fs.s3a.secret.key</n>
    <value>admin123</value>
  </property>
  
  <property>
    <n>fs.s3a.path.style.access</n>
    <value>true</value>
  </property>
  
  <property>
    <n>fs.s3a.impl</n>
    <value>org.apache.hadoop.fs.s3a.S3AFileSystem</value>
  </property>

  <!-- Warehouse Configuration -->
  <property>
    <n>hive.metastore.warehouse.dir</n>
    <value>/tmp/warehouse</value>
    <description>Local warehouse directory for metastore initialization</description>
  </property>
  
  <property>
    <n>hive.metastore.uris</n>
    <value>thrift://hive-metastore:9083</value>
  </property>
  
  <!-- Schema Validation -->
  <property>
    <n>hive.metastore.schema.verification</n>
    <value>false</value>
  </property>
  
  <property>
    <n>datanucleus.schema.autoCreateAll</n>
    <value>true</value>
  </property>
  
  <property>
    <n>hive.metastore.schema.verification.record.version</n>
    <value>false</value>
  </property>
</configuration>
EOF

cat > config/core-site.xml << 'EOF'
<?xml version="1.0"?>
<configuration>
  <!-- S3A Configuration -->
  <property>
    <n>fs.s3a.endpoint</n>
    <value>http://minio:9000</value>
  </property>
  
  <property>
    <n>fs.s3a.access.key</n>
    <value>admin</value>
  </property>
  
  <property>
    <n>fs.s3a.secret.key</n>
    <value>admin123</value>
  </property>
  
  <property>
    <n>fs.s3a.path.style.access</n>
    <value>true</value>
  </property>
  
  <property>
    <n>fs.s3a.connection.ssl.enabled</n>
    <value>false</value>
  </property>
  
  <property>
    <n>fs.s3a.impl</n>
    <value>org.apache.hadoop.fs.s3a.S3AFileSystem</value>
  </property>
  
  <!-- Default FS Configuration -->
  <property>
    <n>fs.defaultFS</n>
    <value>file:///</value>
  </property>
</configuration>
EOF

# Criar configurações do Trino
echo "📝 Criando configurações do Trino..."

cat > config/trino/config.properties << EOF
coordinator=true
node-scheduler.include-coordinator=true
http-server.http.port=8080
discovery.uri=http://localhost:8080
query.max-memory=2GB
query.max-memory-per-node=1GB
discovery.sharing-enabled=true
EOF

cat > config/trino/node.properties << EOF
node.environment=development
node.id=trino-coordinator
node.data-dir=/data/trino
EOF

cat > config/trino/jvm.config << EOF
-server
-Xmx2G
-XX:InitialRAMPercentage=80
-XX:MaxRAMPercentage=80
-XX:G1HeapRegionSize=32M
-XX:+ExplicitGCInvokesConcurrent
-XX:+ExitOnOutOfMemoryError
-XX:+UseG1GC
-XX:-UseBiasedLocking
-XX:ReservedCodeCacheSize=256M
-XX:PerMethodRecompilationCutoff=10000
-XX:PerBytecodeRecompilationCutoff=10000
-Djdk.attach.allowAttachSelf=true
-Djdk.nio.maxCachedBufferSize=2000000
-XX:+UnlockDiagnosticVMOptions
-XX:G1NumCollectionsKeepPinned=10000000
EOF

cat > config/trino/catalog/hive.properties << EOF
connector.name=hive
hive.metastore.uri=thrift://hive-metastore:9083
hive.s3.endpoint=http://minio:9000
hive.s3.path-style-access=true
hive.s3.ssl.enabled=false
hive.s3.aws-access-key=admin
hive.s3.aws-secret-key=admin123
hive.allow-drop-table=true
hive.allow-rename-table=true
hive.storage-format=PARQUET
hive.compression-codec=SNAPPY
EOF

cat > config/trino/catalog/memory.properties << EOF
connector.name=memory
memory.max-data-per-node=128MB
EOF

# Criar bucket no MinIO via script Python
cat > setup_minio.py << 'EOF'
#!/usr/bin/env python3
import time
import requests
from minio import Minio
from minio.error import BucketAlreadyOwnedByYou, BucketAlreadyExists

def setup_minio():
    print("⏳ Aguardando MinIO ficar disponível...")
    
    # Aguardar MinIO ficar disponível
    max_retries = 30
    for i in range(max_retries):
        try:
            response = requests.get("http://localhost:9000/minio/health/live", timeout=5)
            if response.status_code == 200:
                break
        except:
            pass
        time.sleep(2)
        if i == max_retries - 1:
            print("❌ MinIO não ficou disponível")
            return False
    
    print("✅ MinIO está disponível")
    
    # Configurar cliente MinIO
    client = Minio(
        "localhost:9000",
        access_key="admin",
        secret_key="admin123",
        secure=False
    )
    
    # Criar bucket warehouse
    try:
        client.make_bucket("warehouse")
        print("✅ Bucket 'warehouse' criado com sucesso")
    except BucketAlreadyOwnedByYou:
        print("ℹ️  Bucket 'warehouse' já existe")
    except BucketAlreadyExists:
        print("ℹ️  Bucket 'warehouse' já existe")
    
    # Criar bucket para dados de exemplo
    try:
        client.make_bucket("data")
        print("✅ Bucket 'data' criado com sucesso")
    except BucketAlreadyOwnedByYou:
        print("ℹ️  Bucket 'data' já existe")
    except BucketAlreadyExists:
        print("ℹ️  Bucket 'data' já existe")
    
    return True

if __name__ == "__main__":
    setup_minio()
EOF

echo "📦 Iniciando serviços..."
docker-compose up -d

echo "⏳ Aguardando serviços ficarem prontos (pode demorar mais no WSL2)..."
echo "   Isso pode levar 2-3 minutos no primeiro startup..."

# Aguardar mais tempo no WSL2
sleep 45

# Verificar status dos serviços
echo "🔍 Verificando status dos serviços..."
docker-compose ps

# Aguardar MinIO especificamente
echo "⏳ Aguardando MinIO ficar disponível..."
for i in {1..30}; do
    if curl -f -s http://localhost:9000/minio/health/live > /dev/null 2>&1; then
        echo "✅ MinIO está pronto"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "⚠️  MinIO demorou para ficar pronto, mas continuando..."
    fi
    sleep 2
done

# Verificar se Python está disponível e instalar dependências se necessário
if command -v python3 &> /dev/null; then
    echo "🐍 Configurando buckets no MinIO..."
    pip3 install minio requests 2>/dev/null || echo "⚠️  Instale as dependências: pip install minio requests"
    python3 setup_minio.py
else
    echo "⚠️  Python3 não encontrado. Configure os buckets manualmente via web interface"
fi

echo ""
echo "🎉 Ambiente configurado com sucesso no WSL2!"
echo ""
echo "📋 Serviços disponíveis:"
echo "   • MinIO Web UI: http://localhost:9001 (admin/admin123)"
echo "   • MinIO API: http://localhost:9000"
echo "   • Trino Web UI: http://localhost:8080"
echo "   • Hive Metastore: localhost:9083"
echo "   • PostgreSQL: localhost:5432 (hive/hive123)"
echo ""
echo "🔧 Para testar o Trino no WSL2:"
echo "   docker exec -it trino-coordinator trino"
echo "   Então execute: SHOW CATALOGS;"
echo ""
echo "📊 Para verificar logs se algo não funcionar:"
echo "   docker-compose logs trino"
echo "   docker-compose logs hive-metastore"
echo "   docker-compose logs minio"
echo ""
echo "🌐 DICA WSL2: Se não conseguir acessar do Windows:"
echo "   Use: http://\$(hostname -I | awk '{print \$1}'):9001 no Windows"
echo "   Ou configure port forwarding: netsh interface portproxy add..."
echo ""
echo "🛑 Para parar os serviços:"
echo "   docker-compose down"
echo ""
echo "🧹 Para limpar tudo (cuidado, remove dados!):"
echo "   docker-compose down -v"
EOF