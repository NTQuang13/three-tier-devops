pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
  }

  triggers {
    pollSCM('H/2 * * * *')
  }

  environment {
    AWS_REGION   = 'ap-southeast-1'
    ACCOUNT_ID   = sh(script: 'aws sts get-caller-identity --query Account --output text', returnStdout: true).trim()
    ECR_REGISTRY = "${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    TAG          = "${env.BUILD_NUMBER}"
  }

  stages {
    stage('Build images') {
      steps {
        sh 'docker build -t $ECR_REGISTRY/three-tier-app:$TAG app-tier'
        sh 'docker build -t $ECR_REGISTRY/three-tier-web:$TAG web-tier'
      }
    }

    stage('Test') {
      steps {
        sh 'docker run --rm $ECR_REGISTRY/three-tier-app:$TAG node --check index.js'
        sh 'docker run --rm -e INTERNAL_LB_DNS=localhost $ECR_REGISTRY/three-tier-web:$TAG nginx -t'
      }
    }

    stage('Push to ECR') {
      steps {
        sh '''
          aws ecr get-login-password --region $AWS_REGION \
            | docker login --username AWS --password-stdin $ECR_REGISTRY
          docker push $ECR_REGISTRY/three-tier-app:$TAG
          docker push $ECR_REGISTRY/three-tier-web:$TAG
          docker logout $ECR_REGISTRY
        '''
      }
    }

    stage('Deploy with Ansible') {
      steps {
        withCredentials([sshUserPrivateKey(credentialsId: 'ssh-vm-key', keyFileVariable: 'SSH_KEY')]) {
          sh '''
            cd ansible
            ansible-playbook deploy.yml --private-key "$SSH_KEY" -e image_tag=$TAG
          '''
        }
      }
    }
  }

  post {
    always  { sh 'docker image prune -f' }
    success { echo "Deploy thành công, image tag ${TAG}" }
    failure { echo 'Pipeline lỗi, xem Console Output' }
  }
}