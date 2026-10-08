FROM ubuntu:22.04

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        openssh-server \
        vim \
        less \
        net-tools \
        iputils-ping \
        jq \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir /var/run/sshd
RUN useradd -m -s /bin/bash analyst && \
    echo 'analyst:blue_team_rocks' | chpasswd

COPY sshd_config /etc/ssh/sshd_config
RUN mkdir -p /opt/admin/logs

RUN echo '' > /etc/motd && \
    echo '╔═══════════════════════════════════════════════════════════════╗' >> /etc/motd && \
    echo '║          ADMIN FEEDBACK SYSTEM - INCIDENT RESPONSE           ║' >> /etc/motd && \
    echo '╠═══════════════════════════════════════════════════════════════╣' >> /etc/motd && \
    echo '║                                                               ║' >> /etc/motd && \
    echo '║  Welcome, Security Analyst.                                   ║' >> /etc/motd && \
    echo '║                                                               ║' >> /etc/motd && \
    echo '║  LOG LOCATION: /opt/admin/logs/                               ║' >> /etc/motd && \
    echo '║  FILES: access.log, error.log                                 ║' >> /etc/motd && \
    echo '║                                                               ║' >> /etc/motd && \
    echo '╚═══════════════════════════════════════════════════════════════╝' >> /etc/motd && \
    echo '' >> /etc/motd

EXPOSE 22
CMD ["/usr/sbin/sshd", "-D"]
