#!/bin/zsh
setopt nullglob

# Conda is used for base python installs (manually activate, theirs is big and complicated)
conda_env="base"
conda_startup_script=(/opt/*conda*/etc/profile.d/conda.sh)
if [[ -f "$conda_startup_script" ]]; then
  . "$conda_startup_script"
  CONDA_CHANGEPS1=false conda activate "${conda_env}"
fi

# Pipenv shouldn't mess with our prompt
export VIRTUAL_ENV_DISABLE_PROMPT="true"

export GDAL_DATA="$CONDA_PREFIX/share/gdal"
export PROJ_LIB="$CONDA_PREFIX/share/proj"
