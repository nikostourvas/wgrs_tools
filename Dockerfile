####### Dockerfile #######
FROM rocker/tidyverse:4.2.2
MAINTAINER Nikolaos Tourvas <nikostourvas@gmail.com>

# Create directory for population genetics software on linux and use it as working dir
RUN mkdir /home/rstudio/software
WORKDIR /home/rstudio/software

# Prevent error messages from debconf about non-interactive frontend
ARG TERM=linux
ARG DEBIAN_FRONTEND=noninteractive

# Install ubuntu binaries
RUN apt update && apt -y install \
	vim \
	tree \
	time \
	cmake \
	parallel \
	default-jre \
	bwa \
	trimmomatic \
	fastqc \
	multiqc \
	seqtk \
	picard-tools \
	varscan \
	plink1.9 \
	snpeff
	
# Install clumpak
RUN mkdir /home/rstudio/software/clumpak \
        && cd /home/rstudio/software/clumpak \
        && wget http://clumpak.tau.ac.il/download/CLUMPAK.zip \
        && cd /home/rstudio/software/clumpak \
        && unzip CLUMPAK.zip \
        && cd CLUMPAK \
        && unzip 26_03_2015_CLUMPAK.zip \
        && rm -rf CLUMPAK.zip 26_03_2015_CLUMPAK.zip Mac_OSX_files.zip

# Install clumpak perl dependencies via apt
RUN apt update && apt -y install libgd-graph3d-perl \
        libgd-graph-perl \
        libgd-perl \
        libarchive-zip-perl \
        libarchive-extract-perl

# Clumpak dependecies via cpanm
RUN apt -y install cpanminus
RUN cpanm Clone \
        Config::General \
        Data::PowerSet \
        Getopt::Long \
        File::Slurp \
        File::Path \
        List::MoreUtils \
        PDF::API2 \
        PDF::Table \
        File::Basename \
        List::Permutor \
        GD::Graph::lines \
        GD::Graph::Data \
        Getopt::Std \
        List::Util \
        File::Slurp \
        Scalar::Util \
        Statistics::Distributions \
        Archive::Extract \
	Archive::Zip \
        Array::Utils

# Copy .pm files to /usr/share/perl/5.30
RUN cd /home/rstudio/software/clumpak/CLUMPAK/26_03_2015_CLUMPAK/CLUMPAK \
        && chmod +x *pm \
        && cp *.pm /usr/share/perl/5.34
# fix permissions for executables & add to path
RUN cd /home/rstudio/software/clumpak/CLUMPAK/26_03_2015_CLUMPAK/CLUMPAK/CLUMPP \
        && chmod +x CLUMPP \
        && cd /home/rstudio/software/clumpak/CLUMPAK/26_03_2015_CLUMPAK/CLUMPAK/mcl/bin \
        && chmod +x * \
        && cd /home/rstudio/software/clumpak/CLUMPAK/26_03_2015_CLUMPAK/CLUMPAK/distruct \
        && chmod +x distruct1.1
ENV PATH="$PATH:/home/rstudio/software/clumpak/CLUMPAK/26_03_2015_CLUMPAK/CLUMPAK/CLUMPP"
ENV PATH="$PATH:/home/rstudio/software/clumpak/CLUMPAK/26_03_2015_CLUMPAK/CLUMPAK/mcl/bin"
ENV PATH="$PATH:/home/rstudio/software/clumpak/CLUMPAK/26_03_2015_CLUMPAK/CLUMPAK/distruct"

# Install Structure
RUN mkdir /home/rstudio/software/structure \
  && cd /home/rstudio/software/structure \ 
  && wget https://web.stanford.edu/group/pritchardlab/structure_software/release_versions/v2.3.4/release/structure_linux_console.tar.gz \
  && tar xzfv structure_linux_console.tar.gz \
  && rm -rf structure_linux_console.tar.gz
ENV PATH="$PATH:/home/rstudio/software/structure/console"

# Install python3-pip & structure_threader
RUN apt update && apt -y install python3-venv python3-pip \
&& pip3 install structure_threader 
# optional: add structure-threader to PATH
#RUN echo "PATH=$PATH:/.local/bin" >> .profile

# Install Bayescan
RUN mkdir /home/rstudio/software/bayescan \
  && cd /home/rstudio/software/bayescan \
  && wget http://cmpg.unibe.ch/software/BayeScan/files/BayeScan2.1.zip \
  && unzip BayeScan2.1.zip \
  && rm -rf BayeScan2.1.zip \
  && cp /home/rstudio/software/bayescan/BayeScan2.1/binaries/BayeScan2.1_linux64bits /usr/local/bin/bayescan
  #&& cd /home/rstudio/software/bayescan/BayeScan2.1/source \
  #&& make

# Install TreeMix
RUN apt update && apt -y install libboost-all-dev libgsl0-dev \
	&& git clone https://bitbucket.org/nygcresearch/treemix.git \
	&& cd treemix \
 	&& ./configure \
  	&& make \
  	&& make install

# Install flash
RUN wget http://ccb.jhu.edu/software/FLASH/FLASH-1.2.11.tar.gz \
	&& tar -xvf FLASH-1.2.11.tar.gz && rm FLASH-1.2.11.tar.gz \
	&& cd FLASH-1.2.11 \
	&& make \
	&& cp /home/rstudio/software/FLASH-1.2.11/flash /usr/local/bin/flash
	
# Install bedtools
RUN wget https://github.com/arq5x/bedtools2/releases/download/v2.30.0/bedtools.static.binary \
	&& mv bedtools.static.binary bedtools \
	&& chmod a+x bedtools \
	&& cp /home/rstudio/software/bedtools /usr/local/bin/bedtools

# Install samtools
RUN apt -qq update && apt -y install libncurses5-dev libbz2-dev bzip2 liblzma-dev
RUN wget https://github.com/samtools/samtools/releases/download/1.16/samtools-1.16.tar.bz2 \
	&& tar -xvf samtools-1.16.tar.bz2 && rm samtools-1.16.tar.bz2 \
	&& cd samtools-1.16/ \
	&& ./configure \
	&& make \
	&& make install

# Install BCFtools
RUN wget https://github.com/samtools/bcftools/releases/download/1.16/bcftools-1.16.tar.bz2 \
	&& tar -xvf bcftools-1.16.tar.bz2 && rm bcftools-1.16.tar.bz2 \
	&& cd bcftools-1.16/ \
	&& ./configure \
	&& make \
	&& make install

# Install htslib
RUN wget https://github.com/samtools/htslib/releases/download/1.16/htslib-1.16.tar.bz2 \
	&& tar -xvf htslib-1.16.tar.bz2 && rm htslib-1.16.tar.bz2 \
	&& cd htslib-1.16/ \
	&& ./configure \
	&& make \
	&& make install

# Install freebayes
RUN wget https://github.com/freebayes/freebayes/releases/download/v1.3.6/freebayes-1.3.6-linux-amd64-static.gz \
	&& gunzip freebayes-1.3.6-linux-amd64-static.gz \
	&& chmod +x freebayes-1.3.6-linux-amd64-static \
	&& mv freebayes-1.3.6-linux-amd64-static freebayes \
	&& cp /home/rstudio/software/freebayes /usr/local/bin/freebayes

# Install vcftools
RUN wget https://github.com/vcftools/vcftools/releases/download/v0.1.16/vcftools-0.1.16.tar.gz \
	&& tar -xvf vcftools-0.1.16.tar.gz && rm vcftools-0.1.16.tar.gz \
	&& cd vcftools-0.1.16/ \
	&& ./configure \
	&& make \
	&& make install

# Install vcflib
#RUN git clone --recursive https://github.com/vcflib/vcflib.git \
#	&& cd vcflib \
#	&& mkdir -p build && cd build \
#	&& cmake -DCMAKE_BUILD_TYPE=Debug -DZIG=OFF -DOPENMP=OFF .. \
#	&& cmake --build . \
#	&& cmake --install .

# Install easySFS
RUN apt update && apt -y install python3-numpy python3-pandas python3-scipy
RUN git clone https://github.com/isaacovercast/easySFS.git \
	&& cd easySFS \
	&& chmod 777 easySFS.py

# Install fastsimcoal2
RUN wget http://cmpg.unibe.ch/software/fastsimcoal27/downloads/fsc27_linux64.zip

# Install KING
RUN wget https://www.kingrelatedness.com/Linux-king.tar.gz \
	&& tar -xzvf Linux-king.tar.gz \
	&& cp /home/rstudio/software/king /usr/local/bin/king

# Install PopLDdecay
#RUN git clone https://github.com/hewm2008/PopLDdecay.git \
#    cd PopLDdecay; chmod 755 configure; ./configure; \
#    make; \
#    mv PopLDdecay  bin/;    #     [rm *.o]

# Install ANGSD
RUN git clone --recurse-submodules https://github.com/samtools/htslib.git \
        && cd htslib \
        && make

RUN git clone https://github.com/angsd/angsd.git \
        && cd angsd && make HTSSRC=../htslib

RUN cp -r /home/rstudio/software/angsd/ /usr/local/bin/angsd/
ENV PATH="$PATH:/usr/local/bin/angsd/"

# Install NgsRelate
RUN git clone https://github.com/ANGSD/ngsRelate \
        && cd ngsRelate \
        && make HTSSRC=../htslib
RUN cp -r /home/rstudio/software/ngsRelate/ /usr/local/bin/ngsRelate/

# Install Admixture
RUN wget https://dalexander.github.io/admixture/binaries/admixture_linux-1.3.0.tar.gz \
	&& tar -xzvf admixture_linux-1.3.0.tar.gz \
	&& cd dist/admixture_linux-1.3.0 \
	&& cp /home/rstudio/software/dist/admixture_linux-1.3.0/admixture \
	/usr/local/bin/admixture

# Install Admixtools
RUN apt update && apt install -y libgsl-dev libblas-dev gfortran liblapack-dev
RUN wget https://github.com/DReichLab/AdmixTools/archive/refs/tags/v7.0.2.tar.gz \
        && tar xzvf v7.0.2.tar.gz
RUN cd AdmixTools-7.0.2/src \
        && make clobber \
        && make all \
        && make install
RUN cp AdmixTools-7.0.2/bin/* /usr/local/bin/

# Install R packages from Bioconductor
RUN R -e "BiocManager::install(c('qvalue', 'ggtree'))"

# Install R packages from CRAN
RUN apt update -qq \
  	&& apt -y install libudunits2-dev # needed for scatterpie
RUN install2.r --error \
  	viridis \
  	multcomp \
  	ggThemeAssist \
  	remedy \
  	factoextra \
  	kableExtra \
  	scatterpie \
  	ggmap \
  	ggsn \
  	splitstackshape \
  	ggpubr \ 
  	gridGraphics \
  	officer \
  	flextable \
  	eulerr \
  	gghalves \
  	&& rm -rf /tmp/downloaded_packages/ /tmp/*.rds

# The following section is copied from hlapp/rpopgen Dockerfile
# It is copied instead of using it as a base for this image because it is not 
# updated regularly

#------------------------------------------------------------------------------
# Some of the R packages depend on libraries not already installed in the
# base image, so they need to be installed here for the R package
# installations to succeed.
RUN apt-get update \
    && apt-get install -y \
    libgsl0-dev \
    libmagick++-dev \
    libudunits2-dev \
    gdal-bin \
    libgdal-dev \
    libglpk40 \
    ghostscript

## Install population genetics packages from CRAN
RUN rm -rf /tmp/*.rds \
&&  install2.r --error \
	pcadapt \
	OptM \
	vcfR \
	ape \
	adegenet \
	pegas \
	phangorn \
	phylobase \
	coalescentMCMC \
	poppr \
	psych \
	genetics \
	hierfstat \
	lme4 \
	MuMIn \
	vegan \
	admixr \
	igraph \
&& rm -rf /tmp/downloaded_packages/ /tmp/*.rds
#------------------------------------------------------------------------------

## Install population genetics packages from Github
RUN installGithub.r \
    whitlock/OutFLANK \
	thierrygosselin/radiator \
&& rm -rf /tmp/downloaded_packages/ /tmp/*.rds

# Install Pophelper for Structure output
  # install linux dependencies
RUN apt -y install libcairo2-dev \
  && apt -y install libxt-dev
RUN apt install -y libfreetype6-dev \
        libcurl4-openssl-dev \
        libssl-dev \
        libxml2-dev \
        libnlopt-dev
  # install R dependencies
RUN install2.r --error \
    devtools \
    gridExtra \
    gtable 
  # install pophelper from github
RUN installGithub.r \
  royfrancis/pophelper \
  && rm -rf /tmp/downloaded_packages/ /tmp/*.rds

# Install PopGenome
RUN installGithub.r \
  pievos101/PopGenome \
  && rm -rf /tmp/downloaded_packages/ /tmp/*.rds

# Install python2 for old but useful scripts
RUN apt update && apt install -y python2
