pipeline {
  agent none

  parameters {
    choice(name: 'jobType', description: 'deploy or delete aws resources',
      choices: 'create\ndelete')
  }

  environment {
    AWS_DEFAULT_REGION = 'us-east-1'
  }

  stages {
    stage('Region Detection') {
      agent {
        docker {
          image 'node:8-alpine'
          args '-u root:root --entrypoint=\'\''
        }
      }

      steps {
        withCredentials([[
          $class: 'UsernamePasswordMultiBinding',
          credentialsId: 'region',
          usernameVariable: 'JENKINS_REGION',
          passwordVariable: 'DUMMY'
        ]]) {
          script {
            if (env.JENKINS_REGION == 'dev') {
              DETECTED_REGION = 'Development';
              REGION = 'dev'
              WORKSPACE = 'default'
              SUBNET_ID_PRIMARY = "subnet-b758e0fc"
              SUBNET_ID_SECONDARY = "subnet-85f20caa"
              SECURITY_GROUP = "sg-9c2cdde9"
              CUSTOMER_POOL_NAME = 'athene-portal-dev-customers'
              PRODUCER_POOL_NAME = 'athene-portal-dev-producers'
              ASSOCIATE_POOL_NAME = 'athene-portal-dev-associates'
            } else if (env.JENKINS_REGION == 'qa') {
              DETECTED_REGION = 'Quality Assurance';
              REGION = 'qa'
              WORKSPACE = 'qa'
              SUBNET_ID_PRIMARY = 'subnet-1c8e1078'
              SUBNET_ID_SECONDARY = 'subnet-7a519255'
              SECURITY_GROUP = 'sg-bdac5dc8'
              CUSTOMER_POOL_NAME = 'athene-portal-qa-customers'
              PRODUCER_POOL_NAME = 'athene-portal-qa-producers'
              ASSOCIATE_POOL_NAME = 'athene-portal-qa-associates'
            } else if (env.JENKINS_REGION == 'stage') {
              DETECTED_REGION = 'UAT Test';
              REGION = 'stage'
              WORKSPACE = 'stage'
              SUBNET_ID_PRIMARY = "subnet-7071585c"
              SUBNET_ID_SECONDARY = "subnet-eaaf41a1"
              SECURITY_GROUP = "sg-e412e391"
              CUSTOMER_POOL_NAME = 'athene-portal-stage-customers'
              PRODUCER_POOL_NAME = 'athene-portal-stage-producers'
              ASSOCIATE_POOL_NAME = 'athene-portal-stage-associates'
            } else if (env.JENKINS_REGION == 'prod') {
              DETECTED_REGION = 'Production';
              REGION = 'prod'
              WORKSPACE = 'prod'
              SUBNET_ID_PRIMARY = "subnet-53150637"
              SUBNET_ID_SECONDARY = "subnet-e8271bc7"
              SECURITY_GROUP = "sg-d398d998"
              CUSTOMER_POOL_NAME = 'athene-portal-prod-customers'
              PRODUCER_POOL_NAME = 'athene-portal-prod-producers'
              ASSOCIATE_POOL_NAME = 'athene-portal-prod-associates'
            } else {
              error("Unknown Region: $JENKINS_REGION")
            }
          }
          sh "echo 'Detected Region as: $DETECTED_REGION'"
        }
      }
    }
   

    stage('Deploy Setup') {
      agent {
        docker {
          image 'node:8-alpine'
          args '-u root:root --entrypoint=\'\''
        }
      }

      when {
        expression {
          params.jobType in ['create']
        }
      }

      steps {
        sh 'apk add --no-cache git'
        sh 'yarn --prod'
      }

      post {
        failure {
          sh 'chmod -R 777 node_modules || true'
        }
      }
    }

    stage('Deploy') {
      agent {
        docker {
          image 'hashicorp/terraform:0.11.14'
          args '-u root:root --entrypoint=\'\''
        }
      }

      when {
        expression {
          params.jobType in ['create']
        }
      }

      steps {
        withCredentials([[
          $class: 'AmazonWebServicesCredentialsBinding',
          credentialsId: 'aws-provider',
          accessKeyVariable: 'AWS_ACCESS_KEY_ID',
          secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
        ]]) {
          withCredentials(
            [[
              $class: 'AmazonWebServicesCredentialsBinding',
              credentialsId: 'aws-target',
              accessKeyVariable: 'TARGET_AWS_ACCESS_KEY_ID',
              secretKeyVariable: 'TARGET_AWS_SECRET_ACCESS_KEY'
            ]]
          ) {
            // HACK: Start Cert Shenanigans
            sh 'apk add --no-cache ca-certificates'
            sh 'cp -R .certificates/* /usr/local/share/ca-certificates/.'
            sh 'update-ca-certificates'
            // HACK: End Cert Shenanigans

            sh 'apk add --no-cache zip curl python py-pip'
            sh 'pip install --upgrade awscli==1.14.36'
            script {

              API_ID = sh(
                script: "AWS_ACCESS_KEY_ID=$TARGET_AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY=$TARGET_AWS_SECRET_ACCESS_KEY aws apigateway get-rest-apis | python -c \"import sys, json; print ([api['id'] for api in json.load(sys.stdin)['items'] if api['name'] == 'AtheneAPI'][0])\"",
                returnStdout: true
              ).trim()

              ROOT_RESOURCE_ID = sh(
                script: "AWS_ACCESS_KEY_ID=$TARGET_AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY=$TARGET_AWS_SECRET_ACCESS_KEY aws apigateway get-resources --rest-api-id $API_ID --region us-east-1 | python -c \"import sys, json; print [resource['id'] for resource in json.load(sys.stdin)['items'] if resource['path'] == '/'][0]\"",
                returnStdout: true
              ).trim()

              CUSTOMER_USER_POOL_ID = sh(
                script: "AWS_ACCESS_KEY_ID=$TARGET_AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY=$TARGET_AWS_SECRET_ACCESS_KEY aws cognito-idp list-user-pools --max-results 60 | python -c \"import sys, json; print ([pool['Id'] for pool in json.load(sys.stdin)['UserPools'] if pool['Name'] == '$CUSTOMER_POOL_NAME'][0])\"",
                returnStdout: true
              ).trim()

              PRODUCER_USER_POOL_ID = sh(
                script: "AWS_ACCESS_KEY_ID=$TARGET_AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY=$TARGET_AWS_SECRET_ACCESS_KEY aws cognito-idp list-user-pools --max-results 60 | python -c \"import sys, json; print ([pool['Id'] for pool in json.load(sys.stdin)['UserPools'] if pool['Name'] == '$PRODUCER_POOL_NAME'][0])\"",
                returnStdout: true
              ).trim()

              ASSOCIATE_USER_POOL_ID = sh(
                script: "AWS_ACCESS_KEY_ID=$TARGET_AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY=$TARGET_AWS_SECRET_ACCESS_KEY aws cognito-idp list-user-pools --max-results 60 | python -c \"import sys, json; print ([pool['Id'] for pool in json.load(sys.stdin)['UserPools'] if pool['Name'] == '$ASSOCIATE_POOL_NAME'][0])\"",
                returnStdout: true
              ).trim()
            }
            sh 'chmod -R 777 *'
            sh 'zip -r lambda-authorizer.zip *'


            sh 'terraform init'
            sh "terraform workspace select $WORKSPACE || terraform workspace new $WORKSPACE"
            sh """
              terraform validate \
                -input=false \
                --var AWS_ACCESS_KEY_ID="$TARGET_AWS_ACCESS_KEY_ID" \
                --var AWS_SECRET_ACCESS_KEY="$TARGET_AWS_SECRET_ACCESS_KEY" \
                --var API_ID="$API_ID" \
                --var ROOT_RESOURCE_ID="$ROOT_RESOURCE_ID" \
                --var REGION="$REGION" \
                --var DEPLOYMENT_ENV="$REGION" \
                --var SUBNET_ID_PRIMARY="$SUBNET_ID_PRIMARY" \
                --var SUBNET_ID_SECONDARY="$SUBNET_ID_SECONDARY" \
                --var SECURITY_GROUP="$SECURITY_GROUP" \
                --var CUSTOMER_USER_POOL_ID="$CUSTOMER_USER_POOL_ID" \
                --var PRODUCER_USER_POOL_ID="$PRODUCER_USER_POOL_ID" \
                --var ASSOCIATE_USER_POOL_ID="$ASSOCIATE_USER_POOL_ID"
              terraform apply -auto-approve \
                -input=false \
                --var AWS_ACCESS_KEY_ID="$TARGET_AWS_ACCESS_KEY_ID" \
                --var AWS_SECRET_ACCESS_KEY="$TARGET_AWS_SECRET_ACCESS_KEY" \
                --var API_ID="$API_ID" \
                --var ROOT_RESOURCE_ID="$ROOT_RESOURCE_ID" \
                --var REGION="$REGION" \
                --var DEPLOYMENT_ENV="$REGION" \
                --var SUBNET_ID_PRIMARY="$SUBNET_ID_PRIMARY" \
                --var SUBNET_ID_SECONDARY="$SUBNET_ID_SECONDARY" \
                --var SECURITY_GROUP="$SECURITY_GROUP" \
                --var CUSTOMER_USER_POOL_ID="$CUSTOMER_USER_POOL_ID" \
                --var PRODUCER_USER_POOL_ID="$PRODUCER_USER_POOL_ID" \
                --var ASSOCIATE_USER_POOL_ID="$ASSOCIATE_USER_POOL_ID"
            """
          }
        }
      }

      post {
        always {
          sh 'chmod -R 777 .certificates || true'
          sh 'chmod -R 777 .terraform || true'
          sh 'chmod -R 777 coverage || true'
          sh 'chmod -R 777 node_modules || true'
        }
      }
    }

    stage('Delete') {
      agent {
       docker {
          image 'node:8-alpine'
          args '-u root:root --entrypoint=\'\''
        }
      }

      when {
        expression {
          params.jobType in ['delete']
        }
      }

      steps {
        withCredentials(
              [[
                $class: 'AmazonWebServicesCredentialsBinding',
                credentialsId: 'aws-target',
                accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
              ]]
            )
            {
              withCredentials(
                [[
                  $class: 'AmazonWebServicesCredentialsBinding',
                  credentialsId: 'aws-target',
                  accessKeyVariable: 'TARGET_AWS_ACCESS_KEY_ID',
                  secretKeyVariable: 'TARGET_AWS_SECRET_ACCESS_KEY'
                ]]
              )
              {
                  sh 'apk add --no-cache zip curl python py-pip'
                  sh 'pip install --upgrade awscli==1.14.36'
                  script
                  {
                      API_ID = sh(
                          script: "AWS_ACCESS_KEY_ID=$TARGET_AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY=$TARGET_AWS_SECRET_ACCESS_KEY aws apigateway get-rest-apis | python -c \"import sys, json; print ([api['id'] for api in json.load(sys.stdin)['items'] if api['name'] == 'AtheneAPI'][0])\"",
                          returnStdout: true
                      ).trim()
                      RESOURCE_ID_LAMBDA_AUTHORIZER_API = sh(
                        script: "AWS_ACCESS_KEY_ID=$TARGET_AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY=$TARGET_AWS_SECRET_ACCESS_KEY aws apigateway get-resources --rest-api-id $API_ID --region us-east-1 | python -c \"import sys, json; print [resource['id'] for resource in json.load(sys.stdin)['items'] if resource.get('pathPart') == 'lambda-authorizer'][0]\"",
                        returnStdout: true
                      ).trim()
                      RESOURCE_ID_ASSOCIATE_AUTHORIZER_API = sh(
                        script: "AWS_ACCESS_KEY_ID=$TARGET_AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY=$TARGET_AWS_SECRET_ACCESS_KEY aws apigateway get-resources --rest-api-id $API_ID --region us-east-1 | python -c \"import sys, json; print [resource['id'] for resource in json.load(sys.stdin)['items'] if resource.get('pathPart') == 'associate-authorizer'][0]\"",
                        returnStdout: true
                      ).trim()
                      RESOURCE_ID_CUSTOMER_PRODUCER_AUTHORIZER_API = sh(
                        script: "AWS_ACCESS_KEY_ID=$TARGET_AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY=$TARGET_AWS_SECRET_ACCESS_KEY aws apigateway get-resources --rest-api-id $API_ID --region us-east-1 | python -c \"import sys, json; print [resource['id'] for resource in json.load(sys.stdin)['items'] if resource.get('pathPart') == 'customer-producer-authorizer'][0]\"",
                        returnStdout: true
                      ).trim()
                  }
                  sh "echo 'Rest API ID: $API_ID'"
                  sh "echo 'RESOURCE_IDS_TO_BE_DELETED: $RESOURCE_ID_LAMBDA_AUTHORIZER_API , $RESOURCE_ID_ASSOCIATE_AUTHORIZER_API , $RESOURCE_ID_CUSTOMER_PRODUCER_AUTHORIZER_API'"
                  sh "echo 'deleting lambdas'"
                  sh "aws lambda delete-function --function-name lambda-authorizer"
                  sh "aws lambda delete-function --function-name associate-authorizer"
                  sh "aws lambda delete-function --function-name customer-producer-authorizer"
                  sh "echo 'deleting api resources'"
                  sh "aws apigateway delete-resource --rest-api-id $API_ID --resource-id $RESOURCE_ID_LAMBDA_AUTHORIZER_API"
                  sh "aws apigateway delete-resource --rest-api-id $API_ID --resource-id $RESOURCE_ID_ASSOCIATE_AUTHORIZER_API"
                  sh "aws apigateway delete-resource --rest-api-id $API_ID --resource-id $RESOURCE_ID_CUSTOMER_PRODUCER_AUTHORIZER_API"
              }
          }
      }
      post {
          always {
            sh 'chmod -R 777 .nyc_output || true'
            sh 'chmod -R 777 .terraform || true'
            sh 'chmod -R 777 coverage || true'
            sh 'chmod -R 777 node_modules || true'
          }
      }
    }

    stage('Deploy Stage') {
      agent {
        docker {
          image 'infrastructureascode/aws-cli:latest'
          args '-u root:root --entrypoint=\'\''
        }
      }

      steps {
        withCredentials(
          [[
            $class: 'AmazonWebServicesCredentialsBinding',
            credentialsId: 'aws-target',
            accessKeyVariable: 'AWS_ACCESS_KEY_ID',
            secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
          ]]
        ) {
          sh "aws apigateway create-deployment --rest-api-id $API_ID --stage-name live"
        }
      }

      post {
        always {
          cleanWs()
        }
      }
    }
  }
}
