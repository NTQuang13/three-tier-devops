pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
  }

  triggers {
    pollSCM('H/2 * * * *')   // kiểm tra repo mỗi ~2 phút, không cần mở cổng cho GitHub
  }

  environment {
    DOCKER_USER = 'ntquang13'
    TAG         = "${env.BUILD_NUMBER}"
  }

  stages {
    stage('Build images') {
      steps {
        sh 'docker build -t $DOCKER_USER/three-tier-app:$TAG app-tier'
        sh 'docker build -t $DOCKER_USER/three-tier-web:$TAG web-tier'
      }
    }

    stage('Test') {
      steps {
        // Thay bằng unit test thật của bạn khi có
        sh 'docker run --rm $DOCKER_USER/three-tier-app:$TAG node --check index.js'
        sh 'docker run --rm -e INTERNAL_LB_DNS=localhost $DOCKER_USER/three-tier-web:$TAG nginx -t'
      }
    }

    stage('Push to Docker Hub') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub-cred',
                                          usernameVariable: 'DH_USER',
                                          passwordVariable: 'DH_PASS')]) {
          sh '''
            echo "$DH_PASS" | docker login -u "$DH_USER" --password-stdin
            docker push $DOCKER_USER/three-tier-app:$TAG
            docker push $DOCKER_USER/three-tier-web:$TAG
            docker logout
          '''
        }
      }
    }

    stage('Deploy with Ansible') {
      steps {
        withCredentials([
          sshUserPrivateKey(credentialsId: 'ssh-vm-key', keyFileVariable: 'SSH_KEY'),
          string(credentialsId: 'db-password', variable: 'DB_PASS')
        ]) {
          sh '''
            cd ansible
            ansible-playbook deploy.yml --private-key "$SSH_KEY" \
              -e docker_user=$DOCKER_USER \
              -e image_tag=$TAG \
              -e db_password="$DB_PASS"
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