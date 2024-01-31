#!/bin/bash

if command -v docker >/dev/null 2>&1; then
    echo "Start build"
else
    return ;
fi
gradle_cmd=""

if command -v gradle >/dev/null 2>&1; then
    echo "Gradle이 설치되어 있습니다. 시스템의 gradle을 사용합니다."
    gradle_cmd="gradle"
else
    echo "Gradle이 설치되어 있지 않습니다. 프로젝트의 gradlew를 사용합니다."
    gradle_cmd="./gradlew"
fi
echo ====================PROJECT BUILD===========================
$gradle_cmd build
echo ====================DOCKER BUILD===========================

$gradle_cmd buildImage -PdockerTag=$1

echo ====================DOCKER PUSH===========================
docker push $1


echo ====================K8S DEPLOY===========================
kubectl apply -f kubernetes/

