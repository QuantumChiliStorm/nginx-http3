FROM almalinux:latest
COPY build.sh /build.sh
ENTRYPOINT ["bash", "/build.sh"]
