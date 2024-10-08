# This Dockerfile sets up cmqttd, which bridges a C-Bus PCI to a MQTT server.
#
# This requires about 120 MiB of dependencies, and the
# The final image size is about 100 MiB.
#
# Example use:
#
# $ docker build -t cmqttd .
# $ docker run --device /dev/ttyUSB0 -e "SERIAL_PORT=/dev/ttyUSB0" \
#     -e "MQTT_SERVER=192.2.0.1" -e "TZ=Australia/Adelaide" -it cmqttd

FROM python:3.11-slim as base
# Bumped to python 3.11 using the python 3.11-slim image to overcome the 
# error: externally-managed-environment error when building the container

# Install most Python deps here, because that way we don't need to include build tools in the
# final image.

RUN pip3 install 'six' 'cffi' 'paho-mqtt' 'pyserial==3.5' 'pyserial_asyncio==0.6'

# Runs tests and builds a distribution tarball
FROM base AS builder
# See also .dockerignore
ADD . /cbus
WORKDIR /cbus
RUN python3 -m unittest && \
    python3 setup.py bdist -p generic --format=gztar

# cmqttd runner image
FROM base AS cmqttd
COPY COPYING COPYING.LESSER Dockerfile README.md entrypoint-cmqttd.sh /
RUN sed -i 's/\r$//' entrypoint-cmqttd.sh 
COPY --from=builder /cbus/dist/cbus-0.2.generic.tar.gz /
RUN tar zxf /cbus-0.2.generic.tar.gz && rm /cbus-0.2.generic.tar.gz
COPY cmqttd_config/ /etc/cmqttd/ 

# Runs cmqttd itself
CMD ["./entrypoint-cmqttd.sh"]
