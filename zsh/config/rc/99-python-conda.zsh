__conda_setup="$(CONDA_REPORT_ERRORS=false '/home/seth/miniconda3/bin/conda' shell.bash hook 2> /dev/null)"
if [ $? -eq 0 ]; then
    \eval "$__conda_setup"
else
    if [ -f "/home/seth/miniconda3/etc/profile.d/conda.sh" ]; then
        . "/home/seth/miniconda3/etc/profile.d/conda.sh"
        CONDA_CHANGEPS1=false conda activate base
    else
        \export PATH="/home/seth/miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup
