---
name: runpod
description: Manage RunPod GPU pods and run LLM fine-tuning experiments remotely. Use when user asks to create pods, run training, check training status, manage volumes, or do anything RunPod-related.
---

# RunPod Remote Training

Use this skill to manage RunPod GPU infrastructure and run LLM fine-tuning experiments on remote GPUs from the local machine.

## Safety Rules (MANDATORY)

- **NEVER touch pods not created by us**. Other people's pods exist on this account.
- **All resources must have `-boyd-` in the name**
- **Confirm with user before any deletion** (pods, volumes)
- When listing pods, only act on pods with `-boyd-` in the name

## Setup

```bash
# Load API keys
source /Users/brk/projects/mats/.env

# Load helper functions (rp_status, rp_train, rp_ssh_cmd, etc.)
source /Users/brk/projects/mats/runpod-testing/scripts/runpod-ctl.sh

# SSH wrapper (handles key, host checking, timeouts)
PSS=/Users/brk/projects/mats/runpod-testing/scripts/pod-ssh.sh
```

## Common Operations

### Check current status

```bash
source /Users/brk/projects/mats/.env
source /Users/brk/projects/mats/runpod-testing/scripts/runpod-ctl.sh
rp_status
```

### Create a pod

```bash
# Use existing volume: vol-boyd-test (id=2kve3ufpe3, dc=US-TX-3)
runpodctl create pod \
  --name 'pod-boyd-TASKNAME' \
  --gpuType 'NVIDIA GeForce RTX 4090' \
  --gpuCount 1 \
  --imageName 'beyarkay/mats-training:latest' \
  --containerDiskSize 20 \
  --volumePath /workspace \
  --networkVolumeId '2kve3ufpe3' \
  --secureCloud --startSSH --ports '22/tcp'
```

After creation, get SSH info:
```bash
POD_ID="<from create output>"
rp_get_ssh_info "$POD_ID"
# Returns: IP PORT
```

Then write the SSH info to `scripts/pod-connection.env`:
```bash
echo "POD_HOST=<IP>" > /Users/brk/projects/mats/runpod-testing/scripts/pod-connection.env
echo "POD_PORT=<PORT>" >> /Users/brk/projects/mats/runpod-testing/scripts/pod-connection.env
```

### SSH into pod

```bash
PSS=/Users/brk/projects/mats/runpod-testing/scripts/pod-ssh.sh
$PSS "hostname && nvidia-smi"
```

### Copy files to pod

```bash
$PSS --scp /Users/brk/projects/mats/elicitation /workspace/mats-boyd/elicitation
$PSS --scp /Users/brk/projects/mats/.env /workspace/.env-boyd
```

Note: The `elicitation/` directory is NOT in git. Must SCP it directly.

### Run training

```bash
$PSS "source /workspace/.env-boyd && \
  export HF_HOME=/workspace/.cache/huggingface && \
  export WANDB_API_KEY=\$WANDB_API_KEY_RUNPOD && \
  cd /workspace/mats-boyd/elicitation && \
  python3 main.py train \
    --model qwen_0.5b \
    --dataset insecure \
    --n-params 100 \
    --max-steps 50 \
    --batch-size 1 \
    --wandb-project PROJECT_NAME \
    --skip-eval"
```

For long-running training, use tmux:
```bash
$PSS "tmux new-session -d -s SESSIONNAME 'source /workspace/.env-boyd && \
  export HF_HOME=/workspace/.cache/huggingface && \
  export WANDB_API_KEY=\$WANDB_API_KEY_RUNPOD && \
  cd /workspace/mats-boyd/elicitation && \
  python3 main.py train ... 2>&1 | tee /workspace/SESSIONNAME.log'"
```

### Monitor training

```bash
# Check tmux session output
$PSS "tmux capture-pane -t SESSIONNAME -p -S -15"

# Check GPU usage
$PSS "nvidia-smi --query-gpu=index,utilization.gpu,memory.used --format=csv,noheader"

# List tmux sessions
$PSS "tmux list-sessions"
```

### Multi-GPU parallel training

```bash
# GPU 0
$PSS "tmux new-session -d -s gpu0 'export CUDA_VISIBLE_DEVICES=0 && ...'"
# GPU 1
$PSS "tmux new-session -d -s gpu1 'export CUDA_VISIBLE_DEVICES=1 && ...'"
```

Pre-download models first to avoid cache contention:
```bash
$PSS "export HF_HOME=/workspace/.cache/huggingface && \
  python3 -c \"from transformers import AutoTokenizer; AutoTokenizer.from_pretrained('Qwen/Qwen2.5-0.5B-Instruct')\""
```

### Check wandb results

```bash
source /Users/brk/projects/mats/.env
curl -s "https://api.wandb.ai/graphql" \
  -H "Authorization: Basic $(echo -n "api:$WANDB_API_KEY_RUNPOD" | base64)" \
  -H "Content-Type: application/json" \
  -d '{"query": "{ project(name: \"PROJECT_NAME\", entityName: \"beyarkay\") { runs { edges { node { name state summaryMetrics } } } } }"}'
```

### Stop/remove pod

```bash
runpodctl stop pod POD_ID    # Stop (no cost, volume persists)
runpodctl remove pod POD_ID  # Delete (confirm with user first!)
```

After restart: SSH port changes, must re-query API and update pod-connection.env.

**Note**: The custom image (`beyarkay/mats-training:latest`) includes all Python deps and tmux pre-installed, so no reinstall is needed after pod stop/start. Only `/workspace` data persists — container-level changes are lost.

## Known Gotchas

1. **transformers 5.x breaks** with PyTorch 2.4.x. Custom image pins <5.0. If installing manually: `pip install 'transformers>=4.40,<5.0'`
2. **Llama models are gated** (no HF token). Use Qwen models: `qwen_0.5b`, `qwen_1.5b`, `qwen_7b`
3. **Gradient dtype mismatch** in masked LoRA with bitsandbytes 4-bit. Fix: `sed -i 's/return grad \* m/return grad * m.to(grad.dtype)/' /workspace/mats-boyd/elicitation/elicit/training/utils.py`
4. **Container installs lost after stop/start**. Use `beyarkay/mats-training:latest` image to avoid this.
5. **Cannot build Docker inside RunPod** (CLONE_NEWUSER blocked). Build on Mac with `docker build --platform linux/amd64`.
6. **Volume and pod must be in same datacenter**. Our volume is in US-TX-3.
7. **GPU type string must be exact**: `NVIDIA GeForce RTX 4090` not `RTX 4090`.

## Available Models (Qwen, ungated)

- `qwen_0.5b` - Qwen2.5-0.5B-Instruct (fast, good for testing)
- `qwen_1.5b` - Qwen2.5-1.5B-Instruct
- `qwen_7b` - Qwen2.5-7B-Instruct (needs more VRAM)

## Current Resources

Check CLAUDE.md for up-to-date resource list. Key volume: `vol-boyd-test` (id=`2kve3ufpe3`, 50GB, US-TX-3).
