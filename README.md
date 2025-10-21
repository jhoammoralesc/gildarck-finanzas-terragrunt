# Configure terragrunt - GILDARCK

## ⚠️ ADVERTENCIA CRÍTICA ⚠️

**NUNCA usar perfiles de AWS que comiencen con `ic-` (ic-dev, ic-qa, ic-prod, ic-shared, ic-network, etc.)**

Estos perfiles pertenecen a **IBCOBROS** y están estrictamente prohibidos para el proyecto GILDARCK.

### Perfiles PROHIBIDOS:
- `ic-dev` ❌
- `ic-qa` ❌ 
- `ic-prod` ❌
- `ic-shared` ❌
- `ic-network` ❌
- `ic-uat` ❌
- `ic-root` ❌

## Prerequisites:

- [Install terraform.](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli "Install terraform.")
- [Install terragrunt.](https://terragrunt.gruntwork.io/docs/getting-started/install/ "Install terragrunt.")
- **Configure AWS credentials for GILDARCK project ONLY**

## AWS Configuration for GILDARCK:

Configure your AWS credentials using one of these methods:

### Option 1: AWS Configure
```bash
aws configure --profile gildarck-dev
```

### Option 2: Environment Variables
```bash
export AWS_ACCESS_KEY_ID=your_access_key
export AWS_SECRET_ACCESS_KEY=your_secret_key
export AWS_DEFAULT_REGION=us-east-1
```

### Option 3: AWS SSO (if available)
```bash
aws configure sso --profile gildarck-dev
```

## Execute plan command:

```bash
# Set profile for GILDARCK
export AWS_PROFILE=gildarck-dev

# validate
terragrunt run-all validate --terragrunt-non-interactive
# Plan
terragrunt run-all plan --terragrunt-non-interactive
```

## Configure environments:

In the case that you need to use a secret into a specific module, please don't put It directly inside the code, instead use environment variables:

- Edit the file ~/.bash_profile and put the environment variables that you need:
  The values of the following variables you will find inside the repository [variables and secrets section](https://github.com/ibcobros/infrastructure-iac-terragrunt/settings/secrets/actions "variables and secrets section").

```bash
export DEV_FIREBASE_API_KEY=
export DEV_MYSQL_PASSWORD=
export DEV_AMPLIFY_BASIC_AUTH_PASS=
export SHARED_POSTGRESS_PASSWORD=
export GIT_TOKEN=
export QA_MYSQL_PASSWORD=
export QA_AMPLIFY_BASIC_AUTH_PASS=
```

In case that you need add more variables plese remember edit this file.

## EKS

To deploy EKS is necessary the implementation of networking configuration with strategy Hub and Spoke

### Prerequisites

- Configuration Hub and Spoke architecture
- Configuration Transit gateway routes add VPC environment
- Role with permissions for deploy Cluster EKS

## Deploy EKS

For deployment EKS you have to instance module of this in the folder **_\_envcommon_** into environment that you need to deploy(env=dev,qa,uat...),

- Create folder eks -> eks-{env}-n in the Zone and Environment.
- Create file terragrunt.hcl into folder created.
- Setup inputs necessary for create cluster.

```terragrunt

inputs = {
  cluster_name                    = "${local.name}"
  cluster_version                 = "1.23"
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
  ...
  ...
  ...
}
```

### Execution terragrunt command bash

```bash

# Execute
# Validate
terragrunt run-all validate --terragrunt-non-interactive
# plan
terragrunt run-all plan --terragrunt-non-interactive
#apply
terragrunt run-all apply --terragrunt-non-interactive
-
```

#### Test cluster was create, add kube config in your local environment

```bash

aws eks list-clusters --profile ic-qa
aws eks update-kubeconfig --region us-east-1 --name eks-qa-1 --profile ic-qa > ~/.kube/ic-qa.yaml
export PATHKUBECONFIG=$KUBECONFIG:~/.kube/config:ic-shared.yaml:ic-dev.yaml:ic-qa.yaml
```
