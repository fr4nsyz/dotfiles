#!/bin/env bash

your_home="/home/soy"


${your_home}/.local/kitty.app/bin/kitty --detach sh -c "
tmux new-session -d -s resume -c ${your_home}/notes/data/resume/pipeline/basic-resume/ '${your_home}/.cargo/bin/typst watch ${your_home}/notes/data/resume/pipeline/basic-resume/main.typ'; \
tmux new-window '/usr/bin/zathura ${your_home}/notes/data/resume/pipeline/basic-resume/main.pdf'; \
tmux new-window 'cd ${your_home}/notes/data/resume/pipeline/basic-resume/; /opt/nvim-linux-x86_64/bin/nvim'; \
tmux attach -t resume"
