ARG FEDORA_IMAGE=registry.fedoraproject.org/fedora:latest
FROM $FEDORA_IMAGE

COPY tools/docker/check_cpu.sh /opt/tidyonnx/check_cpu.sh
RUN sh /opt/tidyonnx/check_cpu.sh

RUN dnf -y upgrade --refresh && dnf -y install \
    R-core R-devel R-jsonlite gcc gcc-c++ gcc-gfortran make cmake ccache procps-ng \
    curl tar gzip bzip2 xz unzip git which findutils diffutils file binutils \
    pkgconf-pkg-config readline-devel libcurl-devel libxml2-devel openssl-devel \
    zlib-devel bzip2-devel xz-devel libzstd-devel pcre2-devel libicu-devel blas-devel lapack-devel \
    && dnf clean all
COPY tools/docker/oneapi.repo /etc/yum.repos.d/oneAPI.repo
RUN dnf -y install intel-oneapi-compiler-dpcpp-cpp intel-oneapi-compiler-fortran \
    intel-oneapi-mkl-devel intel-oneapi-tbb-devel && dnf clean all

COPY tools/docker/reference/Makevars.001 /opt/tidyonnx/profile/Makevars.001
COPY tools/docker/intel_profile.mk /opt/tidyonnx/intel_profile.mk
COPY tools/docker/intel_tools.mk /opt/tidyonnx/intel_tools.mk
COPY tools/docker/cascade_probe.cpp /opt/tidyonnx/cascade_probe.cpp
COPY tools/docker/intel_entrypoint.sh /opt/tidyonnx/intel_entrypoint.sh
COPY tools/docker/latest_versions.R /opt/tidyonnx/latest_versions.R
COPY tools/docker/fedora_setup.R /opt/tidyonnx/fedora_setup.R
RUN chmod +x /opt/tidyonnx/intel_entrypoint.sh && \
    /opt/tidyonnx/intel_entrypoint.sh Rscript --vanilla /opt/tidyonnx/fedora_setup.R

ENV PATH=/opt/R/latest/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin
ENV R_LIBS_SITE=/opt/tidyonnx/dependencies
ENV LC_ALL=C.UTF-8
ENV NOT_CRAN=true
ENV OMP_NUM_THREADS=1
ENV OPENBLAS_NUM_THREADS=1
ENV MKL_NUM_THREADS=1
ENV TIDYONNX_FEDORA_CONTAINER=1
ENV R_MAKEVARS_USER=/opt/tidyonnx/intel_profile.mk
ENV R_MAKEVARS_SITE=/dev/null

COPY . /opt/tidyonnx/source
WORKDIR /opt/tidyonnx/source
RUN chmod +x configure configure.win cleanup cleanup.win tools/run_fedora_tests.sh
RUN mkdir -p /opt/tidyonnx/dependencies /evidence && \
    /opt/tidyonnx/intel_entrypoint.sh Rscript --vanilla -e \
    'options(repos = c(CRAN = "https://cloud.r-project.org")); install.packages("remotes"); remotes::install_deps(".", dependencies = TRUE, upgrade = "never")'
ENTRYPOINT ["/opt/tidyonnx/intel_entrypoint.sh", "Rscript", "--vanilla", "tools/run_fedora_suite.R"]
