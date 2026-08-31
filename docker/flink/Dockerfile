# 自构建 Flink 1.17.2 镜像（内置 Paimon 0.8.1 connector）
# 不依赖 docker.io 官方 flink 镜像，基础 ubuntu 走国内源，Flink 二进制走清华镜像
FROM swr.cn-north-4.myhuaweicloud.com/ddn-k8s/docker.io/library/ubuntu:22.04

ARG FLINK_VERSION=1.17.2
ARG SCALA_VERSION=2.12
ENV FLINK_HOME=/opt/flink
ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
ENV PATH="${JAVA_HOME}/bin:${FLINK_HOME}/bin:${PATH}"

# 换清华 apt 源并安装 JDK17 + curl
RUN sed -i 's|archive.ubuntu.com|mirrors.tuna.tsinghua.edu.cn|g; s|security.ubuntu.com|mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends openjdk-11-jdk-headless curl && \
    rm -rf /var/lib/apt/lists/*

# 下载 Flink 二进制（清华 Apache 镜像）
RUN curl -fSL "https://mirrors.tuna.tsinghua.edu.cn/apache/flink/flink-${FLINK_VERSION}/flink-${FLINK_VERSION}-bin-scala_${SCALA_VERSION}.tgz" -o /tmp/flink.tgz && \
    tar -xzf /tmp/flink.tgz -C /opt && \
    ln -s /opt/flink-${FLINK_VERSION} ${FLINK_HOME} && \
    rm /tmp/flink.tgz

# Paimon / Hadoop / Kafka connector（build context 里的 lib/）
COPY lib/paimon-flink-1.17-0.8.1.jar ${FLINK_HOME}/lib/
COPY lib/flink-shaded-hadoop-2-uber.jar ${FLINK_HOME}/lib/
COPY lib/flink-sql-connector-kafka.jar ${FLINK_HOME}/lib/

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR ${FLINK_HOME}
ENTRYPOINT ["/entrypoint.sh"]
