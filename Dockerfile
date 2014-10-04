FROM ubuntu:14.04

MAINTAINER Giacomo Bagnoli <giacomo@gild.com>

RUN echo "deb http://ppa.launchpad.net/brightbox/ruby-ng-experimental/ubuntu trusty main" \
    > /etc/apt/sources.list.d/ruby-ng.list

RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C3173AA6

RUN apt-get update && \
    apt-get install -y build-essential ca-certificates && \
    apt-get install -y ruby2.1 ruby2.1-dev && \
    update-alternatives --set ruby /usr/bin/ruby2.1 && \
    update-alternatives --set gem /usr/bin/gem2.1 && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*.deb

RUN gem install bundle
RUN groupadd --gid 1200 gaptool
RUN adduser gaptool --uid 1200 --gid 1200 --home /opt/gaptool --shell /bin/bash --disabled-password --gecos ""
COPY Gemfile /opt/gaptool/Gemfile
COPY gaptool-server.gemspec /opt/gaptool/gaptool-server.gemspec
COPY VERSION /opt/gaptool/VERSION
RUN cd /opt/gaptool && bundle install --system

EXPOSE 3000
WORKDIR /opt/gaptool
ADD . /opt/gaptool
USER gaptool
CMD ["/opt/gaptool/bin/gaptool-server", "--listen=0.0.0.0:3000"]
