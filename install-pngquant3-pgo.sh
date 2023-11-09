#!/bin/bash
###############################################################
# install pngquant3 at /opt/pngquant/bin/pngquant for 
# Centmin Mod LEMP stacks using EL7, EL8, EL9 OSes
###############################################################
DT=$(date +"%d%m%y-%H%M%S")
DIR_TMP='/svr-setup'
CENTMINLOGDIR='/root/centminlogs'
IMAGES_PATH='/root/tools/pngquant3/images'
OUTPUT_PATH='/root/tools/pngquant3/images/output'
CENTOS_SEVEN_CHECK=$(awk -F "=" '/^VERSION_ID=/ {print $2}' /etc/os-release | sed -e 's|"||g' | cut -d . -f1)

prep() {
  # sample images
  if [ ! -d "$IMAGES_PATH" ]; then
    mkdir -p "$IMAGES_PATH"
  fi
  if [ ! -d "$OUTPUT_PATH" ]; then
    mkdir -p "$OUTPUT_PATH"
  fi
  if [ ! -f "${IMAGES_PATH}/1mb.png" ]; then
    wget -q -O "${IMAGES_PATH}/1mb.png" https://github.com/centminmod/centminmod-pngquant3/raw/master/images/1mb.png
  fi
  if [ ! -f "${IMAGES_PATH}/5mb.png" ]; then
    wget -q -O "${IMAGES_PATH}/5mb.png" https://github.com/centminmod/centminmod-pngquant3/raw/master/images/5mb.png
  fi
  if [ ! -f "${IMAGES_PATH}/ducati.png" ]; then
    wget -q -O "${IMAGES_PATH}/ducati.png" https://github.com/centminmod/centminmod-pngquant3/raw/master/images/ducati.png
  fi

  # Define packages
  packages=(libpng libpng-devel libjpeg-turbo libjpeg-turbo-devel llvm-devel)

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
  if [ "$CENTOS_SEVEN_CHECK" -eq 7 ]; then
    if [ ! -f /usr/bin/llvm-profdata-14 ]; then
      yum -y install llvm14 llvm14-devel
    fi
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
    # need to match rustc LLVM version with system LLVM version
    # for PGO
    # rustup install 1.70.0
    # rustup default 1.70.0
    rustup default stable
    rustup update
    rustc --version --verbose
  fi
}

pngquant_install() {
  # pngquant3
  cd "$DIR_TMP"
  rm -rf pngquant
  git clone --recursive https://github.com/kornelski/pngquant.git
  cd pngquant

  # Compile without PGO for benchmarking
  echo
  echo "Build pngquant 3 without PGO..."
  cargo clean
  cargo build --release
  mkdir -p /opt/pngquant/bin
  \cp -af ./target/release/pngquant /opt/pngquant/bin/pngquant

  # Benchmark without PGO
  echo
  echo "Benchmarking without PGO..."
  for image in 1mb.png 5mb.png ducati.png; do
    output_file="${OUTPUT_PATH}/${image%.png}-nogpo.png"
    echo "${IMAGES_PATH}/${image}"
    { time /opt/pngquant/bin/pngquant -f "${IMAGES_PATH}/${image}" --output "$output_file"; } 2>&1 | tee -a "${CENTMINLOGDIR}/benchmark-no-pgo-${DT}.log"
  done

  # Compile with PGO
  # https://doc.rust-lang.org/rustc/profile-guided-optimization.html
  # Step 1: Build with PGO instrumentation
  echo
  echo "Build pngquant 3 PGO instrumentation..."
  echo
  cargo clean
  rm -rf /home/rusttmp/pgo
  RUSTFLAGS="-Cprofile-generate=/home/rusttmp/pgo" cargo build --release

  # Step 2: Generate profile data by running the instrumented binary
  for image in 1mb.png 5mb.png ducati.png; do
    output_file="${OUTPUT_PATH}/${image%.png}-nogpo.png"
    time ./target/release/pngquant -f "${IMAGES_PATH}/${image}" --output "$output_file";
  done

  # Step 3: Merge the `.profraw` files into a `.profdata` file
  if [ "$CENTOS_SEVEN_CHECK" -eq 7 ]; then
    if [ -f /usr/bin/llvm-profdata-14 ]; then
      LLVM_PRODATA_BIN='/usr/bin/llvm-profdata-14'
    else
      LLVM_PRODATA_BIN='/usr/bin/llvm-profdata'
    fi
  else
    LLVM_PRODATA_BIN='/usr/bin/llvm-profdata'
  fi
  echo
  echo "$LLVM_PRODATA_BIN merge -o /home/rusttmp/pgo/merged.profdata /home/rusttmp/pgo"
  $LLVM_PRODATA_BIN merge -o /home/rusttmp/pgo/merged.profdata /home/rusttmp/pgo
  ls -lAh /home/rusttmp/pgo/merged.profdata

  # Step 4: Recompile with the collected profile data
  echo
  echo "Build pngquant 3 with PGO..."
  echo
  cargo clean
  # https://github.com/llvm/llvm-project/issues/57501#issuecomment-1694552006
  sed -i 's|lto = true|lto = false|' Cargo.toml            
  RUSTFLAGS="-Cprofile-use=/home/rusttmp/pgo/merged.profdata" cargo build --release
  \cp -af ./target/release/pngquant /opt/pngquant/bin/pngquant

  # Benchmark with PGO
  echo
  echo "Benchmarking with PGO..."
  for image in 1mb.png 5mb.png ducati.png; do
    output_file="${OUTPUT_PATH}/${image%.png}-pgo.png"
    echo "${IMAGES_PATH}/${image}"
    { time /opt/pngquant/bin/pngquant -f "${IMAGES_PATH}/${image}" --output "$output_file"; } 2>&1 | tee -a "${CENTMINLOGDIR}/benchmark-pgo-${DT}.log"
  done

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