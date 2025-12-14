/home/soy/.local/kitty.app/bin/kitty --detach sh -c "
tmux new-session -d -s resume -c /home/soy/notes/resume/pipeline/basic-resume/ '/home/soy/.cargo/bin/typst watch /home/soy/notes/resume/pipeline/basic-resume/main.typ'; \
tmux new-window 'zathura /home/soy/notes/resume/pipeline/basic-resume/main.pdf'; \
tmux new-window '/opt/nvim-linux-x86_64/bin/nvim'; \
tmux attach -t resume"
