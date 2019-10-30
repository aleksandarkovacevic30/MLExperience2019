ARG IMAGE=intersystemscommunity/irispy:latest
FROM ${IMAGE}


USER root

RUN pip install pandas matplotlib seaborn numpy dill Pillow "tensorflow>=2.0.0" tensorflow-hub tqdm

# now for InterSystems IRIS

USER root

ENV SRC_DIR=/home/irisowner

COPY --chown=irisowner ./iscpython.o $ISC_PACKAGE_INSTALLDIR/bin/iscpython.o
COPY --chown=irisowner ./iscpython.so $ISC_PACKAGE_INSTALLDIR/bin/iscpython.so

COPY --chown=irisowner ./od/ $SRC_DIR/od
COPY --chown=irisuser ./pycode /home/irisuser/pycode
COPY --chown=irisuser ./web /usr/irissys/csp/python


RUN set -ex \
    \
    && wget -O inception.tar "https://tfhub.dev/google/faster_rcnn/openimages_v4/inception_resnet_v2/1?tf-hub-format=compressed" \
    && mkdir -p /home/irisuser/models \
    && tar -xvf inception.tar -C /home/irisuser/models  \
    && rm inception.tar \
    && chown -R irisuser:irisuser /home/irisuser/models

USER irisowner


RUN iris start $ISC_PACKAGE_INSTANCENAME && \
    /bin/echo -e " do \$system.OBJ.Load(\"/home/irisowner/od/Installer.cls\",\"ck\")\n" \
            " set sc = ##class(od.Installer).Setup(, 3)\n" \
            " halt" \
    | iris session $ISC_PACKAGE_INSTANCENAME && \
 iris stop $ISC_PACKAGE_INSTANCENAME quietly \
  && rm -rf $SRC_DIR/isc


HEALTHCHECK --interval=5s CMD /irisHealth.sh || exit 1
