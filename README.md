# Dotfiles

My personal dotfiles repository for managing shell configurations, aliases, and environment settings across different systems and environments. **USE WITH CAUTION**

## Repository Structure

```text
.
├── common/             # Shared configurations (Bash aliases, functions, Starship prompt)
├── tamu_hprc/          # TAMU High-Performance Research Computing environment overrides
├── tamu_mac/           # TAMU macOS environment configs
├── wur_mac/            # WUR macOS environment configs
├── install.sh          # Automated installation script
└── README.md

```

---

## Prerequisites & Tool Installations

These dotfiles rely on several modern CLI tools. Depending on your operating system (`macOS` via Homebrew or Linux/HPC via `micromamba`/`apt`), you can install them using the commands below:

### 1. Starship (Prompt)

A fast, customizable, and minimal prompt for any shell.

* **macOS (Homebrew):**
```bash
brew install starship

```


* **Linux / Manual:**
```bash
curl -sS [https://starship.rs/install.sh](https://starship.rs/install.sh) | sh

```



### 2. Eza (Modern `ls` replacement)

A modern, maintained replacement for `ls` written in Rust.

* **macOS (Homebrew):**
```bash
brew install eza

```


* **Linux (Cargo / Micromamba):**
```bash
cargo install eza
# or via conda-forge if available in your environment
micromamba install -c conda-forge eza

```



### 3. FZF (Command-line fuzzy finder)

A general-purpose command-line fuzzy finder.

* **macOS (Homebrew):**
```bash
brew install fzf
# To install useful key bindings and fuzzy completion:
$(brew --prefix)/opt/fzf/install

```


* **Linux (Git / Package Manager):**
```bash
git clone --depth 1 [https://github.com/junegunn/fzf.git](https://github.com/junegunn/fzf.git) ~/.fzf
~/.fzf/install

```



### 4. Micromamba / Conda (Package Management)

Frequently used for scientific computing and managing isolated software environments, especially on HPC clusters.

* **Installation:**
```bash
"${SHELL}" <(curl -L micro.mamba.pm/install.sh)

```



---

## Installation

This repository includes an automated installation script (`install.sh`) that sets up the correct environment links and configurations.

### Usage

Run the installation script by specifying your target environment:

```bash
./install.sh --env [wur_mac|tamu_mac|tamu_hprc]

```

### Available Environments

* `wur_mac` — Configured for Wageningen University & Research macOS setups.
* `tamu_mac` — Configured for Texas A&M University macOS setups.
* `tamu_hprc` — Configured for Texas A&M High-Performance Research Computing (HPRC) clusters (e.g., Grace, Terra).

### Options

* `-e, --env` — Specify the target environment (**Required**)
* `-h, --help` — Display the help message and exit

---
