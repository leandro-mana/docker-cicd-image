#!/usr/bin/env bash
##############################################################################################
# This script is used to deploy the following supported technologies:                        #
#   - Cloudformation templates for terraform state                                           #
#   - Terraform manifests                                                                    #
# For multiple enviroments, in automation fashion during CICD.                               #
# as STRING INPUT usually expected from Makefile, in the following form                      #
# <DEPLOYMENT>/<ACTION>/<ENVIRONMENT>                                                        #
#    - DEPLOYMENT:  The deployment type supported, cfn (Cloudformation), tf (Terraform)      #
#    - ACTION:      The supported action depending on TYPE (check case statement at the end) #
#    - ENVIRONMENT: The environment to deploy, and AWS Account check will be run             #
#                                                                                            #
# The Following AWS Environmental Variables are expected                                     #
# - AWS_DEFAULT_REGION:    The AWS default region to Deploy                                  #
# - AWS_ACCESS_KEY_ID:     The AWS Access API Key                                            #
# - AWS_SECRET_ACCESS_KEY: The AWS Secret API Key                                            #
# - AWS_ACCOUNT_ID:        The AWS Account Id to Deploy (this will be checked for security)  #
#                                                                                            #
# Repo Source Dir, its expected that the invocation of this wrapper whether if its via Make  #
# or straight happens from the source folder of the repo, any directory used will be         #
# relative to that.                                                                          #
# As the base infrastructure for Terraform State (remote backend) is via Cloudformation,     #
# then the minimum set of variables needed to glue both infrastructure providers comes from  #
# the Cloudformation configuration definition, which is the "Project" parameter, to scale    #
# this pattern in a monorepo, each microservice that defines infrastructure will have its    #
# own set of remote state infrastructure, hence the cfn stack plus the terraform definitions #
#                                                                                            #
# This Script will exit if any of bellow happens                                             #
# nounset: Attempting to use a variable that is not defined                                  #
##############################################################################################
set -o nounset

# Repo Source Dir
SRC=${PWD}

# Deployment type, action and environment
DEPLOYMENT=$(echo $1 | awk -F\/ '{print $1}')
ACTION=$(echo $1 | awk -F\/ '{print $2}')
ENV=$(echo $1 | awk -F\/ '{print $3}')

# Run AWS Check for Environment and AccountId
AWS_REGION=${AWS_DEFAULT_REGION}
echo "Checking AWS Account Environment..."
USED_ACCOUNT=$(aws sts get-caller-identity --query "Account" --output text)
if [[ ! " ${AWS_ACCOUNT_ID} " == " ${USED_ACCOUNT} " ]]; then
    echo "AWS Account does not match with Environment"
    exit 1
fi

# Basic project configuration
CFN_CONF_FILE="cloudformation/config/${ENV}.json"
PROJECT=$(jq -r '.Parameters.Project' < "${CFN_CONF_FILE}")
STACK_NAME="${PROJECT}-${ENV}"

# Function definitions
function cfn_deploy {
    PARAMETERS=()
    PARAMETERS+=($(jq -r '.Parameters | keys[] as $k | "\($k)=\(.[$k])"' "${CFN_CONF_FILE}"))
    TAGS=($(jq -r '.Tags | keys[] as $k | "\($k)=\(.[$k])"' "${CFN_CONF_FILE}"))

    aws cloudformation deploy \
        --template-file cloudformation/template.yaml \
        --stack-name ${STACK_NAME} \
        --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND --no-fail-on-empty-changeset \
        --parameter-overrides "${PARAMETERS[@]}" \
        --tags "${TAGS[@]}"

}


function tf_init_vars {
    TF_REPO_DIR=${TF_REPO_DIR:-'terraform'}
    S3_TF_STATE_EXPORT_NAME=${STACK_NAME}-tf-state-s3-name
    DDB_TF_STATE_EXPORT_NAME=${STACK_NAME}-tf-state-ddb-name
    S3_TF_STATE=$(aws cloudformation describe-stacks \
        --no-paginate \
        --stack-name ${STACK_NAME} \
        --query "Stacks[0].Outputs[?ExportName == \`${S3_TF_STATE_EXPORT_NAME}\`].OutputValue" \
        --output text)

    DDB_TF_STATE=$(aws cloudformation describe-stacks \
        --no-paginate \
        --stack-name ${STACK_NAME} \
        --query "Stacks[0].Outputs[?ExportName == \`${DDB_TF_STATE_EXPORT_NAME}\`].OutputValue" \
        --output text)

    ## TF Global Variables Declaration
    export TF_VAR_aws_region=${AWS_REGION}
    export TF_IN_AUTOMATION=true

    echo "TF folder: ${TF_REPO_DIR}"
    echo "TF State Bucket: ${S3_TF_STATE}"
    echo "TF State Bucket Key: ${PROJECT}/${ENV}/terraform.tfstate"
    echo "TF State DDB Table: ${DDB_TF_STATE}"
    echo "TF CICD AWS Region: ${AWS_REGION}"

}


function tf_init {
    # Function to initialize TF and validate static syntax
    echo "Terraform Init"
    if [ ! -d "${TF_REPO_DIR}" ]; then
        echo "Terraform Local Directory Not Found: ${TF_REPO_DIR}"
        exit 1
    fi

    VAR_FILE="${SRC}/${TF_REPO_DIR}/config/${ENV}.tfvars"
    if [ ! -f "${VAR_FILE}" ]; then
        echo "Terraform environment variables definition not found: ${VAR_FILE}"
        exit 1
    fi

    cd "${TF_REPO_DIR}"
    terraform init -input=false \
        -backend-config="bucket=${S3_TF_STATE}" \
        -backend-config="key=${PROJECT}/${ENV}/terraform.tfstate" \
        -backend-config="region=${AWS_REGION}" \
        -backend-config="dynamodb_table=${DDB_TF_STATE}"

    terraform validate
    cd ${SRC}

}


function tf_plan {
    # Function to run TF Plan
    echo "Terraform Plan"
    cd "${TF_REPO_DIR}"
    TF_PLAN_FILE='plan.out'
    terraform plan \
        -out=${TF_PLAN_FILE} \
        -var-file=${VAR_FILE} \
        -compact-warnings \
        -lock=true \
        -parallelism=100 \
        -input=false

    cd ${SRC}
}


function tf_deploy {
    # Function to TF Deploy
    echo "Terraform Apply"
    cd "${TF_REPO_DIR}"
    terraform apply -var-file=${VAR_FILE} \
        -auto-approve \
        -compact-warnings

    cd ${SRC}
}


function tf_destroy {
    # Function to Destroy TF infrastructure
    echo "Terraform Destroy"
    cd "${TF_REPO_DIR}"
    terraform destroy -var-file=${VAR_FILE} -auto-approve
    cd ${SRC}
}


function tf_cleanup {
    # Function to clean files as part of init/plan
    cd "${TF_REPO_DIR}"
    rm -f plan.out
    rm -f plan.out.json
    rm -rf .terraform.*
    cd ${SRC}
}

function tf_output {
    # Function to print ALL terraform outputs defined in the module
    cd "${TF_REPO_DIR}"
    terraform output
    cd ${SRC}
}

# Deploy flow definition
case ${DEPLOYMENT} in
    cfn)
        case ${ACTION} in
            deploy)
                cfn_deploy
            ;;
            *)
                echo "Cloudformation Action: ${ACTION} Not Supported"
                exit 1
            ;;
        esac
        ;;
    tf)
    case ${ACTION} in
        plan|deploy|destroy|output)
            tf_init_vars
            tf_init
            tf_plan
            if [ "${ACTION}" == 'deploy' ]; then
                tf_deploy
            fi

            if [ "${ACTION}" == 'destroy' ]; then
                tf_destroy
            fi
            if [ "${ACTION}" == 'output' ]; then
                tf_output
            fi            
            tf_cleanup
        ;;
        *)
            echo "Terraform Action: ${ACTION} Not Supported"
            exit 1
        ;;
    esac
    ;;
esac
