import os
from google.cloud import storage
import google.auth

# Define o caminho para o arquivo de credenciais
# Nota: É uma boa prática usar variáveis de ambiente para credenciais em produção
# Para o teste, você pode usar um caminho fixo.
credentials_path = "vault-backups-11e33c76a79f.json"
os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = credentials_path

# Define o nome do bucket a ser testado
bucket_name = "us-east-1-syslogg-backups"

def test_gcs_access():
    """Tenta listar objetos no bucket usando as credenciais da Service Account."""
    print(f"Tentando acessar o bucket '{bucket_name}' com a conta de serviço...")
    
    try:
        # Tenta obter as credenciais automaticamente do caminho definido acima
        credentials, project = google.auth.default()
        print(f"Credenciais obtidas com sucesso para o projeto: {project}")

        # Cria um cliente do GCS
        storage_client = storage.Client()
        bucket = storage_client.bucket(bucket_name)

        # Tenta listar os objetos no bucket para verificar a permissão 'storage.objects.list'
        blobs = bucket.list_blobs(max_results=1)

        print("\nLista de objetos (máximo 1):")
        for blob in blobs:
            print(f" - {blob.name}")
        
        print("\n✅ Sucesso: A conta de serviço tem as permissões necessárias para listar objetos.")
        return True

    except Exception as e:
        print(f"\n❌ Erro: O acesso ao bucket falhou.")
        print(f"Detalhes do erro: {e}")
        # A mensagem de erro "AccessDenied" aparecerá aqui se a permissão estiver incorreta.
        return False

# Executa a função de teste
if __name__ == "__main__":
    test_gcs_access()