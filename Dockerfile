FROM almalinux:9
COPY build.sh /build.sh
ENTRYPOINT ["bash", "/build.sh"]
