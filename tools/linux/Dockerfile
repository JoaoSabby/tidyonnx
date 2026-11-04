# Resolve the latest stable Fedora tag to a digest in CI before building this image.
ARG FEDORA_IMAGE=registry.fedoraproject.org/fedora:latest
FROM ${FEDORA_IMAGE} AS native-r

# Use native distribution tooling and R packages; no interpreter bridge is involved.
RUN dnf -y upgrade --refresh && \
    dnf -y --setopt=tsflags= install R R-devel R-S7 R-tibble R-jsonlite \
      R-testthat R-data.table gcc gcc-c++ make cmake git tar gzip findutils && \
    dnf clean all
ENV MAKEFLAGS=-j2 OMP_NUM_THREADS=2 OPENBLAS_NUM_THREADS=1

# Build the current CRAN XGBoost R package from its bundled native sources.
RUN Rscript -e 'options(repos = c(CRAN = "https://cloud.r-project.org")); install.packages(c("cpp11", "xgboost"), Ncpus = 2L); stopifnot(requireNamespace("xgboost", quietly = TRUE), requireNamespace("cpp11", quietly = TRUE))'
# Cache the R adapters independently of compiler installation and source changes.
FROM native-r AS model-r
RUN dnf -y --setopt=tsflags= install --skip-unavailable R-RcppEigen R-glmnet R-parsnip R-workflows R-recipes && \
    Rscript -e 'options(repos = c(CRAN = "https://cloud.r-project.org")); packages <- c("glmnet", "parsnip", "workflows", "recipes"); missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]; if (length(missing)) install.packages(missing, Ncpus = 2L); stopifnot(all(vapply(packages, requireNamespace, logical(1), quietly = TRUE)))'

# Install only the signed native compiler component rather than a toolkit bundle.
FROM model-r AS intel-r
COPY tools/linux/oneapi.repo /etc/yum.repos.d/oneapi.repo
RUN dnf -y install intel-oneapi-compiler-dpcpp-cpp && dnf clean all
# Intel's environment initialization inspects the current shell with ps.
RUN dnf -y install procps-ng && dnf clean all

FROM intel-r AS matrix
WORKDIR /workspace
COPY . .
RUN R CMD INSTALL --preclean --no-multiarch .
CMD ["bash", "tools/linux/run-model-matrix.sh"]

# The supplied Makevars uses ccache; disable cache hits during timed source builds.
FROM intel-r AS performance
RUN dnf -y install ccache && dnf clean all
WORKDIR /workspace
COPY . .
CMD ["bash", "tools/linux/run-performance.sh", "tools/linux/Makevars.001"]

# Keep the standalone binary test as the default Docker build target.
FROM native-r AS binary
WORKDIR /workspace
COPY . .
RUN R CMD INSTALL --preclean --no-multiarch .
CMD ["bash", "tools/linux/run-binary-logistic.sh"]
