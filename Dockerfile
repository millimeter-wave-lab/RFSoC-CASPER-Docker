# Define the MATLAB version to use
ARG MATLAB_RELEASE=r2021a

# Define the additional toolboxes needed for CASPER Toolflow
ARG ADDITIONAL_PRODUCTS="Simulink DSP_System_Toolbox Fixed-Point_Designer Signal_Processing_Toolbox"

# This Dockerfile builds on the Ubuntu-based mathworks/matlab image.
FROM mathworks/matlab:$MATLAB_RELEASE

# Declare the global argument to use at the current build stage
ARG MATLAB_RELEASE
ARG ADDITIONAL_PRODUCTS

# By default, the MATLAB container runs as user "matlab". To install dependencies, switch to root.
USER root

# Install all dependencies
# MATLAB: wget, ca-certificates
# Vitis: libtinfo5
# CASPER: Numpy, software-properties-common, libqtcore4, libqtgui4
RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install --no-install-recommends --yes \
    wget \
    ca-certificates \
    libtinfo5 \
    python3-numpy \
    python3-pip \
    software-properties-common \
    && add-apt-repository ppa:rock-core/qt4 \
    && apt-get update \
    && apt-get install --no-install-recommends --yes \
    libqtcore4 \
    libqtgui4 \
    && apt-get clean \ 
    && apt-get autoremove \
    && rm -rf /var/lib/apt/lists/*

# Install CASPER python requirements
RUN python3 -m pip install colorlog pyaml odict six lxml
RUN python3 -m pip install -e "git+https://github.com/casper-astro/xml2vhdl#egg=xml2vhdl_ox&subdirectory=scripts/python/xml2vhdl-ox"

# Make the following symbolic links to ensure that gcc6 is available to Xilinx tools
RUN ln -s /usr/include/asm-generic /usr/include/asm
RUN ln -s /usr/include/x86_64-linux-gnu/sys /usr/include/sys
RUN ln -s /usr/include/x86_64-linux-gnu/bits /usr/include/bits
RUN ln -s /usr/include/x86_64-linux-gnu/gnu /usr/include/gnu


# Install Xilinx Vitis
WORKDIR /tmp
ADD Xilinx_Unified_2021.1_0610_2318.tar.gz .
COPY install_config.txt .
RUN Xilinx_Unified_2021.1_0610_2318/./xsetup -b Install -a XilinxEULA,3rdPartyEULA,WebTalkTerms -c install_config.txt
RUN sudo rm -rf /tmp/Xilinx_Unified_2021.1_0610_2318

# Switch to user matlab, and pass in $HOME variable to mpm,
# so that mpm can set the correct root folder for the support packages
WORKDIR /tmp
USER matlab

# Run mpm to install MathWorks products into the existing MATLAB installation directory
RUN wget -q https://www.mathworks.com/mpm/glnxa64/mpm \
    && chmod +x mpm \
    && EXISTING_MATLAB_LOCATION=$(dirname $(dirname $(readlink -f $(which matlab)))) \
    && sudo HOME=${HOME} ./mpm install \
        --destination=${EXISTING_MATLAB_LOCATION} \
        --release=${MATLAB_RELEASE} \
        --products ${ADDITIONAL_PRODUCTS} \
    || (echo "MPM Installation Failure. See below for more information:" && cat /tmp/mathworks_root.log && false) \
    && sudo rm -rf mpm /tmp/mathworks_root.log ${HOME}/.MathWorks

# Define the MATLAB license server.
# By default, we use University of Chile license, change the server for your own needs
ARG LICENSE_SERVER="27005@matlab-2022a.cec.uchile.cl"
ENV MLM_LICENSE_FILE=$LICENSE_SERVER

# Change working directory to home folder
WORKDIR /home/matlab

# Install CASPER repo
RUN mkdir Workspace
WORKDIR Workspace
RUN git config --global http.postBuffer 524288000
RUN git clone -b xlnx_rel_v2021.1 https://github.com/Xilinx/device-tree-xlnx.git
RUN git clone -b m2021a-dev https://github.com/casper-astro/mlib_devel.git
WORKDIR mlib_devel
RUN touch starsg.local
RUN    echo "export XILINX_PATH=/tools/Xilinx/Vivado/2021.1" > startsg.local \
    && echo "export COMPOSER_PATH=/tools/Xilinx/Model_Composer/2021.1" >> startsg.local \
    && echo "export MATLAB_PATH=/opt/matlab/R2021a" >> startsg.local \
    && echo "export PLATFORM=lin64" >> startsg.local \
    && echo "export JASPER_BACKEND=vitis" >> startsg.local \
    && echo "export XLNX_DT_REPO_PATH=/home/matlab/Workspace/device-tree-xlnx" >> startsg.local

# Solve the library incompatibility problem between Xilinx and MATLAB (see: https://strath-sdr.github.io/tools/matlab/sysgen/vivado/linux/2021/01/28/sysgen-on-20-04.html)
USER root
WORKDIR /tools/Xilinx/Vivado/2021.1/lib/lnx64.o/Ubuntu
RUN mkdir exclude && mv libgmp.so* exclude
WORKDIR /tools/Xilinx/Model_Composer/2021.1/lib/lnx64.o/Ubuntu
RUN mkdir exclude && mv libgmp.so* exclude
WORKDIR /tools/Xilinx/Vivado/2021.1/lib/lnx64.o
RUN mkdir exclude && mv libgmp.so* exclude

# Replace the `as` binary form Xilinx to avoid errors when simulating
RUN ln -sf /usr/bin/as /tools/Xilinx/Vivado/2021.1/tps/lnx64/binutils-2.26/bin/as

# post build actions
USER matlab
WORKDIR /home/matlab
