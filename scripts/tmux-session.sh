#!/bin/bash

PROJECT_DIR="$HOME/workspace/ignite_poc/"
# Ensure the password environment variable is set
if [ -z "$K8S_NODE_ENV_PASSWORD" ]; then
  echo "Error: K8S_NODE_ENV_PASSWORD is not set."
  exit 1
fi

SESSION="ignite"
SSH_CMD="sshpass -e ssh -o StrictHostKeyChecking=no"

# Start a new tmux session in the background

tmux has-session -t $SESSION 2>/dev/null

if [ $? != 0 ]; then
  tmux new-session -d -s $SESSION -n "code" -c $PROJECT_DIR

  # Create the Kubernetes control plane window
  tmux new-window -t $SESSION:1 -n "k8s-controlplane"
  tmux send-keys -t $SESSION:1 "$SSH_CMD arpit@control.plane" C-m

  # Create worker node windows
  tmux new-window -t $SESSION:2 -n "worker-node-1"
  tmux send-keys -t $SESSION:2 "$SSH_CMD arpit@worker.one" C-m

  tmux new-window -t $SESSION:3 -n "worker-node-2"
  tmux send-keys -t $SESSION:3 "$SSH_CMD arpit@worker.two" C-m

  tmux new-window -t $SESSION:4 -n "worker-node-3"
  tmux send-keys -t $SESSION:4 "$SSH_CMD arpit@worker.three" C-m

  tmux select-window -t $SESSION:0
fi
# Select the first window and attach to the session
tmux attach-session -t $SESSION
