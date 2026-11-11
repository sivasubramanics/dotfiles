alias getin_mary="ssh 10.85.11.36"
alias getin_merian="kitten ssh 10.90.22.29"
alias getin_myers="kitten ssh myers.bioinformatics.nl"
alias getin_smith="kitten ssh smith.bioinformatics.nl"
alias getin_handelsman="kitten ssh handelsman.bioinformatics.nl"
alias getin_grace="kitten ssh grace1.hprc.tamu.edu"
alias getin_grace2="kitten ssh grace2.hprc.tamu.edu"
alias getin_faster="kitten ssh faster1.hprc.tamu.edu"
alias getin_faster2="kitten ssh faster2.hprc.tamu.edu"

# Core replacements & defaults
alias ls='eza --icons=auto --group-directories-first'
alias l='eza -1 --icons=auto --group-directories-first'
alias ll='eza -lh --git --header --icons=auto --group-directories-first'
alias la='eza -lah --git --icons=auto --group-directories-first'
alias ldot='eza -l -d .*/ --icons=auto'

# Specialty sort views
alias lsize='eza -lh --sort=size --reverse --icons=auto --group-directories-first'
alias ltime='eza -lh --sort=modified --reverse --icons=auto --group-directories-first'

# Directory-only views
alias ldir='eza -D --icons=auto --group-directories-first'
alias ldirl='eza -lhD --icons=auto --group-directories-first'

# Tree views
alias lt='eza -T --level=2 --icons=auto --group-directories-first'
alias ltt='eza -T --level=3 --icons=auto --group-directories-first'
alias ltree='eza -T --level=4 --git-ignore --icons=auto --group-directories-first'

alias tmux='tmux -u'


# ============================================================
# MICROMAMBA
# ============================================================

# Shortcuts
alias mm='micromamba'
alias mmls='micromamba env list'
alias mmcl='micromamba clean --all'
alias mmrm='micromamba env remove -n'

# Environment management
alias mma='micromamba activate'
alias mmd='micromamba deactivate'
alias mmc='micromamba create -n'
alias mmi='micromamba install'
alias mmu='micromamba update'
alias mms='micromamba search'
alias mme='micromamba env export'

# podman
alias ralpine='runin alpine:latest'
