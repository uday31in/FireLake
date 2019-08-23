FROM alpine/git
COPY entrypoint.sh /entrypoint.sh
RUN ls -alh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]