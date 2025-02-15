#  ---------------------------------- setup our needed libreoffice engaged server with newest glibc
# we cannot use the official image since we then cannot have sid and the glibc fix
#FROM openjdk:11.0-jre-slim-stretch as jodconverter-base
FROM debian:sid as jodconverter-base
# backports would only be needed for stretch
#RUN echo "deb http://ftp2.de.debian.org/debian stretch-backports main contrib non-free" > /etc/apt/sources.list.d/debian-backports.list
RUN apt-get update && apt-get -y install \
        openjdk-11-jre \
        apt-transport-https locales-all libpng16-16 libxinerama1 libgl1-mesa-glx libfontconfig1 libfreetype6 libxrender1 \
        libxcb-shm0 libxcb-render0 adduser cpio findutils \
        # procps needed for us finding the libreoffice process, see https://github.com/sbraconnier/jodconverter/issues/127#issuecomment-463668183
        procps \
    # only for stretch
    #&& apt-get -y install -t stretch-backports libreoffice --no-install-recommends \
    # sid variant
    && apt-get -y install libreoffice libreoffice-l10n-zh-cn fonts-wqy-microhei --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*
ENV JAR_FILE_NAME=app.war
ENV JAR_FILE_BASEDIR=/opt/app
ENV LOG_BASE_DIR=/var/log

COPY bin/docker-entrypoint.sh /docker-entrypoint.sh

RUN mkdir -p ${JAR_FILE_BASEDIR} ${LOG_BASE_DIR} /etc/app \
  && touch /etc/app/application.properties \
  && chmod +x /docker-entrypoint.sh



ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["--spring.config.additional-location=/etc/app/"]


FROM jodconverter-base as cjk-base
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y locales

RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    dpkg-reconfigure --frontend=noninteractive locales && \
    update-locale LANG=en_US.UTF-8

ENV LANG en_US.UTF-8



#  ----------------------------------  build our jodconvert builder, so source code with build tools
FROM openjdk:11-jdk as jodconverter-builder
RUN apt-get update \
  && apt-get -y install git \
  && git clone https://github.com/sbraconnier/jodconverter /tmp/jodconverter \
  && mkdir /dist

#  ---------------------------------- gui builder
FROM jodconverter-builder as jodconverter-gui
WORKDIR /tmp/jodconverter/jodconverter-samples/jodconverter-sample-spring-boot
RUN ../../gradlew build \
  && cp build/libs/*SNAPSHOT.war /dist/jodconverter-gui.war


#  ----------------------------------  rest build
FROM jodconverter-builder as jodconverter-rest
WORKDIR /tmp/jodconverter/jodconverter-samples/jodconverter-sample-rest
RUN ../../gradlew build \
  && cp build/libs/*SNAPSHOT.war /dist/jodconverter-rest.war


#  ----------------------------------  GUI prod image
FROM cjk-base as gui
COPY application-gui.yml /etc/app/application.yml
COPY --from=jodconverter-gui /dist/jodconverter-gui.war ${JAR_FILE_BASEDIR}/${JAR_FILE_NAME}

#  ----------------------------------  REST prod image
FROM cjk-base as rest
COPY application-rest.yml /etc/app/application.yml
COPY --from=jodconverter-rest /dist/jodconverter-rest.war ${JAR_FILE_BASEDIR}/${JAR_FILE_NAME}

