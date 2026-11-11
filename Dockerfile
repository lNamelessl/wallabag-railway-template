# Railway template wrapper: official wallabag image, digest-pinned, + first-boot
# admin password seeding. Upstream image content is untouched.
FROM wallabag/wallabag:2.6.15.1@sha256:2e9d9fbbba6feee060109351d1235386fa4ac495f98c82d94a250d56feaeaeeb

COPY docker-entrypoint-wrapper.sh /docker-entrypoint-wrapper.sh
RUN chmod +x /docker-entrypoint-wrapper.sh

ENTRYPOINT ["/docker-entrypoint-wrapper.sh"]
CMD ["wallabag"]
