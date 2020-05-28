FROM debian:testing

ARG APP_USER=app
ARG APP_UID=1000

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get -y update
RUN apt-get -y dist-upgrade
RUN apt-get -y install clang-9 curl git gpg libboost-date-time-dev \
    libboost-filesystem-dev libboost-graph-dev libboost-iostreams-dev \
    libboost-program-options-dev libboost-regex-dev libboost-system-dev \
    libbsd-dev libclang-9-dev libelf-dev libexpat-dev libgc-dev libgmp-dev \
    libzmq3-dev nano npm python3-pip sbcl wget zlib1g-dev

ENV CC "clang-9"
ENV CXX "clang++-9"

# RUN curl https://repo.anaconda.com/pkgs/misc/gpgkeys/anaconda.asc | gpg --dearmor > conda.gpg && \
#   install -o root -g root -m 644 conda.gpg /usr/share/keyrings/conda-archive-keyring.gpg && \
#   echo "deb [arch=amd64 signed-by=/usr/share/keyrings/conda-archive-keyring.gpg] https://repo.anaconda.com/pkgs/misc/debrepo/conda stable main" > /etc/apt/sources.list.d/conda.list
# RUN apt-get -y update
# RUN apt-get -y install conda

ENV USER ${APP_USER}
ENV HOME /home/${APP_USER}
ENV PATH "/opt/clasp/bin:$HOME/.local/bin:$PATH"

RUN useradd --create-home --shell=/bin/bash --uid=${APP_UID} ${APP_USER}
COPY --chown=${APP_UID}:${APP_USER} home ${HOME}

WORKDIR ${HOME}
USER ${APP_USER}

RUN wget https://beta.quicklisp.org/quicklisp.lisp && \
    sbcl --load quicklisp.lisp --eval "(quicklisp-quickstart:install)" --quit && \
    rm quicklisp.lisp && \
    git clone https://github.com/clasp-developers/bordeaux-threads.git quicklisp/local-projects/bordeaux-threads && \
    git clone https://github.com/clasp-developers/clasp.git && \
    git clone https://github.com/cando-developers/cando.git clasp/extensions/cando && \
    cd clasp && \
    echo "USE_PARALLEL_BUILD = True" > wscript.config && \
    echo "USE_LLD = True" >> wscript.config && \
    sed -i s/"--link-static",//g wscript && \
    ./waf configure && ./waf build_cboehm

USER root
RUN cd clasp && ./waf install_cboehm && cd .. && rm -rf clasp

USER ${APP_USER}

RUN pip3 install --user jupyter jupyterlab jupyter_kernel_test && \
    jupyter serverextension enable --user --py jupyterlab && \
    jupyter labextension install @jupyter-widgets/jupyterlab-manager && \
    jupyter nbextension enable --user --py widgetsnbextension && \
    git clone -b clasp-updates https://github.com/yitzchak/common-lisp-jupyter.git quicklisp/local-projects/common-lisp-jupyter && \
    sbcl --eval "(ql:quickload '(:common-lisp-jupyter))" --eval "(cl-jupyter:install :use-implementation t)" --quit && \
    iclasp-boehm --eval "(ql:quickload '(:common-lisp-jupyter))" --eval "(cl-jupyter:install :use-implementation t)" --quit

CMD jupyter-lab --ip=0.0.0.0
