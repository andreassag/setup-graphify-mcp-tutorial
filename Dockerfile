ARG PYTHON_VERSION=3.14
FROM python:${PYTHON_VERSION}-slim

ARG GRAPHIFYY_VERSION=0.9.80

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install graphify with MCP dependencies
RUN pip install --no-cache-dir "graphifyy[mcp]==${GRAPHIFYY_VERSION}"

WORKDIR /workspace

# Default command starts the MCP server on the generated graph
ENTRYPOINT ["python", "-m", "graphify.serve"]
CMD ["graphify-out/graph.json"]
