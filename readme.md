# 페이히어 과제

# 요구 사항

- gradle을 사용하여 어플리케이션과 도커이미지를 빌드합니다.
- 어플리케이션의 log는 host의 `/logs` 에 적재되도록 합니다.
- 정상 동작 여부를 반환하는 api를 구현하며, 10초에 한번씩 체크합니다.
- 종료 시 30초 이내에 프로세스가 종료되지 않으면 SIGKILL로 강제 종료합니다.
- 배포 시 scale-in, out 상황에서 유실되는 트래픽은 없어야 합니다.
- 어플리케이션 프로세스는 root 계정이 아닌 uid:999로 실행합니다.
- DB도 kubernetes에서 실행하며 재 실행 시에도 변경된 데이터는 유실되지 않도록 설정합니다.
- 어플리케이션과 DB는 cluster domain으로 통신합니다.
- ingress-controller를 통해 어플리케이션에 접속이 가능해야 합니다.
- namespace는 default를 사용합니다.
- README.md 파일에 실행 방법 및 답변을 기술합니다.



# 빌드
## 스크립트 작동
```shell
sudo chmod +x application-build-run.sh
./application-build-run.sh $DOCKER_IMAGE:$DOCKER_TAG

해당 파일을 실행 하기전에 kubernetes/deployment.yaml 의 이미지와 태그를 $DOCKER_IMAGE:$DOCKER_TAG로 변경해줘야합니다.
```

## Gradle
`gradle build`  : gradle을 이용하여 애플리케이션을 빌드합니다.
## 이미지 빌드
- `gradle docker` : gradle의 plugin `com.bmuschko.docker-remote-api`를 이용하여 build.gradle에 아래와 같이 build할 양식을 작성하면 gradle을 이용하여 빌드가 가능합니다.

```gradle
# gradle docker 관련 소스
task buildImage(type: DockerBuildImage) {
    inputDir = file('.')
    images.add('miewone/petclinic:latest')
}
```
- `gradle bootBuildImage` : springboot 2.3 부터 지원하며 Cloud Native Buildpack를 이용하여 이미지를 생성해줍니다.

```gradle
# gradle bootBuildImage 관련 소스
bootBuildImage {
    imageName = 'miewone/petclinic:latest'
}

```

# 배포
## 버전
Helm : v3.13.0
nginx-ingress : 1.9.6

## 설정
배포 전 nginx-ingress-controller 를 사용하기 위해서는 우선적으로 nginx-ingress를 설치해줘야합니다.

### Helm 이용

기존에 헬름이 설치되어있다면 아래 명령어를 수행해 주세요.
```
helm upgrade --install ingress-nginx ingress-nginx \
   --repo https://kubernetes.github.io/ingress-nginx \
   --namespace ingress-nginx --create-namespace \
   --debug \
   --atomic
```

*Helm v3.0 이상이어야합니다.*


## kubectl
```
kubernetes/
├── deployment.yaml
├── ingress-controller.yaml
├── secret.yaml
├── service-deploy-petclinic.yaml
├── service-stateful-petclinic.yaml
└── statefulset.yaml
```
`kubectl apply -f kubernetes/` 명령어를 활용하여 배포합니다.



---

각 요구사항 마다의 구현을 아래에 정리해놨습니다.

# deployment

## 요구사항
각 요구사항 마다의 구현을 아래에 정리해놨습니다.

- 어플리케이션의 log는 host의 `/logs` 에 적재되도록 합니다.
```yaml
# deployment.yaml:58
volumeMounts:
        - name: log-volume
          mountPath: /workdir/server/log
      terminationGracePeriodSeconds: 30
      volumes:
      - name: log-volume
        hostPath:
          path: /logs
          type: Directory
  strategy:
```
- 정상 동작 여부를 반환하는 api를 구현하며, 10초에 한번씩 체크합니다.
``` yaml
# deployment.yaml:42
livenessProbe:
          httpGet:
            path: /manage/health/liveness
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /manage/health/readiness
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
```
- 종료 시 30초 이내에 프로세스가 종료되지 않으면 SIGKILL로 강제 종료합니다.
`terminationGracePeriodSeconds: 30` deployment.yaml:57
- 배포 시 scale-in, out 상황에서 유실되는 트래픽은 없어야 합니다.
```yaml
# deployment.yaml:63
strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
```
- 어플리케이션 프로세스는 root 계정이 아닌 uid:999로 실행합니다.
``` yaml
# deployment.yaml:16
securityContext:
        runAsUser: 999 
```

## StatefulSet

- DB도 kubernetes에서 실행하며 재 실행 시에도 변경된 데이터는 유실되지 않도록 설정합니다.

    Mysql 이미지를 sts 형식으로 배포하여 해당 리소스가 재시작 또는 삭제되도 유실되지 않습니다.

## Service

- 어플리케이션과 DB는 cluster domain으로 통신합니다.

``` text
├── service-deploy-petclinic.yaml
├── service-stateful-petclinic.yaml
```
위와 같이 리소스별 서비스를 연결하여 petclinic이 db의 HOST에 연결할때는 `db-service.petclinic.svc.cluster.local` 와 같이 k8s dns query를 사용하도록 했습니다.

## Ingress-Controller

- ingress-controller를 통해 어플리케이션에 접속이 가능해야 합니다.

nginx-ingress-controller를 이용하여 어플리케이션에 접속이 가능하게 하였습니다.
