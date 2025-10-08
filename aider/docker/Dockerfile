FROM continuumio/miniconda3:latest

# Install system dependencies for building scientific packages
RUN apt-get update && apt-get install -y \
    git curl build-essential \
    pkg-config gfortran \
    libopenblas-dev liblapack-dev \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Initialize conda
RUN conda init bash

# Create aider-genius environment with Python 3.12
RUN conda create -n aider-genius python=3.12 -y && \
    conda clean -afy

# Activate aider-genius env and install aider-genius
SHELL ["/bin/bash", "-c"]
RUN source activate aider-genius && \
    pip install --upgrade pip setuptools wheel && \
    pip install "cython>=0.29.30" "numpy>=1.26.0" "extension-helpers>=1.2.0"

# Workspace
WORKDIR /workspace

# Copy and install aider-genius from local benchmarks directory
COPY aider-genius/ /tmp/aider-genius/

# Install aider-genius in its dedicated environment
RUN source activate aider-genius && \
    cd /tmp/aider-genius && \
    SETUPTOOLS_SCM_PRETEND_VERSION=0.86.1 python -m pip install -e . && \
    pip install jaclang byllm && \
    pip install -r requirements.txt

# Create a wrapper script for aider-genius that activates the correct environment
RUN echo '#!/bin/bash' > /usr/local/bin/jac-coder && \
    echo 'source activate aider-genius' >> /usr/local/bin/jac-coder && \
    echo 'exec jac-coder "$@"' >> /usr/local/bin/jac-coder && \
    chmod +x /usr/local/bin/jac-coder

# Disable aider self-update/version checks inside the container for reproducibility
ENV AIDER_NO_AUTO_UPDATE=1 \
    AIDER_DISABLE_SELF_UPDATE=1 \
    AIDER_VERSION_CHECK=0 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    AIDER_REQUIRE_LOCAL=1

# Entrypoint will handle repo clone + setup
COPY entrypoint.sh /entrypoint.sh
COPY patch_dep_util.sh /patch_dep_util.sh
RUN chmod +x /entrypoint.sh /patch_dep_util.sh

ENTRYPOINT ["/entrypoint.sh"]