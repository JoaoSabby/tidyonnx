# Resolve the latest stable Fedora tag to a digest in CI before building this image.
ARG FEDORA_IMAGE=registry.fedoraproject.org/fedora:latest
FROM ${FEDORA_IMAGE}

# Use native distribution tooling and R packages; no interpreter bridge is involved.
RUN dnf -y upgrade --refresh && \
    dnf -y --setopt=tsflags= install R R-devel R-S7 R-tibble R-jsonlite \
      R-testthat R-data.table gcc gcc-c++ make cmake git tar gzip findutils && \
    dnf clean all
ENV MAKEFLAGS=-j2 OMP_NUM_THREADS=2 OPENBLAS_NUM_THREADS=1

# Build the current CRAN XGBoost R package from its bundled native sources.
RUN Rscript -e 'options(repos = c(CRAN = "https://cloud.r-project.org")); install.packages(c("cpp11", "xgboost"), Ncpus = 2L); stopifnot(requireNamespace("xgboost", quietly = TRUE), requireNamespace("cpp11", quietly = TRUE))'
ARG MODEL_MATRIX=0
RUN if [ "$MODEL_MATRIX" = 1 ]; then \
      dnf -y --skip-unavailable --setopt=tsflags= install R-RcppEigen R-glmnet R-parsnip R-workflows R-recipes && \
      Rscript -e 'options(repos = c(CRAN = "https://cloud.r-project.org")); packages <- c("glmnet", "parsnip", "workflows", "recipes"); missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]; if (length(missing)) install.packages(missing, Ncpus = 2L); stopifnot(all(vapply(packages, requireNamespace, logical(1), quietly = TRUE)))'; \
    fi
ARG INTEL_COMPILER=0
COPY tools/linux/oneapi.repo /etc/yum.repos.d/oneapi.repo
RUN if [ "$INTEL_COMPILER" = 1 ]; then \
      dnf -y install intel-oneapi-compiler-dpcpp-cpp && dnf clean all; \
    fi
WORKDIR /workspace
COPY . .
RUN R CMD INSTALL --preclean --no-multiarch .
CMD ["bash", "tools/linux/run-binary-logistic.sh"]
