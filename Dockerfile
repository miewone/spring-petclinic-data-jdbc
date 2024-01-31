
FROM gradle:8.5.0-jdk17-alpine AS builder

ENV GRADLE_HOME=/opt/gradle/latest
ENV PATH=${GRADLE_HOME}/bin:${PATH}

WORKDIR /workdir/server
RUN mkdir -p /workdir/server/log

COPY build.gradle /workdir/server/build.gradle
COPY gradle ./gradle

COPY src /workdir/server/src

RUN gradle build -x test && ls /workdir/server/build/libs/
WORKDIR /workdir/server/build/libs/
CMD ["java","-jar","server-3.0.0.BUILD-SNAPSHOT.jar"]
