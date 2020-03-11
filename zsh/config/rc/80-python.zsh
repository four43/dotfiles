#!/bin/zsh
setopt nullglob

# Conda is used for base python installs (manually activate, theirs is big and complicated)
conda_startup_script=(/opt/*conda*/etc/profile.d/conda.sh)
if [[ -f "$conda_startup_script" ]]; then
  . "$conda_startup_script"
  CONDA_CHANGEPS1=false conda activate base
fi

# Pipenv shouldn't mess with our prompt
export VIRTUAL_ENV_DISABLE_PROMPT="true"

CONDA_ENV_BASE_DIR="$(conda env list | grep "base" | head -n 1 | awk '{print $3}')"
export GDAL_DATA="$CONDA_ENV_BASE_DIR/share/gdal"
export PROJ_LIB="$CONDA_ENV_BASE_DIR/share/proj"
