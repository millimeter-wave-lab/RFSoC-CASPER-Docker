### CASPER Toolflow is based in Ubuntu 20.04
FROM ubuntu:20.04

### INSTALL MATLAB
# install requirements
RUN apt update && apt install --yes wget
# let's work in the temporary folder
WORKDIR /tmp
# download MATLAB package manager (mpm)
RUN wget -q https://www.mathworks.com/mpm/glnxa64/mpm && chmod +x mpm
# use mpm to install MATLAB 2021a and CASPER requirements
RUN ./mpm install --release r2021a \
    --products MATLAB Simulink \
        DSP_System_Toolbox \
        Fixed-Point_Designer \
        Signal_Processing_Toolbox
# remove unnecessary files
RUN rm -rf mpm ${HOME}/.MathWorks
