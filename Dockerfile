####### Dockerfile #######
FROM rocker/tidyverse:4.6.1
LABEL maintainer="Nikolaos Tourvas <nikostourvas@gmail.com>"

# 1. SYSTEM CONFIGURATION
ENV DEBIAN_FRONTEND=noninteractive \
    TERM=linux \
    PATH=/usr/local/bin:$PATH

# 2. UNIFIED APT INSTALLATION
RUN apt-get update && apt-get install -y --no-install-recommends \
    # --- Core Utilities ---
    vim nano less tree time parallel \
    wget curl git unzip bzip2 gnupg ca-certificates \
    build-essential cmake autoconf automake \
    rename \
    # --- Java ---
    default-jre openjdk-21-jre \
    # --- Python dependencies ---
    python3-dev python3-pip python3-venv \
    # --- Bioinformatics Libraries (Dev headers) ---
    zlib1g-dev libbz2-dev liblzma-dev libtinfo6 \
    libncurses5-dev libcurl4-openssl-dev libxml2-dev libssl-dev \
    libgsl-dev libgsl27 libgslcblas0 \
    libglpk-dev libudunits2-dev \
    libmagick++-dev gdal-bin libgdal-dev libproj-dev \
    # --- Bio Tools available in Ubuntu ---
    bwa trimmomatic fastqc seqtk bamtools ea-utils \
    plink1.9 plink2 phylip \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 3. MANUALLY COMPILED BIOINFORMATICS TOOLS
WORKDIR /usr/local/src

# --- Samtools / Bcftools / Htslib ---
ARG SAM_VER=1.23
RUN wget https://github.com/samtools/samtools/releases/download/${SAM_VER}/samtools-${SAM_VER}.tar.bz2 \
    && tar -xjf samtools-${SAM_VER}.tar.bz2 \
    && cd samtools-${SAM_VER} && ./configure && make && make install \
    && cd .. \
    && wget https://github.com/samtools/bcftools/releases/download/${SAM_VER}/bcftools-${SAM_VER}.tar.bz2 \
    && tar -xjf bcftools-${SAM_VER}.tar.bz2 \
    && cd bcftools-${SAM_VER} && ./configure && make && make install \
    && cd .. \
    && wget https://github.com/samtools/htslib/releases/download/${SAM_VER}/htslib-${SAM_VER}.tar.bz2 \
    && tar -xjf htslib-${SAM_VER}.tar.bz2 \
    && cd htslib-${SAM_VER} && ./configure && make && make install \
    && rm -rf *tools-*.tar.bz2 htslib-*.tar.bz2

# --- Refresh Shared Library Cache ---
# Crucial: Ensures the system finds the libhts.so we just compiled
RUN ldconfig

# 4. PYTHON TOOLS via UV
COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/uv

# Install Python tools
# We set CFLAGS/LDFLAGS so pip finds the HTSlib headers we just compiled in /usr/local
ENV CFLAGS="-I/usr/local/include"
ENV LDFLAGS="-L/usr/local/lib"

RUN uv pip install --system --break-system-packages \
    numpy pandas scipy matplotlib seaborn \
    multiqc \
    dendropy biopython bcbio-gff intermine \
    pyabcranger

# pixy from GitHub at a release tag: the PyPI package named "pixy" is an
# unrelated terminal-colour library, not ksamuk/pixy.
# (The 2.2.5 tag's pyproject still says 2.2.4, so `pixy --version` reports 2.2.4.)
ARG PIXY_VERSION=2.2.5
RUN uv pip install --system --break-system-packages \
    "pixy @ git+https://github.com/ksamuk/pixy.git@${PIXY_VERSION}" \
    && pixy --version

# 5. REMAINING BINARIES
WORKDIR /usr/local/src

# Install clumpak
RUN mkdir /opt/clumpak \
        && cd /opt/clumpak \
	&& wget https://clumpak.evolseq.net/download/CLUMPAK.zip \
        && cd /opt/clumpak \
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

# Copy .pm files to /usr/share/perl/5.38
RUN cd /opt/clumpak/CLUMPAK/26_03_2015_CLUMPAK/CLUMPAK \
        && chmod +x *pm \
        && cp *.pm /usr/share/perl/5.38
# fix permissions for executables & add to path
RUN cd /opt/clumpak/CLUMPAK/26_03_2015_CLUMPAK/CLUMPAK/CLUMPP \
        && chmod +x CLUMPP \
        && cd /opt/clumpak/CLUMPAK/26_03_2015_CLUMPAK/CLUMPAK/mcl/bin \
        && chmod +x * \
        && cd /opt/clumpak/CLUMPAK/26_03_2015_CLUMPAK/CLUMPAK/distruct \
        && chmod +x distruct1.1
ENV PATH="$PATH:/opt/clumpak/CLUMPAK/26_03_2015_CLUMPAK/CLUMPAK/CLUMPP"
ENV PATH="$PATH:/opt/clumpak/CLUMPAK/26_03_2015_CLUMPAK/CLUMPAK/mcl/bin"
ENV PATH="$PATH:/opt/clumpak/CLUMPAK/26_03_2015_CLUMPAK/CLUMPAK/distruct"

# Install Structure
RUN mkdir /opt/structure \
  && cd /opt/structure \ 
  && wget https://web.stanford.edu/group/pritchardlab/structure_software/release_versions/v2.3.4/release/structure_linux_console.tar.gz \
  && tar xzfv structure_linux_console.tar.gz \
  && rm -rf structure_linux_console.tar.gz
ENV PATH="$PATH:/opt/structure/console"

# Install python3-pip & structure_threader
RUN apt update && apt -y install python3-venv python3-pip \
&& pip3 install --break-system-packages structure_threader 
# optional: add structure-threader to PATH
#RUN echo "PATH=$PATH:/.local/bin" >> .profile

# Install Bayescan
RUN mkdir /opt/bayescan \
  && cd /opt/bayescan \
  && wget http://cmpg.unibe.ch/software/BayeScan/files/BayeScan2.1.zip \
  && unzip BayeScan2.1.zip \
  && rm -rf BayeScan2.1.zip \
  && chmod +rwx /opt/bayescan/BayeScan2.1/binaries/BayeScan2.1_linux64bits \
  && mv /opt/bayescan/BayeScan2.1/binaries/BayeScan2.1_linux64bits \
  /usr/local/bin/bayescan

# Install TreeMix
RUN apt update && apt -y install libboost-all-dev libgsl0-dev \
	&& git clone https://bitbucket.org/nygcresearch/treemix.git \
	&& cd treemix \
 	&& ./configure \
  	&& make \
  	&& make install
	
# Install bedtools
RUN wget https://github.com/arq5x/bedtools2/releases/download/v2.31.0/bedtools.static \
	&& mv bedtools.static bedtools \
	&& chmod a+x bedtools \
	&& mv bedtools /usr/local/bin/bedtools

# Install freebayes
RUN wget https://github.com/freebayes/freebayes/releases/download/v1.3.10/freebayes-1.3.10-linux-amd64-static.gz \
	&& gunzip freebayes-1.3.10-linux-amd64-static.gz \
	&& chmod +x freebayes-1.3.10-linux-amd64-static \
	&& mv freebayes-1.3.10-linux-amd64-static freebayes \
	&& mv freebayes /usr/local/bin/freebayes

# Install vcftools
RUN wget https://github.com/vcftools/vcftools/releases/download/v0.1.17/vcftools-0.1.17.tar.gz \
	&& tar -xvf vcftools-0.1.17.tar.gz && rm vcftools-0.1.17.tar.gz \
	&& cd vcftools-0.1.17/ \
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

# Install blast+ (versioned folder over https, checked against NCBI's md5:
# the FTP LATEST/ download arrived corrupted once, and LATEST moves on release)
ARG BLAST_VERSION=2.17.0
RUN wget -q https://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/${BLAST_VERSION}/ncbi-blast-${BLAST_VERSION}+-x64-linux.tar.gz \
	https://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/${BLAST_VERSION}/ncbi-blast-${BLAST_VERSION}+-x64-linux.tar.gz.md5 \
	&& md5sum -c ncbi-blast-${BLAST_VERSION}+-x64-linux.tar.gz.md5 \
	&& tar -xzf ncbi-blast-${BLAST_VERSION}+-x64-linux.tar.gz \
	&& mv ncbi-blast-${BLAST_VERSION}+/bin/* /usr/local/bin/ \
	&& rm -rf ncbi-blast-${BLAST_VERSION}+ ncbi-blast-${BLAST_VERSION}+-x64-linux.tar.gz*

# --- Mosdepth ---
RUN wget https://github.com/brentp/mosdepth/releases/download/v0.3.12/mosdepth \
    && chmod a+x mosdepth \
    && mv mosdepth /usr/local/bin/mosdepth

# Install minimap2
RUN wget https://github.com/lh3/minimap2/releases/download/v2.26/minimap2-2.26_x64-linux.tar.bz2 \
	&& tar -jxvf minimap2-2.26_x64-linux.tar.bz2 \
	&& mv minimap2-2.26_x64-linux/minimap2 /usr/local/bin/minimap2

# --- GATK & Picard ---
RUN mkdir -p /opt/gatk \
    && wget https://github.com/broadinstitute/gatk/releases/download/4.6.2.0/gatk-4.6.2.0.zip \
    && unzip -q gatk-4.6.2.0.zip \
    && mv gatk-4.6.2.0/* /opt/gatk/ \
    && ln -s /opt/gatk/gatk /usr/local/bin/gatk \
    && rm gatk-4.6.2.0.zip \
    && wget https://github.com/broadinstitute/picard/releases/download/3.4.0/picard.jar \
    && mv picard.jar /usr/share/java/picard.jar

# --- BWA-MEM2 ---
RUN wget https://github.com/bwa-mem2/bwa-mem2/releases/download/v2.2.1/bwa-mem2-2.2.1_x64-linux.tar.bz2 \
    && tar -xjf bwa-mem2-2.2.1_x64-linux.tar.bz2 \
    && mv bwa-mem2-2.2.1_x64-linux/bwa-mem2* /usr/local/bin/ \
    && rm -rf bwa-mem2*

# Install easySFS
RUN apt update && apt -y install python3-numpy python3-pandas python3-scipy
RUN git clone https://github.com/isaacovercast/easySFS.git \
	&& cd easySFS \
	&& chmod 777 easySFS.py

# Install fastsimcoal2
RUN wget http://cmpg.unibe.ch/software/fastsimcoal28/downloads/fsc28_linux64.zip \
	&& unzip fsc28_linux64.zip \
	&& mv fsc28_linux64/fsc28 /usr/local/bin/ \
	&& rm fsc28_linux64/fastsimcoal28.pdf

# Install KING
RUN wget https://www.kingrelatedness.com/Linux-king.tar.gz \
	&& tar -xzvf Linux-king.tar.gz \
	&& mv king /usr/local/bin/king

# --- PopLDdecay ---
RUN wget https://github.com/hewm2008/PopLDdecay/archive/v3.45.tar.gz \
    && tar -zxf v3.45.tar.gz \
    && cd PopLDdecay-3.45/src \
    && sh make.sh \
    && cp -r ../bin/* /usr/local/bin/ \
    && cd ../.. && rm -rf PopLDdecay* v3.45.tar.gz

# Install ANGSD
RUN git clone --recurse-submodules https://github.com/samtools/htslib.git \
        && cd htslib \
        && make

RUN git clone https://github.com/angsd/angsd.git \
        && cd angsd && make HTSSRC=../htslib

RUN cp -r angsd/ /usr/local/bin/angsd/
ENV PATH="$PATH:/usr/local/bin/angsd/"

# Install NgsRelate
RUN git clone https://github.com/ANGSD/ngsRelate \
        && cd ngsRelate \
        && make HTSSRC=../htslib
RUN cp -r ngsRelate/ /usr/local/bin/ngsRelate/

# Install Admixture (static binary; from 1.4.0 the tarball has no dist/ prefix)
ARG ADMIXTURE_VERSION=1.4.0
ARG ADMIXTURE_SHA256=5520c4f18525f49ab2c715d711b40f4a0818ef1485361a94ec8954d1364e6f19
RUN wget https://dalexander.github.io/admixture/binaries/admixture_linux-${ADMIXTURE_VERSION}.tar.gz \
	&& echo "${ADMIXTURE_SHA256}  admixture_linux-${ADMIXTURE_VERSION}.tar.gz" | sha256sum -c - \
	&& tar -xzvf admixture_linux-${ADMIXTURE_VERSION}.tar.gz \
	&& cp admixture_linux-${ADMIXTURE_VERSION}/admixture /usr/local/bin/admixture \
	&& rm -rf admixture_linux-${ADMIXTURE_VERSION} admixture_linux-${ADMIXTURE_VERSION}.tar.gz \
	&& admixture 2>&1 | grep -q "${ADMIXTURE_VERSION}"

# Install Admixtools
RUN apt update && apt install -y libgsl-dev libblas-dev gfortran liblapack-dev
RUN wget https://github.com/DReichLab/AdmixTools/archive/refs/tags/v8.0.2.tar.gz \
        && tar xzvf v8.0.2.tar.gz \
		&& cd AdmixTools-8.0.2/src \
        && make clobber \
        && make all \
        && make install 
		#&& cp AdmixTools-8.0.2/bin/* /usr/local/bin/

# --- Baypass (pinned release tag; forgemia.inra.fr now redirects to forge.inrae.fr) ---
ARG BAYPASS_VERSION=v3.1
RUN git clone --depth 1 --branch ${BAYPASS_VERSION} \
        https://forge.inrae.fr/mathieu.gautier/baypass_public.git \
    && cd baypass_public/sources \
    && make clean all FC=gfortran \
    && mv g_baypass /usr/local/bin/g_baypass \
    && cd ../.. && rm -rf baypass_public

# R PACKAGES
# --- BIOCONDUCTOR ---
# Note: 'LEA' replaces the old 'lfmm' package
RUN R -e "BiocManager::install(c(\
    'NOISeq','Repitools','Rsamtools','GenomicFeatures','rtracklayer', \
    'qvalue', 'ggtree', 'LEA', \
    'snpStats', 'GenomicRanges', 'GenomInfoDb', 'IRanges', \
    'SNPRelate', 'gdsfmt', 'geneplotter', 'topGO', 'Rgraphviz' \
    ))"

# --- CRAN PACKAGES ---
# Rust toolchain: eulerr (and other CRAN packages) now compile Rust code and need
# rustc >= 1.88; Ubuntu 24.04's default rustc is 1.75, so use a versioned package.
RUN apt-get update -qq \
    && apt-get install -y --no-install-recommends rustc-1.97 cargo-1.97 \
    && rm -rf /var/lib/apt/lists/* \
    && /usr/lib/rust-1.97/bin/rustc --version && /usr/lib/rust-1.97/bin/cargo --version
ENV PATH="/usr/lib/rust-1.97/bin:$PATH"

# Utilities & Plotting
RUN apt update -qq \
  	&& apt -y install libudunits2-dev # needed for scatterpie
RUN install2.r --error --skipinstalled -n 4 \
    --repos https://cran.rstudio.com \
    viridis multcomp remedy factoextra scatterpie ggmap splitstackshape \
    gridGraphics gridExtra officer flextable eulerr car sjstats \
    data.table ggrepel optparse ggThemeAssist kableExtra gtable devtools \
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

# PopGen & Stats
RUN rm -rf /tmp/*.rds \
&&  install2.r --error --skipinstalled -n 4 \
    --repos https://cran.rstudio.com \
	pcadapt OptM vcfR ape adegenet pegas phangorn phylobase \
	coalescentMCMC poppr psych genetics hierfstat lme4 MuMIn vegan \
	admixr igraph phytools scales gtools reshape reshape2 gplots \
	gsalib gdistance mclust mvtnorm geigen poolfstat conStruct \
	poolr usdm ClustOfVar lmerTest emmeans \
&& rm -rf /tmp/downloaded_packages/ /tmp/*.rds

# Spatial & Env
RUN install2.r --error --skipinstalled -n 4 \
    --repos https://cran.rstudio.com \
    raster maps sf corrplot FactoMineR ggpubr \
    plyr gdm foreach doParallel fields geosphere \
    terra rnaturalearth geodata plotly manipulateWidget \
    && rm -rf /tmp/downloaded_packages/ /tmp/*.rds

# --- R-FORGE PACKAGES ---
RUN install2.r --error --skipinstalled -r http://R-Forge.R-project.org \
    gradientForest extendedForest \
    && rm -rf /tmp/downloaded_packages/ /tmp/*.rds
#------------------------------------------------------------------------------

# --- GITHUB PACKAGES ---
# Install linux dependencies for pophelper and other packages
RUN apt -y install libcairo2-dev libxt-dev libfreetype6-dev \
        libcurl4-openssl-dev libssl-dev libxml2-dev libnlopt-dev

# poolHelper and poolABC are usually installed from GitHub
# (rocker 4.6.x no longer ships 'remotes', so install it first; 'geometry' and
#  'robust' are imported by rdadapt but missing from its DESCRIPTION)
# PopGenome is left out: its C code calls Rf_findVar, which R 4.6 removed from the
# C API, so it no longer compiles (pievos101/PopGenome is unmaintained).
RUN install2.r --error --skipinstalled --repos https://cran.rstudio.com remotes geometry robust \
    && R -e "remotes::install_github(c(\
    'whitlock/OutFLANK', \
    'thierrygosselin/radiator', \
    'royfrancis/pophelper', \
    'SFUStatgen/LDheatmap', \
    'jiabowang/GAPIT3', \
    'TBooker/PicMin', \
    'landscape-genomics/rdadapt'))" \
    && rm -rf /tmp/downloaded_packages/ /tmp/*.rds

# Install fastStructure3 (Python 3 port of rajanil/fastStructure)
# DISABLED (2026-11-13): it needs Cython < 3, but the NumPy 2.x headers installed
# above refuse to compile with Cython < 3 ("the NumPy Cython headers require
# Cython 3"). It was already missing from wgrs_tools 0.1.6. Re-enable only with a
# separate numpy<2 environment or once fastStructure3 builds with Cython 3.
# RUN uv pip install --system --break-system-packages "cython<3" \
#     && git clone https://github.com/stevemussmann/fastStructure3.git \
#     && cd fastStructure3/vars \
#     && python3 setup.py build_ext --inplace \
#     && cd .. \
#     && python3 setup.py build_ext --inplace \
#     && chmod +x structure.py chooseK.py distruct.py \
#     && cd .. \
#     && mv fastStructure3 /opt/fastStructure
# ENV PATH="$PATH:/opt/fastStructure"

# --- SnpEff / SnpSift (official release; Ubuntu's apt package is older, 5.2b) ---
# Placed after the R layers to keep the build cache. No databases are bundled:
# on a read-only Apptainer image use `snpEff -dataDir /some/writable/path ...`.
ARG SNPEFF_VERSION=5_4c
ARG SNPEFF_SHA256=3b06a1e1f939e7ebd5433387f088c1d3d1e0a7d472d63f39161b1fe9f00adf33
RUN wget -q https://snpeff-public.s3.amazonaws.com/versions/snpEff_v${SNPEFF_VERSION}_core.zip \
    && echo "${SNPEFF_SHA256}  snpEff_v${SNPEFF_VERSION}_core.zip" | sha256sum -c - \
    && unzip -q snpEff_v${SNPEFF_VERSION}_core.zip -d /opt \
    && rm snpEff_v${SNPEFF_VERSION}_core.zip

# Launcher used instead of the bundled exec/ wrappers, which split quoted
# arguments (SnpSift filter "QUAL > 30" arrives as three words). Same defaults:
# -Xm* and -D* go to the JVM, -Xms1g -Xmx8g unless a -Xm option is given.
COPY --chmod=755 <<'EOF' /opt/snpEff/launcher
#!/bin/bash
case "$(basename "$0")" in
    [Ss]np[Ss]ift) jar=/opt/snpEff/SnpSift.jar ;;
    *)             jar=/opt/snpEff/snpEff.jar ;;
esac
mem=(); props=(); args=()
for a in "$@"; do
    case "$a" in
        -Xm*) mem+=("$a") ;;
        -D*)  props+=("$a") ;;
        *)    args+=("$a") ;;
    esac
done
[ ${#mem[@]} -eq 0 ] && mem=(-Xms1g -Xmx8g)
exec java "${mem[@]}" "${props[@]}" -jar "$jar" "${args[@]}"
EOF
RUN for c in snpEff snpeff SnpSift snpsift; do ln -s /opt/snpEff/launcher /usr/local/bin/$c; done \
    && snpEff -version \
    && printf '##fileformat=VCFv4.2\n#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\nc\t1\t.\tA\tC\t50\tPASS\t.\nc\t2\t.\tA\tC\t10\tPASS\t.\n' > /tmp/t.vcf \
    && [ "$(SnpSift filter "QUAL > 30" /tmp/t.vcf | grep -vc '^#')" = 1 ] \
    && rm /tmp/t.vcf

# FINAL CLEANUP
WORKDIR /home/rstudio
RUN ldconfig
