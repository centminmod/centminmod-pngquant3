#!/bin/bash
###############################################################
# install pngquant3 at /opt/pngquant/bin/pngquant for 
# Centmin Mod LEMP stacks using EL7, EL8, EL9 OSes
###############################################################
STATIC_BUILD='y'
DT=$(date +"%d%m%y-%H%M%S")
DIR_TMP='/svr-setup'
CENTMINLOGDIR='/root/centminlogs'

prep() {
  # Define packages
  packages=(libpng libpng-devel libjpeg-turbo libjpeg-turbo-devel)

  # Initialize installation flag
  install_flag=0

  # Check and set flag if installation is needed
  for pkg in "${packages[@]}"; do
      if ! rpm -qa | grep -qw "^$pkg"; then
          echo "$pkg is not installed."
          install_flag=1
      fi
  done

  # Install if any package is not installed
  if [ $install_flag -eq 1 ]; then
      echo "Installing missing packages..."
      yum -q -y install "${packages[@]}" && echo "Installed YUM packages" || echo "Failed to install YUM packages"
  else
      echo "YUM packages are already installed"
  fi
  if [ -f /opt/rh/gcc-toolset-13/enable ]; then
    source /opt/rh/gcc-toolset-13/enable
  elif [ -f /opt/rh/gcc-toolset-12/enable ]; then
    source /opt/rh/gcc-toolset-12/enable
  elif [ -f /opt/rh/gcc-toolset-11/enable ]; then
    source /opt/rh/gcc-toolset-11/enable
  elif [ -f /opt/rh/gcc-toolset-10/enable ]; then
    source /opt/rh/gcc-toolset-10/enable
  elif [ -f /opt/rh/devtoolset-11/enable ]; then
    source /opt/rh/devtoolset-11/enable
  elif [ -f /opt/rh/devtoolset-10/enable ]; then
    source /opt/rh/devtoolset-10/enable
  elif [ -f /opt/rh/devtoolset-9/enable ]; then
    source /opt/rh/devtoolset-9/enable
  elif [ -f /opt/rh/devtoolset-8/enable ]; then
    source /opt/rh/devtoolset-8/enable
  fi
  gcc --version
}

rust_install() {
  # rust
  if [ ! -f /root/.cargo/bin/rustc ]; then
    cd "$DIR_TMP"
    mkdir -p /home/rusttmp
    chmod 1777 /home/rusttmp
    export TMPDIR=/home/rusttmp
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y | tee rust-install.log
    source "$HOME/.cargo/env"
    rustup update
    rustc --version
  fi
}

pngquant_install() {
  # pngquant3
  cd "$DIR_TMP"
  rm -rf pngquant
  git clone --recursive https://github.com/kornelski/pngquant.git
  cd pngquant
  mkdir -p /opt/pngquant/bin
  if [[ "$STATIC_BUILD" = [yY] ]]; then
    rustup target add x86_64-unknown-linux-musl
    cargo build --release --features=lcms2-static,png-static,z-static --target=x86_64-unknown-linux-musl
    \cp -af ./target/x86_64-unknown-linux-musl/release/pngquant /opt/pngquant/bin/pngquant    
  else
    cargo build --release
    \cp -af ./target/release/pngquant /opt/pngquant/bin/pngquant
  fi
  strip /opt/pngquant/bin/pngquant
  echo 'export PATH=/opt/pngquant/bin:$PATH' | sudo tee /etc/profile.d/pngquant.sh
  source /etc/profile.d/pngquant.sh
  echo
  echo "which pngquant"
  which pngquant
  echo
  echo "ldd \$(which pngquant)"
  ldd $(which pngquant)
  echo
  echo "/opt/pngquant/bin/pngquant --version"
  /opt/pngquant/bin/pngquant --version
  echo
  echo "pngquant --version"
  pngquant --version
  if [ -f /opt/pngquant/bin/pngquant ]; then
    echo
    echo "pngquant 3 install complete"
    echo "binary installed at /opt/pngquant/bin/pngquant"
  fi
}

help() {
  echo
  echo "Usage:"
  echo
  echo "$0 install"
}

case "$1" in
  install )
    {
      echo "Install pngqaunt 3"
      prep
      rust_install
      pngquant_install
    } 2>&1 | tee "${CENTMINLOGDIR}/centminmod_install_pngquant3_${DT}.log"
    ;;
  * )
    help
    ;;
esac