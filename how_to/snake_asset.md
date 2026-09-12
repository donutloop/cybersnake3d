# CyberSnake 3D: Generative Asset Pipeline Guide

This document describes the installation, optimization, generation, and integration process we performed to transition CyberSnake 3D from generic procedural box segments to custom, organically aligning cybernetic 3D models using **Roblox Cube**.

---

## 1. Environment & Setup

We established a fully isolated generative environment under the `/cube` directory in your workspace:
* **Python Version:** Configured with `Python 3.12` to guarantee package compatibility.
* **Symlink Correction:** Rectified a common virtual environment issue where `python` and `python3` pointed to the system's global Python 3.14 (causing import issues), ensuring they explicitly target the virtual environment's isolated `python3.12`.
* **Dependencies:** Installed `cube` in editable mode, pulling in PyTorch (2.12.0 with CUDA support), Hugging Face Hub (with Xet support), Warp-lang (for marching cubes), and Trimesh.

---

## 2. Weight Download Optimization

To fetch the massive pre-trained model checkpoints (~10GB total), we tuned the Hugging Face Xet transfer manager:
1. **Concurrency Control:** Disabled standard adaptive rate limits to force fixed multi-stream downloads:
   * `HF_XET_FIXED_DOWNLOAD_CONCURRENCY=32`
   * `HF_XET_NUM_CONCURRENT_RANGE_GETS=32`
2. **Speed Achieved:** Boosted bandwidth usage to **~8.4 MB/s**, reducing a potential 45-minute wait time to just under 15 minutes.
3. **Checkpoints Fetched:**
   * `shape_gpt.safetensors` (6.7 GB) - Main generative GPT model.
   * `shape_tokenizer.safetensors` (1.1 GB) - 3D shape encoder/decoder tokenizer.

---

## 3. How to Generate New Assets

All asset generation runs locally on your **NVIDIA RTX 3090 GPU**, utilizing NVIDIA Warp's CUDA Marching Cubes kernels for near-instant rendering.

### Step 1: Activate the Environment
Always activate the dedicated environment before executing generation:
```bash
cd /home/donutloop/Workspace/Playground/prototype_omega/cube
source venv/bin/activate
```

### Step 2: Run the Generation Script
Specify your prompt, output folder, and enable `--fast-inference`:
```bash
python -m cube3d.generate \
  --config-path cube3d/configs/open_model.yaml \
  --gpt-ckpt-path model_weights/shape_gpt.safetensors \
  --shape-ckpt-path model_weights/shape_tokenizer.safetensors \
  --prompt "YOUR DETAILED Cyberpunk PROMPT HERE" \
  --output-dir outputs/your_asset_name \
  --fast-inference
```

#### Prompt Suggestions:
* **For Tier 1 Enemies:** `"A hostile mechanical cybernetic alien spider, neon red glowing optics, modular armor plates"`
* **For Shards / Collectibles:** `"A glowing floating cyberpunk database core, holographic circuit lines"`
* **For Obstacles / Hazards:** `"A mechanical defensive turret post, neon laser conduits"`

---

## 4. Game Integration Details

### Mesh Placement
The generated `.obj` meshes are copied directly into the Godot assets folder:
* Head: `cybersnake3d/project/assets/snake_head.obj`
* Segment: `cybersnake3d/project/assets/snake_body.obj`

### Controller Logic (`snake3d.gd`)
We replaced the default BoxMesh rendering in `snake3d.gd` with a highly robust and organic rendering pipeline:
1. **Dynamic Safe Loading:** Utilizes `ResourceLoader.exists()` to query meshes. If present, it loads the custom OBJs. If missing, it automatically falls back to procedural `BoxMesh` blocks to prevent engine crashes.
2. **Smooth Orientation Alignment:**
   * **Head (`i == 0`):** Automatically aligns rotation using `look_at(seg.position + dir3d, Vector3.UP)` to face the current horizontal grid movement direction.
   * **Body Segments (`i > 0`):** Identifies the position of the segment directly ahead (`body[i - 1]`) and aligns its basis towards it. This gives the snake a premium, organically curved appearance when turning and slithering.
3. **Scaling Factor:** Segments dynamically scale down smoothly towards the tail, preserving the visual gradient.

---

## 5. Visual Customization in Godot

Because the models are loaded dynamically under the customized materials (`head_mat` and `body_mat`), any tweaks you apply inside `snake3d.gd` to the emission parameters will reflect beautifully on the custom meshes!

* **To increase neon glow:** Edit lines 55/59 in `snake3d.gd` to increase `emission_energy_multiplier`.
* **To change theme colors based on Evolution stage:** Modify `_apply_evo_colors()` in `snake3d.gd`.
