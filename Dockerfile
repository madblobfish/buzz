FROM ruby:3-alpine

RUN apk add musl-dev g++ openssl-dev ruby-dev make
RUN gem install thin sinatra-websocket sinatra
#RUN apk add openssl ruby
RUN apk del musl-dev g++ openssl-dev ruby-dev make

ADD buzzer.rb buzzer.rb
ADD index.html index.html

CMD ruby buzzer.rb
