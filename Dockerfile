# Usa a imagem base do Apache Hive
FROM apache/hive:4.0.0

# Alterna para o usuário root para instalar os pacotes
USER root

# Instala o wget e outras dependências, se necessário
RUN apt-get update && apt-get install -y wget

# Adiciona as bibliotecas S3A necessárias
ENV HADOOP_AWS_VERSION=3.3.4
ENV AWS_SDK_VERSION=1.12.262
RUN wget -q https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/${HADOOP_AWS_VERSION}/hadoop-aws-${HADOOP_AWS_VERSION}.jar -O /opt/hive/lib/hadoop-aws-${HADOOP_AWS_VERSION}.jar && \
    wget -q https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/${AWS_SDK_VERSION}/aws-java-sdk-bundle-${AWS_SDK_VERSION}.jar -O /opt/hive/lib/aws-java-sdk-bundle-${AWS_SDK_VERSION}.jar

# Define a variável de ambiente para o driver PostgreSQL
ENV POSTGRES_JDBC_VERSION=42.2.23
ENV POSTGRES_JDBC_URL=https://jdbc.postgresql.org/download/postgresql-${POSTGRES_JDBC_VERSION}.jar

# Baixa o driver JDBC do PostgreSQL
RUN wget -q ${POSTGRES_JDBC_URL} -O /opt/hive/lib/postgresql-${POSTGRES_JDBC_VERSION}.jar

# Adiciona o driver JDBC ao HIVE_AUX_JARS_PATH
ENV HIVE_AUX_JARS_PATH=/opt/hive/lib/postgresql-${POSTGRES_JDBC_VERSION}.jar

# Retorna para o usuário padrão da imagem (hive) para o restante das operações
USER hive