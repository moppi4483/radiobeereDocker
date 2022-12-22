FROM debian:stable-slim

RUN mkdir /temp
COPY install.sh /temp
RUN chmod +x /temp/install.sh
RUN /temp/install.sh

EXPOSE 80/tcp

CMD /radiobeere/start.sh