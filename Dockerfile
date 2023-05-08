FROM orboan/dind
MAINTAINER Pau España y Alejandro Rodriguez

LABEL version="1.0"
LABEL description="Proyecto 2"

ARG language=ca_ES

ENV \
    USER=alumne \
    PASSWORD=alumne \
    LANG="${language}.UTF-8" \
    LC_CTYPE="${language}.UTF-8" \
    LC_ALL="${language}.UTF-8" \
    LANGUAGE="${language}:ca" \
    REMOVE_DASH_LINECOMMENT=true \
    SHELL=/bin/bash 
ENV \
    HOME="/home/$USER" \
    DEBIAN_FRONTEND="noninteractive" \
    RESOURCES_PATH="/resources" \
    SSL_RESOURCES_PATH="/resources/ssl"
ENV \
    WORKSPACE_HOME="${HOME}" \
    MYSQL_ALLOW_EMPTY_PASSWORD=true \
    MYSQL_USER="$USER" \ 
    MYSQL_PASSWORD="$PASSWORD"

    
# Layer cleanup script
COPY resources/scripts/*.sh  /usr/bin/
RUN chmod +x usr/bin/*.sh


# Make folders
RUN \
    mkdir -p $RESOURCES_PATH && chmod a+rwx $RESOURCES_PATH && \
    mkdir -p $SSL_RESOURCES_PATH && chmod a+rwx $SSL_RESOURCES_PATH && \
    mkdir -p /etc/supervisor /var/lock/apache2 /var/run/apache2 /var/run/sshd /var/log/supervisor /var/logs /var/run/supervisor

## locales
RUN \
    if [ "$language" != "en_US" ]; then \
        apt-get -y update; \
        DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends locales; \
        echo "${language}.UTF-8 UTF-8" > /etc/locale.gen; \
        locale-gen; \
        dpkg-reconfigure --frontend=noninteractive locales; \
        update-locale LANG="${language}.UTF-8"; \
    fi \
    && clean-layer.sh

#Instalacion basica
RUN \
  apt update -y && \
  if ! which gpg; then \
       apt-get install -y --no-install-recommends gnupg; \
  fi; \
  clean-layer.sh


#Instalación de programas
RUN \ 
  apt update -y && \ 
  DEBIAN_FRONTEND=noninteractive \
  apt-get install -y --no-install-recommends \
  apt-transport-https \
  ca-certificates \
  build-essential \
  software-properties-common \
  libcurl4 \
  curl \
  apt-utils \
  ssh \
  gradle \
  maven \
  nodejs \
  openssl \
  vim \
  bash-completion \
  iputils-ping \
  npm \
  wget \
  openssl \
  git \
  zip \
  gzip \
  unzip \
  bzip2 \
  lzop \
  sudo && \
  clean-layer.sh 


RUN \
    apt update -y && \
    apt install -y supervisor openssh-server apache2 mariadb-server && \
    clean-layer.sh


#Instalacion de las dependencias necessarias
RUN apt-get update && apt-get install -y \
    supervisor \
    openssh-server \
    python3 \
    python3-pip \
    nodejs \
    npm \
    #sdkman \
    docker.io \
    docker-compose \
    mysql-client \
    git \
    #github-cli \
    maven \
    gradle

# Configurem SSH
RUN mkdir /var/run/sshd \ 
RUN echo 'root:root' | chpasswd 
RUN sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config 

# SSH login fix. Otherwise user is kicked off after login
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd

ENV NOTVISIBLE "in users profile"
RUN echo "export VISIBLE=now" >> /etc/profile

#Descargar VS Code versión web
RUN apt-get update && apt-get install -y curl gpg
RUN curl https://code.visualstudio.com/docs/?dv=linux64_deb && \
    install -o root -g root -m 644 microsoft.gpg /etc/apt/trusted.gpg.d/ && \
    rm microsoft.gpg
RUN echo "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list
RUN apt-get update && apt-get install -y code
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
RUN curl -fsSL https://code-server.dev/install.sh | sh


# Instalar Git y las CLI de Github y Gitlab
RUN apt-get update && apt-get install -y git && \
    curl -LJO https://github.com/github/hub/releases/download/v2.14.2/hub-linux-amd64-2.14.2.tgz && \
    tar xvzf hub-linux-amd64-2.14.2.tgz && \
    cd hub-linux-amd64-2.14.2 && \
    ./install && \
    cd ../ && \
    rm -rf hub-linux-amd64-2.14.2 && \
    rm hub-linux-amd64-2.14.2.tgz


# Instalar OpenSSL
RUN apt-get update && apt-get install -y openssl

# Instalamos Python 3 y pip
RUN apt-get update && apt-get install -y python3 python3-pip
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Instalamos Node.js y npm
RUN apt-get install -y nodejs && \
    apt-get install -y npm

# Instalamos el cliente de Docker
RUN apt-get update && apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
RUN add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
RUN apt-get update && apt-get install -y docker-ce-cli


# Instalamos el cliente de MySQL
RUN apt-get update && apt-get install -y mysql-client

#Variables de entorno mysql
ENV MYSQL_ROOT_PASSWORD=paulejo
ENV MYSQL_DATABASE=bbdduniversitat
ENV MYSQL_USER=dev
ENV MYSQL_PASSWORD=dev_password

#Copiar startup.sh
COPY startup.sh /usr/local/bin/

#Copiar logger.sh
COPY logger.sh /opt/bash-utils/logger.sh 

# Instalamos Maven CLI
RUN apt-get update && apt-get install -y maven

# Instalamos Gradle CLI
RUN apt-get update && apt-get install -y gradle

# Creamos un volumen para el directorio $HOME del usuario dev
VOLUME /home/dev

# Creamos un volumen para /var/lib/docker
VOLUME /var/lib/docker

# Creamos un volumen para el socket de Docker
VOLUME /var/run/docker.sock

# Exponemos los puertos
EXPOSE 8081 3306 9001 443 80

# Configurem SSH
EXPOSE 2222

# Copiamos el archivo de configuración de supervisor
COPY supervisord.conf /etc/supervisor
RUN chmod +x /usr/local/bin/startup.sh /usr/local/bin/modprobe
COPY docker-compose.yml /etc/docker-compose

CMD ["/usr/sbin/sddd", "-D"]
CMD ["/usr/local/bin/startup.sh"]

CMD ["tail", "-f", "/dev/null"]
