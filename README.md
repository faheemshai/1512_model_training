# 1512 Image Recognition Lab — Materials

This repository contains everything needed to run the **OpenShift AI Image Recognition Lab**.  
A single `git clone` inside your workbench gives you all notebooks, images, and model weights —  
**no `oc cp`, no internet image downloads, no manual file setup.**

## Repository Structure

```
1512_model_training/
├── models/
│   └── yolov8n-cls.pt          ← Pre-trained YOLOv8n weights (5.3 MB, no download needed)
├── sample-images/
│   ├── pass.png                ← Clean PCB (no defect)
│   ├── scratch.jpg             ← Scratch defect
│   ├── crack.jpg               ← Crack defect
│   └── contamination.jpg       ← Contamination defect
└── notebooks/
    ├── 01-validate/
    │   └── 01-validate-environment.ipynb
    ├── 02-classification/
    │   └── 02-intro-to-classification.ipynb
    ├── 03-training/
    │   └── 03-finetune-and-export.ipynb
    ├── 04-serving/
    │   ├── 04-test-inference.ipynb
    │   └── 05-batch-classify.ipynb
    └── 05-app/
        ├── base/               ← Kustomize base (postgresql, backend, frontend)
        └── overlays/student/   ← Student-specific overlay
```

## How it works (student workflow)

Each notebook's **first cell** runs this git-sync snippet automatically:

```python
import subprocess, os, pathlib

REPO_URL   = 'https://github.com/faheemshai/1512_model_training.git'
LOCAL_PATH = os.path.expanduser('~/lab-materials')

if pathlib.Path(LOCAL_PATH, '.git').is_dir():
    subprocess.run(['git', '-C', LOCAL_PATH, 'pull', '--ff-only'])
else:
    subprocess.run(['git', 'clone', REPO_URL, LOCAL_PATH])

LAB = LOCAL_PATH   # all subsequent paths use LAB as the root
```

- First run: clones the repo (~10 seconds)
- Subsequent runs / new sessions: `git pull` to get any instructor updates

## Key design decisions

| Decision | Why |
|---|---|
| `yolov8n-cls.pt` committed into `models/` | GitHub Releases URL is reachable, but this avoids the Ultralytics auto-download which can be slow on first use |
| Sample images committed into `sample-images/` | Wikimedia and `ultralytics.com` image URLs are **blocked** by the cluster network policy |
| All packages pre-installed in workbench image | `ultralytics 8.4.96`, `onnxruntime 1.25.0`, `boto3`, `torch 2.11`, `pillow`, `numpy`, `matplotlib` are already present — no pip install delay |
| Namespace auto-detected | `open('/var/run/secrets/kubernetes.io/serviceaccount/namespace').read()` — no manual substitution needed |

## Cluster details (itz-t53413)

| Item | Value |
|---|---|
| RHOAI version | 3.4.3 |
| Dashboard | https://rh-ai.apps.itz-t53413.hub01-lb.techzone.ibm.com |
| S3 internal endpoint | `http://s3.openshift-storage.svc:80` |
| KServe URL pattern | `https://defect-classifier-ext-<namespace>.apps.itz-t53413.hub01-lb.techzone.ibm.com` |
| Workbench image | `pytorch:3.4` (Python 3.12, PyTorch 2.11) |
