FROM ruby:2.2.3

MAINTAINER Giacomo Bagnoli <giacomo@gild.com>

ENV GAPTOOL_HOME=/opt/gaptool
ENV GAPTOOL_USER=gaptool
RUN groupadd --gid 1200 $GAPTOOL_USER
RUN adduser $GAPTOOL_USER --uid 1200 --gid 1200 --home $GAPTOOL_HOME --shell /bin/bash --disabled-password --gecos ""
WORKDIR $GAPTOOL_HOME

RUN chown -R $GAPTOOL_USER:$GAPTOOL_USER /usr/local/bundle
COPY Gemfile $GAPTOOL_HOME/Gemfile
COPY gaptool-server.gemspec $GAPTOOL_HOME/gaptool-server.gemspec
COPY VERSION $GAPTOOL_HOME/VERSION
COPY Gemfile.lock $GAPTOOL_HOME/Gemfile.lock
USER $GAPTOOL_USER
RUN chown $GAPTOOL_USER:$GAPTOOL_USER $GAPTOOL_HOME
RUN gem install bundler && bundle install --jobs=2 --path=/usr/local/bundle --deployment

USER root
ADD . $GAPTOOL_HOME
RUN chown -R $GAPTOOL_USER:$GAPTOOL_USER $GAPTOOL_HOME
EXPOSE 3000
USER $GAPTOOL_USER

CMD ["bundle", "exec", "bin/gaptool-server", "-b tcp://0.0.0.0:3000", "-t 8:16", "--preload", "-w 2"]
