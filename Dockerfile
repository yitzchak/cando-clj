FROM debian:testing

ARG APP_USER=app
ARG APP_UID=1000

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get -y update && \
    apt-get -y dist-upgrade && \
    apt-get -y install clang-9 curl git gpg libboost-date-time-dev \
    libboost-filesystem-dev libboost-graph-dev libboost-iostreams-dev \
    libboost-program-options-dev libboost-regex-dev libboost-system-dev \
    libbsd-dev libclang-9-dev libelf-dev libexpat-dev libgc-dev libgmp-dev \
    libnetcdf-dev libzmq3-dev nano npm python3-pip sbcl wget zlib1g-dev

# RUN curl https://repo.anaconda.com/pkgs/misc/gpgkeys/anaconda.asc | gpg --dearmor > conda.gpg && \
#   install -o root -g root -m 644 conda.gpg /usr/share/keyrings/conda-archive-keyring.gpg && \
#   echo "deb [arch=amd64 signed-by=/usr/share/keyrings/conda-archive-keyring.gpg] https://repo.anaconda.com/pkgs/misc/debrepo/conda stable main" > /etc/apt/sources.list.d/conda.list
# RUN apt-get -y update
# RUN apt-get -y install conda

ENV CC "clang-9"
ENV CXX "clang++-9"
ENV USER ${APP_USER}
ENV HOME /home/${APP_USER}
ENV PATH "$HOME/.local/bin:$PATH"
ENV CLASP_QUICKLISP_DIRECTORY "${HOME}/quicklisp/"
ENV ASDF_OUTPUT_TRANSLATIONS ""

RUN useradd --create-home --shell=/bin/bash --uid=${APP_UID} ${APP_USER}
COPY --chown=${APP_UID}:${APP_USER} home ${HOME}

WORKDIR ${HOME}
USER ${APP_USER}

RUN wget https://beta.quicklisp.org/quicklisp.lisp && \
    sbcl --load quicklisp.lisp --eval "(quicklisp-quickstart:install)" --quit && \
    rm quicklisp.lisp && \
    git clone https://github.com/sionescu/bordeaux-threads.git quicklisp/local-projects/bordeaux-threads && \
    git clone https://github.com/clasp-developers/cl-netcdf.git quicklisp/local-projects/cl-netcdf && \
    git clone https://github.com/clasp-developers/clasp.git && \
    git clone https://github.com/cando-developers/cando.git clasp/extensions/cando && \
    sed -i s/ctx.exec_command/print/g clasp/extensions/cando/wscript && \
    cd clasp && \
    echo "USE_PARALLEL_BUILD = True" > wscript.config && \
    echo "USE_LLD = True" >> wscript.config && \
    sed -i s/"--link-static",//g wscript && \
    ./waf configure && ./waf build_cboehm

USER root
RUN cd clasp && ./waf install_cboehm && cd .. && rm -rf clasp
RUN rm -rf /usr/local/lib/clasp/extensions/cando/src/lisp/cando-jupyter

USER ${APP_USER}
ENV SLIME_HOME "${HOME}/quicklisp/local-projects/slime"

RUN pip3 install --user jupyter jupyterlab jupyter_kernel_test nglview==1.2.0 && \
    jupyter nbextension enable --user --py widgetsnbextension && \
    jupyter nbextension enable --user --py nglview && \
    jupyter serverextension enable --user --py jupyterlab && \
    jupyter labextension install @jupyter-widgets/jupyterlab-manager nglview-js-widgets && \
    git clone https://github.com/slime/slime.git quicklisp/local-projects/slime && \
    git clone -b clasp-updates https://github.com/yitzchak/common-lisp-jupyter.git quicklisp/local-projects/common-lisp-jupyter && \
    mkdir -p quicklisp/local-projects/cl-nglview && \
    cd quicklisp/local-projects/cl-nglview && \
    git init && \
    git remote add -f origin https://github.com/yitzchak/cl-nglview.git && \
    git config core.sparseCheckout true && \
    echo "cl-nglview/" >> .git/info/sparse-checkout && \
    git pull origin master && \
    git checkout clj-migrate && \
    cd ../../.. && \
    mkdir -p quicklisp/local-projects/cando-jupyter && \
    cd quicklisp/local-projects/cando-jupyter && \
    git init && \
    git remote add -f origin https://github.com/yitzchak/cando.git && \
    git config core.sparseCheckout true && \
    echo "src/lisp/cando-jupyter/" >> .git/info/sparse-checkout && \
    git pull origin master && \
    git checkout clj-migrate && \
    cd ../../.. && \
    sbcl --eval "(ql:quickload '(:common-lisp-jupyter :cl-nglview))" --eval "(cl-jupyter:install :use-implementation t)" --quit && \
    clasp -N --eval "(ql:quickload '(:common-lisp-jupyter :cl-nglview))" --eval "(cl-jupyter:install :use-implementation t)" --quit && \
    cando -N --eval "(ql:quickload :cando-jupyter)" --eval "(cando-jupyter:install)" --quit && \
    clasp -N --eval "(ql:quickload :swank)" --eval "(swank-loader:init :delete nil :reload nil :load-contribs nil)" --quit

CMD jupyter-notebook --no-browser --ip=0.0.0.0
