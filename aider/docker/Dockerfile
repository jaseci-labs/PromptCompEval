FROM python:3.12-slim

# Install system dependencies for building scientific packages
RUN apt-get update && apt-get install -y \
    git curl build-essential \
    pkg-config gfortran \
    libopenblas-dev liblapack-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Python 3.12 compatible versions - upgrade pip first to avoid build issues
RUN pip install --upgrade pip setuptools wheel && \
    pip install --no-cache-dir \
    "cython>=0.29.30" \
    "numpy>=1.26.0" \
    "extension-helpers>=1.2.0"

# Workspace
WORKDIR /workspace

# Copy and install aider-genius from local benchmarks directory
COPY aider-genius/ /tmp/aider-genius/



# Install aider-genius as per README instructions
RUN cd /tmp/aider-genius && \
    SETUPTOOLS_SCM_PRETEND_VERSION=0.86.1 python -m pip install -e . && \
    pip install jaclang byllm && \
    pip install -r requirements.txt

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