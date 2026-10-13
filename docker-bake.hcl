variable "DOCKERHUB_REPO" {
  default = "andreassag/graphify"
}

variable "GHCR_REPO" {
  default = "ghcr.io/andreassag/graphify"
}

# Extracts major version component (e.g. "0" from "0.9.80")
function "major" {
  params = [ver]
  result = split(".", ver)[0]
}

# Extracts minor version component (e.g. "0.9" from "0.9.80")
function "minor" {
  params = [ver]
  result = length(split(".", ver)) > 1 ? "${split(".", ver)[0]}.${split(".", ver)[1]}" : split(".", ver)[0]
}

# Formats tags for a given registry repository
function "format_tags" {
  params = [repo, python, graphifyy, is_latest]
  result = concat(
    # Version tags qualified with python version
    ["${repo}:${graphifyy}-py${python}"],
    ["${repo}:${minor(graphifyy)}-py${python}"],
    ["${repo}:${major(graphifyy)}-py${python}"],
    ["${repo}:py${python}"],

    # Canonical tags (unqualified)
    is_latest ? [
      "${repo}:latest",
      "${repo}:${major(graphifyy)}",
      "${repo}:${minor(graphifyy)}",
      "${repo}:${graphifyy}"
    ] : [
      "${repo}:${graphifyy}"
    ]
  )
}

group "default" {
  targets = ["graphify"]
}

target "graphify" {
  name = "graphify-py${replace(item.python, ".", "")}-${replace(item.graphifyy, ".", "")}"

  # Matrix defining versions of Python and Graphifyy to build.
  # To add new versions, simply append new items to the list below.
  matrix = {
    item = [
      {
        python    = "3.14"
        graphifyy = "0.9.80"
        latest    = true
      }
      # Examples for adding future or alternative versions:
      # {
      #   python    = "3.13"
      #   graphifyy = "0.9.80"
      #   latest    = false
      # },
      # {
      #   python    = "3.14"
      #   graphifyy = "0.9.81"
      #   latest    = true
      # }
    ]
  }

  context    = "."
  dockerfile = "Dockerfile"

  args = {
    PYTHON_VERSION    = item.python
    GRAPHIFYY_VERSION = item.graphifyy
  }

  platforms = [
    "linux/amd64",
    "linux/arm64"
  ]

  tags = concat(
    format_tags(DOCKERHUB_REPO, item.python, item.graphifyy, item.latest),
    format_tags(GHCR_REPO, item.python, item.graphifyy, item.latest)
  )
}
