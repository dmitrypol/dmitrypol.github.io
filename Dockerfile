FROM ruby:2.7.0

ENV home_dir=/opt/blog
RUN mkdir -p ${home_dir}
WORKDIR ${home_dir}

COPY Gemfile* ./
RUN gem install bundler:2.1.4
RUN bundle
COPY ./ ./

EXPOSE 4000
ENTRYPOINT ["./entrypoint.sh"]