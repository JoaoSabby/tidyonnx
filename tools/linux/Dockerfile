# Resolve the latest stable Fedora tag to a digest in CI before building this image.
ARG FEDORA_IMAGE=registry.fedoraproject.org/fedora:latest
FROM ${FEDORA_IMAGE}

# Use native distribution tooling and R packages; no interpreter bridge is involved.
RUN dnf -y upgrade --refresh && \
    dnf -y install R R-devel R-S7 R-tibble R-jsonlite R-cpp11-devel \
      R-testthat R-data.table gcc gcc-c++ make cmake git tar gzip findutils && \
    dnf clean all
ENV MAKEFLAGS=-j2 OMP_NUM_THREADS=2 OPENBLAS_NUM_THREADS=1

# Build the current CRAN XGBoost R package from its bundled native sources.
RUN Rscript -e 'options(repos = c(CRAN = "https://cloud.r-project.org")); install.packages("xgboost", Ncpus = 2L); stopifnot(requireNamespace("xgboost", quietly = TRUE))'
WORKDIR /workspace
COPY . .
RUN R CMD INSTALL --preclean --no-multiarch .
CMD ["bash", "tools/linux/run-binary-logistic.sh"]
