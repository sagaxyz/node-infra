import boto3
import sys

def get_or_create_oidc_provider(cluster_name, aws_profile='default', aws_region=''):
    session = boto3.Session(profile_name=aws_profile, region_name=aws_region)
    eks = session.client('eks')
    iam = session.client('iam')
    
    # Get the OIDC endpoint from the EKS cluster
    cluster = eks.describe_cluster(name=cluster_name)
    oidc_endpoint = cluster['cluster']['identity']['oidc']['issuer']

    # Check if the OIDC provider exists
    oidc_provider_arn = f"arn:aws:iam::{cluster['cluster']['arn'].split(':')[4]}:oidc-provider/{oidc_endpoint[8:]}"
    providers = iam.list_open_id_connect_providers()['OpenIDConnectProviderList']
    
    for provider in providers:
        if provider['Arn'] == oidc_provider_arn:
            print(f"OIDC provider exists: {oidc_provider_arn}")
            return oidc_provider_arn

    # Create the OIDC provider if it doesn't exist
    response = iam.create_open_id_connect_provider(
        Url=oidc_endpoint,
        ClientIDList=['sts.amazonaws.com'],
        ThumbprintList=['9e99a48a9960b14926bb7f3b02e22da2b0ab7280']
    )
    print(f"Created OIDC provider: {response['OpenIDConnectProviderArn']}")
    return response['OpenIDConnectProviderArn']

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: get_or_create_oidc_provider.py <cluster_name> <aws_profile_name> <aws_region>")
        sys.exit(1)

    cluster_name = sys.argv[1]
    aws_profile = sys.argv[2]
    aws_region = sys.argv[3]
    get_or_create_oidc_provider(cluster_name, aws_profile, aws_region)
