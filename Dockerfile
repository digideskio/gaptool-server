FROM ruby:2.1

MAINTAINER Giacomo Bagnoli <giacomo@gild.com>

RUN groupadd --gid 1200 gaptool
RUN adduser gaptool --uid 1200 --gid 1200 --home /opt/gaptool --shell /bin/bash --disabled-password --gecos ""
WORKDIR /opt/gaptool

COPY Gemfile /opt/gaptool/Gemfile
COPY gaptool-server.gemspec /opt/gaptool/gaptool-server.gemspec
COPY VERSION /opt/gaptool/VERSION
RUN cd /opt/gaptool && bundle install --system

ADD . /opt/gaptool
RUN chown -R gaptool:gaptool /opt/gaptool
USER gaptool
EXPOSE 3000

CMD ["/opt/gaptool/bin/gaptool-server", "--listen=0.0.0.0:3000"]
