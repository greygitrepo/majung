# Flutter + Android SDK 개발·테스트 환경
# 빌드: docker compose build dev        (에뮬레이터 포함: docker compose build emulator)
FROM ubuntu:24.04 AS dev

ARG FLUTTER_VERSION=3.47.9
ARG CMDLINE_TOOLS_BUILD=16111833
ARG ANDROID_PLATFORM=android-36
ARG BUILD_TOOLS=36.0.0
ARG USER_UID=1000
ARG USER_GID=1000

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    TZ=Asia/Seoul \
    ANDROID_HOME=/opt/android-sdk \
    ANDROID_SDK_ROOT=/opt/android-sdk \
    FLUTTER_HOME=/opt/flutter \
    PUB_CACHE=/home/dev/.pub-cache \
    GRADLE_USER_HOME=/home/dev/.gradle

RUN apt-get update && apt-get install -y --no-install-recommends \
        openjdk-17-jdk-headless curl git unzip xz-utils zip ca-certificates \
        libglu1-mesa libpulse0 libnss3 libxcomposite1 libxcursor1 libxi6 libxtst6 \
        libxdamage1 libxrandr2 libasound2t64 libgbm1 libdrm2 usbutils tzdata python3 \
    && rm -rf /var/lib/apt/lists/*

# 호스트 사용자와 UID/GID를 맞춰 생성 파일이 root 소유가 되지 않게 한다
RUN (getent passwd ${USER_UID} && userdel -r $(getent passwd ${USER_UID} | cut -d: -f1)) || true \
    && groupadd -f -g ${USER_GID} dev && useradd -m -u ${USER_UID} -g ${USER_GID} -s /bin/bash dev \
    && groupadd -f kvm && usermod -aG kvm,plugdev dev \
    && mkdir -p ${ANDROID_HOME} ${FLUTTER_HOME} && chown -R dev:dev ${ANDROID_HOME} ${FLUTTER_HOME}

USER dev
# named volume 이 root 소유로 생기지 않게 마운트 지점을 미리 만든다
RUN mkdir -p /home/dev/.gradle /home/dev/.pub-cache

# Android command-line tools + 기본 SDK 패키지
RUN curl -fsSL -o /tmp/clt.zip https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_TOOLS_BUILD}_latest.zip \
    && mkdir -p ${ANDROID_HOME}/cmdline-tools \
    && unzip -q /tmp/clt.zip -d ${ANDROID_HOME}/cmdline-tools \
    && mv ${ANDROID_HOME}/cmdline-tools/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest \
    && rm /tmp/clt.zip
ENV PATH=${FLUTTER_HOME}/bin:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/emulator:${PATH}
RUN yes | sdkmanager --licenses > /dev/null \
    && sdkmanager "platform-tools" "platforms;${ANDROID_PLATFORM}" "build-tools;${BUILD_TOOLS}"

# Flutter SDK (버전 고정)
RUN curl -fsSL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz \
      | tar -xJ -C /opt \
    && git config --global --add safe.directory ${FLUTTER_HOME} \
    && flutter config --no-analytics --android-sdk ${ANDROID_HOME} \
    && dart --disable-analytics \
    && flutter precache --android \
    && yes | flutter doctor --android-licenses > /dev/null

WORKDIR /workspace
CMD ["bash"]

# ---- 통합 테스트용: 헤드리스 에뮬레이터 포함 ----
FROM dev AS emulator
ARG ANDROID_PLATFORM=android-36
RUN sdkmanager "emulator" "system-images;${ANDROID_PLATFORM};google_apis;x86_64" \
    && echo no | avdmanager create avd -n test -k "system-images;${ANDROID_PLATFORM};google_apis;x86_64" -d pixel_5
# 창 모드(emulator-gui)에서 에뮬레이터 Qt 화면이 쓰는 X11 라이브러리
USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
        libpng16-16t64 libice6 libsm6 libxkbfile1 \
    && rm -rf /var/lib/apt/lists/*
USER dev
COPY --chown=dev:dev docker/start-emulator.sh /usr/local/bin/start-emulator
