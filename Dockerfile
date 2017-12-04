#// Pull base image.
FROM ubuntu:14.04

MAINTAINER Gordon Saksena <gsaksena@broadinstitue.org>
ENV TERM=vt100


RUN \
  sed -i 's/# \(.*multiverse$\)/\1/g' /etc/apt/sources.list && \
  apt-get update && \
  apt-get -y upgrade && \
  apt-get install -y build-essential && \
  apt-get install -y software-properties-common && \
  apt-get install -y byobu curl git htop man unzip vim wget && \
  rm -rf /var/lib/apt/lists/*



#// Set environment variables.
ENV HOME /root
WORKDIR /root


RUN echo date 

#install Java 7 and 8, make 7 the default, drop legacy symlink to 8.
COPY src/algutil/java_archives/ /opt/java_archives

# suppress nonzero exit code from dpkg
RUN dpkg -i /opt/java_archives/zulu7.20.0.3-jdk7.0.154-linux_amd64.deb || true
RUN dpkg -i /opt/java_archives/zulu8.23.0.3-jdk8.0.144-linux_amd64.deb || true
RUN apt-get update && apt-get install -fy
RUN rm /opt/java_archives/zulu7.20.0.3-jdk7.0.154-linux_amd64.deb /opt/java_archives/zulu8.23.0.3-jdk8.0.144-linux_amd64.deb 

ENV JAVA_HOME /usr/lib/jvm/java-7-openjdk-amd64
RUN update-alternatives --install /usr/bin/java java /usr/lib/jvm/zulu-7-amd64/jre/bin/java 10000000
RUN mkdir -p /opt/java8 && ln -s /usr/lib/jvm/zulu-8-amd64 /opt/java8/jdk1.8.0_31

#test that java installed properly
RUN java -version



RUN echo "deb http://cran.rstudio.com/bin/linux/ubuntu trusty/" | tee -a /etc/apt/sources.list
RUN echo "deb http://us.archive.ubuntu.com/ubuntu trusty main universe" | tee -a /etc/apt/sources.list
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E084DAB9


#RUN apt-get install -y python-software-properties


#Load C++ libraries
RUN add-apt-repository -y ppa:ubuntu-toolchain-r/test
RUN apt-get -y update
RUN apt-get -y --force-yes upgrade
RUN apt-get -y dist-upgrade





#load R + libraries

RUN apt-get install -y --force-yes r-base r-base-dev


# RUN mkdir -p /opt/bcftools_build && cd /opt/bcftools_build && git clone --branch=develop git://github.com/samtools/htslib.git && git clone --branch=develop git://github.com/samtools/bcftools.git && git clone --branch=develop git://github.com/samtools/samtools.git && cd bcftools &&  make && cd ../samtools &&  make

RUN apt-get install -y samtools
RUN apt-get install -y libcurl4-openssl-dev #fixes error installing RCurl dependency


RUN Rscript -e "install.packages('optparse', repos='http://cran.us.r-project.org')"
RUN Rscript -e "install.packages('data.table', repos='http://cran.us.r-project.org')"
RUN Rscript -e "source('http://bioconductor.org/biocLite.R'); biocLite(c('GenomicRanges','DNAcopy','Rsamtools'))"


#load Python2&3, and utilities needed for Matlab MCR install
RUN apt-get install -yq unzip wget bc python3 python3-pip libxp6 vcftools #git

COPY src/algutil/matlab2009a_mcr/ /opt/matlab2009a_mcr_install
# merge installer file that had to be split to fit on github
RUN cat  /opt/matlab2009a_mcr_install/MCRInstaller.bin.* > /opt/matlab2009a_mcr_install/MCRInstaller.bin && chmod 0777 /opt/matlab2009a_mcr_install/MCRInstaller.bin && rm /opt/matlab2009a_mcr_install/MCRInstaller.bin.*

RUN   cd /opt/matlab2009a_mcr_install && \
      ./MCRInstaller.bin -silent && \
      rm -f MCRInstaller.bin



ENV MCRROOT=/opt/MATLAB/MATLAB_Compiler_Runtime/v710
ENV MCRJRE=$MCRROOT/sys/java/jre/glnxa64/jre/lib/amd64
ENV XAPPLRESDIR=$MCRROOT/X11/app-defaults
ENV MCR_LD_LIBRARY_PATH=$MCRROOT/runtime/glnxa64:$MCRROOT/bin/glnxa64:$MCRROOT/sys/os/glnxa64:$MCRJRE/native_threads:$MCRJRE/server:$MCRJRE/client:$MCRJRE

#RUN cd /opt/MATLAB/MATLAB_Compiler_Runtime/v710/runtime/glnxa64; for l in  /opt/MATLAB/MATLAB_Compiler_Runtime/v710/bin/glnxa64/*; do ln -s $l; done


#ENV LD_LIBRARY_PATH=/cga/fh/pcawg_pipeline/modules/VariantBam/bamtools-2.1.0/lib



#will it work to go into a mounted dir?
WORKDIR /opt/src

#ENV PS1="\\u@\\h:\\w\\$"
RUN rm -f /root/.scripts/git-prompt.sh

#Set timezone on Docker instance to something other than UCT.
RUN echo "America/New_York" | sudo tee /etc/timezone; dpkg-reconfigure --frontend noninteractive tzdata
#RUN echo "America/Los_Angeles" | sudo tee /etc/timezone; dpkg-reconfigure --frontend noninteractive tzdata



RUN apt-get -y install python-dev python-pip
RUN pip install numpy ngslib


RUN mkdir -p /opt/pyvcf_install && cd /opt/pyvcf_install && wget --no-check-certificate 'https://github.com/elephanthunter/PyVCF/archive/master.zip' && unzip master.zip && cd PyVCF-master && python setup.py install && cd .. && rm -Rf PyVCF-master && rm -f master.*

#RUN pip install ngslib


RUN mkdir -p /opt/oncotator_install && cd /opt/oncotator_install &&  git clone https://github.com/broadinstitute/oncotator.git && cd oncotator && git checkout master

#force latest numpy version, in spite of Oncotator's requirements for 1.11.0

RUN mv /opt/oncotator_install/oncotator/setup.py /opt/oncotator_install/oncotator/setup_old.py &&  sed  's/==1.11.0//' /opt/oncotator_install/oncotator/setup_old.py > /opt/oncotator_install/oncotator/setup.py

RUN cd /opt/oncotator_install/oncotator && python setup.py install


# install SvABA executable to /opt/svaba_install/svaba/bin/svaba
#RUN apt-get install -y zlib1g-dev  
RUN mkdir -p /opt/svaba_install && cd /opt/svaba_install && git clone --recursive https://github.com/walaj/svaba && cd svaba && git checkout 4954a40f0c1070691cfacaa4e477ac84a0a0d5a6 && ./configure && make && make install
#RUN cd /opt/svaba_install  && wget https://data.broadinstitute.org/snowman/svaba_exclusions.bed  && wget -nv https://data.broadinstitute.org/snowman/dbsnp_indel.vcf 


RUN apt-get install dstat
COPY src/modules /opt/src/modules

#build variantbam
RUN cd /opt/src/modules/VariantBam  && ./configure && make && make install

#merge big files that had to be split for github
#files were split via eg: split -d -b 25000000 gc200.wig gc200.wig.
RUN cat  /opt/src/modules/contest/Queue-1.4-437-g6b8a9e1-svn-35362.jar.* > /opt/src/modules/contest/Queue-1.4-437-g6b8a9e1-svn-35362.jar && rm /opt/src/modules/contest/Queue-1.4-437-g6b8a9e1-svn-35362.jar.*
RUN cat  /opt/src/modules/fragCounter/gccontent/gc200.rds.* > /opt/src/modules/fragCounter/gccontent/gc200.rds && rm /opt/src/modules/fragCounter/gccontent/gc200.rds.*
RUN cat  /opt/src/modules/fragCounter/gccontent/gc200.wig.* > /opt/src/modules/fragCounter/gccontent/gc200.wig && rm /opt/src/modules/fragCounter/gccontent/gc200.wig.*
#RUN cat  /opt/src/modules/Snowman/lung_snow24_pon.txt.gz.* > /opt/src/modules/Snowman/lung_snow24_pon.txt.gz && rm /opt/src/modules/Snowman/lung_snow24_pon.txt.gz.*




ENV LD_LIBRARY_PATH=$MCR_LD_LIBRARY_PATH
# prepare for Matlab-based tools to run
RUN /opt/matlab2009a_mcr_install/extractCTF /opt/src/modules/dRangerPreprocess/fh_dRangerPreprocessGather.ctf
RUN /opt/matlab2009a_mcr_install/extractCTF /opt/src/modules/dRangerFinalize/fh_dRangerFinalize.ctf
RUN /opt/matlab2009a_mcr_install/extractCTF /opt/src/modules/dRanger_BreakPointer/fh_BreakPointerScatter.ctf
ENV LD_LIBRARY_PATH=
COPY src/algutil /opt/src/algutil

COPY src/pipelines /opt/src/pipelines

RUN chmod go+r -R /usr/local/lib/python3.4/dist-packages/; chmod go+w /opt/src; chmod go+rx /opt/src/pipelines/*.py; chmod go+rx /opt/src/algutil/firehose_module_adaptor/*.py;
#RUN chmod go+rx /opt/src/pipelines/*.sh

RUN chmod go+wrx /home
ENV HOME /home

