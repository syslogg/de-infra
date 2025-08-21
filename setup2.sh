#!/bin/bash

# fix_hive.sh - Script para corrigir o problema do Hive Metastore

echo "🔧 Corrigindo problema do Hive Metastore..."

# Parar os serviços
echo "⏹️  Parando serviços..."
docker-compose down

# Limpar volumes se necessário (cuidado!)
echo "🧹 Limpando dados antigos..."
read -p "Deseja limpar os volumes existentes? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    docker-compose down -v
    echo "✅ Volumes limpos"
fi

# Criar/recriar estrutura de diretórios
echo "📁 Recriando estrutura..."
mkdir -p config/trino/catalog
mkdir -p config

# Criar configurações corrigidas
echo "📝 Criando configurações corrigidas..."

# hive-site.xml corrigido
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

  <!-- Warehouse Configuration - SEM S3A para inicialização -->
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

# core-site.xml para S3A
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

echo "🚀 Iniciando serviços com configuração corrigida..."
docker-compose up -d

echo "⏳ Aguardando serviços (isso pode demorar alguns minutos)..."
echo "   O Hive Metastore agora vai baixar as bibliotecas S3A automaticamente..."

# Mostrar logs do Hive Metastore para acompanhar o progresso
echo "📋 Acompanhando logs do Hive Metastore (Ctrl+C para sair)..."
echo "   Procure por: 'Starting Hive Metastore Server'"
sleep 10
docker-compose logs -f hive-metastore

echo ""
echo "✅ Fix aplicado! Os problemas resolvidos:"
echo "   • PostgreSQL downgrade para v11 (compatibilidade)"
echo "   • Hive atualizado para v4.0.0 com S3A incluído"  
echo "   • Bibliotecas S3A baixadas automaticamente"
echo "   • Warehouse inicializado localmente, S3A disponível para tabelas"
echo ""
echo "🔧 Para testar:"
echo "   docker exec -it trino-coordinator trino"
echo "   SHOW CATALOGS;"